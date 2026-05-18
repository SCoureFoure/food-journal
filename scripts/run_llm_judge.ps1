param(
    [string]$Task = "all"  # all | meal | medication
)

$REPO         = Split-Path $PSScriptRoot -Parent
$DATASETS     = Join-Path $REPO "datasets"
$ROOT_ENV     = Join-Path $REPO ".env"

# ── Load env vars from root .env (keys never go in app/.env) ──────────────────

function Get-RootEnv([string]$Key) {
    $val = [System.Environment]::GetEnvironmentVariable($Key)
    if ($val) { return $val }
    if (Test-Path $ROOT_ENV) {
        $line = Get-Content $ROOT_ENV | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
        if ($line) { return ($line -split '=', 2)[1].Trim() }
    }
    return $null
}

$workerUrl    = Get-RootEnv "MEAL_PARSER_URL"
$authToken    = Get-RootEnv "TEST_AUTH_TOKEN"
$anthropicKey = Get-RootEnv "ANTHROPIC_API_KEY"

if (-not $workerUrl)    { Write-Error "MEAL_PARSER_URL not set in root .env"; exit 1 }
if (-not $anthropicKey) { Write-Error "ANTHROPIC_API_KEY not set in root .env"; exit 1 }

$runId = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"

# ── Judge prompts ─────────────────────────────────────────────────────────────

$MEAL_JUDGE_SYSTEM = @'
You are a strict evaluator of a meal-parsing AI. Given the original user input and the parsed JSON output, rate each criterion as true (pass) or false (fail).

Criteria:
1. names_pass: ALL food names are specific real foods. FAIL if ANY name is generic (e.g. "food item", "dish", "meal", "item", "food", "thing", a single article, or clearly made-up).
2. title_pass: Title is descriptive and specific. FAIL if the title is only a meal-type word (e.g. "Breakfast", "Lunch", "Dinner", "Meal", "Snack") or a single generic word.
3. macros_pass: If macros are present they must be physically plausible per item: calories ≤ 3000, protein ≤ 200g, fat ≤ 200g, carbs ≤ 500g. PASS (true) if all macro fields are null.
4. count_pass: At least 1 food item was returned in the foods array.

overall = true only when ALL 4 criteria pass.

Return ONLY this JSON, no explanation, no markdown:
{"names_pass": bool, "title_pass": bool, "macros_pass": bool, "count_pass": bool, "overall": bool, "notes": "one short sentence"}
'@

$MED_JUDGE_SYSTEM = @'
You are a strict evaluator of a medication-parsing AI. Given the original user input and the parsed JSON output, rate each criterion as true (pass) or false (fail).

Criteria:
1. names_pass: The medication name is a specific drug or supplement name (not "medication", "pill", "drug", "supplement", or clearly generic). true if name is a real product/compound name.
2. count_pass: The name field is non-null and non-empty.
3. no_inference_pass: No field (dose, unit, route) contains a value that was NOT explicitly stated in the input text. If the input only says "Metformin" with no number, dose must be null. If input says no route, route must be null. FAIL if the model invented any field.

overall = true only when ALL 3 criteria pass.

Return ONLY this JSON, no explanation, no markdown:
{"names_pass": bool, "count_pass": bool, "no_inference_pass": bool, "overall": bool, "notes": "one short sentence"}
'@

# ── Helper: call Anthropic ────────────────────────────────────────────────────

function Invoke-ClaudeJudge([string]$SystemPrompt, [string]$UserMessage) {
    $body = @{
        model      = "claude-haiku-4-5-20251001"
        max_tokens = 300
        system     = $SystemPrompt
        messages   = @(@{ role = "user"; content = $UserMessage })
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "x-api-key"         = $anthropicKey
        "anthropic-version" = "2023-06-01"
        "Content-Type"      = "application/json"
    }

    try {
        $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post -Headers $headers -Body $body
        $raw = $resp.content[0].text
        $raw = $raw -replace '```json\s*', '' -replace '\s*```', '' -replace '```', ''
        return $raw | ConvertFrom-Json
    } catch {
        Write-Warning "Claude judge call failed: $_"
        return $null
    }
}

# ── Helper: call worker ───────────────────────────────────────────────────────

function Invoke-Worker([hashtable]$Payload) {
    $headers = @{ "Content-Type" = "application/json" }
    if ($authToken) { $headers["Authorization"] = "Bearer $authToken" }
    try {
        return Invoke-RestMethod -Uri $workerUrl -Method Post `
            -Headers $headers -Body ($Payload | ConvertTo-Json -Depth 5)
    } catch {
        return $null
    }
}

# ── Judge meals ───────────────────────────────────────────────────────────────

$mealResults = @()

if ($Task -eq "all" -or $Task -eq "meal") {
    $mealInputs = Get-Content (Join-Path $DATASETS "golden_meal_inputs.json") | ConvertFrom-Json
    Write-Host ""
    Write-Host "[MEAL] Judging $($mealInputs.Count) golden meal inputs..." -ForegroundColor Cyan

    foreach ($input in $mealInputs) {
        Write-Host "  $($input.id): $($input.description)" -NoNewline

        $payload = @{ task = "parse_meal" }
        $effectiveText = $input.input.text
        if ($input.input.mealContext -and $input.input.text) {
            $effectiveText = "$($input.input.mealContext)`n`nUser input: $($input.input.text)"
        }
        if ($effectiveText)           { $payload["text"]     = $effectiveText }
        if ($input.input.mealType)    { $payload["mealType"] = $input.input.mealType }

        $workerOut = Invoke-Worker $payload

        if (-not $workerOut) {
            Write-Host " [WORKER-FAIL]" -ForegroundColor Red
            $mealResults += @{
                input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
                judged_at = (Get-Date -Format "o"); description = $input.description
                worker_success = $false; parsed_output = $null
                names_pass = $false; title_pass = $false; macros_pass = $false
                count_pass = $false; overall = $false; notes = "Worker call failed"
            }
            continue
        }

        $userMsg = "Input: $($input.input | ConvertTo-Json -Depth 3)`n`nParsed output: $($workerOut | ConvertTo-Json -Depth 5)"
        $judgement = Invoke-ClaudeJudge $MEAL_JUDGE_SYSTEM $userMsg

        if (-not $judgement) {
            Write-Host " [JUDGE-FAIL]" -ForegroundColor Yellow
            $mealResults += @{
                input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
                judged_at = (Get-Date -Format "o"); description = $input.description
                worker_success = $true; parsed_output = $workerOut
                names_pass = $null; title_pass = $null; macros_pass = $null
                count_pass = $null; overall = $null; notes = "Judge call failed"
            }
            continue
        }

        $icon = if ($judgement.overall) { "[PASS]" } else { "[FAIL]" }
        $color = if ($judgement.overall) { "Green" } else { "Red" }
        Write-Host " $icon" -ForegroundColor $color

        $mealResults += @{
            input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
            judged_at = (Get-Date -Format "o"); description = $input.description
            worker_success = $true; parsed_output = $workerOut
            names_pass = $judgement.names_pass; title_pass = $judgement.title_pass
            macros_pass = $judgement.macros_pass; count_pass = $judgement.count_pass
            overall = $judgement.overall; notes = $judgement.notes
        }
    }
}

# ── Judge medications ─────────────────────────────────────────────────────────

$medResults = @()

if ($Task -eq "all" -or $Task -eq "medication") {
    $medInputs = Get-Content (Join-Path $DATASETS "golden_medication_inputs.json") | ConvertFrom-Json
    Write-Host ""
    Write-Host "[MED] Judging $($medInputs.Count) golden medication inputs..." -ForegroundColor Cyan

    foreach ($input in $medInputs) {
        Write-Host "  $($input.id): $($input.description)" -NoNewline

        $payload = @{ task = "parse_medication"; text = $input.input.text }
        $workerOut = Invoke-Worker $payload

        if (-not $workerOut) {
            Write-Host " [WORKER-FAIL]" -ForegroundColor Red
            $medResults += @{
                input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
                judged_at = (Get-Date -Format "o"); description = $input.description
                worker_success = $false; parsed_output = $null
                names_pass = $false; count_pass = $false; no_inference_pass = $false
                overall = $false; notes = "Worker call failed"
            }
            continue
        }

        $userMsg = "Input text: `"$($input.input.text)`"`n`nParsed output: $($workerOut | ConvertTo-Json -Depth 5)"
        $judgement = Invoke-ClaudeJudge $MED_JUDGE_SYSTEM $userMsg

        if (-not $judgement) {
            Write-Host " [JUDGE-FAIL]" -ForegroundColor Yellow
            $medResults += @{
                input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
                judged_at = (Get-Date -Format "o"); description = $input.description
                worker_success = $true; parsed_output = $workerOut
                names_pass = $null; count_pass = $null; no_inference_pass = $null
                overall = $null; notes = "Judge call failed"
            }
            continue
        }

        $icon = if ($judgement.overall) { "[PASS]" } else { "[FAIL]" }
        $color = if ($judgement.overall) { "Green" } else { "Red" }
        Write-Host " $icon" -ForegroundColor $color

        $medResults += @{
            input_id = $input.id; run_id = $runId; judge = "llm-claude-haiku"
            judged_at = (Get-Date -Format "o"); description = $input.description
            worker_success = $true; parsed_output = $workerOut
            names_pass = $judgement.names_pass; count_pass = $judgement.count_pass
            no_inference_pass = $judgement.no_inference_pass
            overall = $judgement.overall; notes = $judgement.notes
        }
    }
}

# ── Write output ──────────────────────────────────────────────────────────────

$allResults = $mealResults + $medResults
$passCount  = ($allResults | Where-Object { $_.overall -eq $true } | Measure-Object).Count
$total      = $allResults.Count

$output = @{
    schema_version       = "1.0.0"
    run_id               = $runId
    generated_at         = (Get-Date -Format "o")
    judgement_count      = $total
    pass_count           = $passCount
    meal_judgements      = $mealResults
    medication_judgements = $medResults
}

$outFile = Join-Path $DATASETS "llm_judgements.json"
$output | ConvertTo-Json -Depth 10 | Set-Content $outFile -Encoding utf8

Write-Host ""
Write-Host "Done: $passCount/$total passed  →  $outFile" -ForegroundColor Cyan
Write-Host "Next: fill datasets/human_judgements.json, then run compute_alignment.ps1" -ForegroundColor Gray
