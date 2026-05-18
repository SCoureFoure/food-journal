$REPO     = Split-Path $PSScriptRoot -Parent
$DATASETS = Join-Path $REPO "datasets"

$humanFile = Join-Path $DATASETS "human_judgements.json"
$llmFile   = Join-Path $DATASETS "llm_judgements.json"
$outFile   = Join-Path $DATASETS "alignment.json"

$human = Get-Content $humanFile | ConvertFrom-Json
$llm   = Get-Content $llmFile   | ConvertFrom-Json

if ($llm.judgement_count -eq 0) {
    Write-Host "[SKIP] llm_judgements.json is empty — run run_llm_judge.ps1 first" -ForegroundColor Yellow
    exit 0
}

# ── Build lookup: input_id → human judgement (only where overall is non-null) ─

function Build-Lookup([array]$Judgements) {
    $map = @{}
    foreach ($j in $Judgements) {
        if ($null -ne $j.overall) { $map[$j.input_id] = $j }
    }
    return $map
}

$humanMealMap = Build-Lookup $human.meal_judgements
$humanMedMap  = Build-Lookup $human.medication_judgements

# ── Compute agreement per criterion ──────────────────────────────────────────

function Compute-Agreement([array]$LlmJudgements, [hashtable]$HumanMap, [string[]]$Criteria) {
    $counts   = @{}
    $total    = 0
    $compared = @()

    foreach ($c in $Criteria) { $counts[$c] = 0 }

    foreach ($lj in $LlmJudgements) {
        $hj = $HumanMap[$lj.input_id]
        if (-not $hj) { continue }
        $total++

        $row = @{ input_id = $lj.input_id; description = $lj.description }
        foreach ($c in $Criteria) {
            $agree = ($hj.$c -eq $lj.$c)
            if ($agree) { $counts[$c]++ }
            $row["${c}_human"] = $hj.$c
            $row["${c}_llm"]   = $lj.$c
            $row["${c}_agree"] = $agree
        }
        $compared += $row
    }

    $perCriterion = @{}
    foreach ($c in $Criteria) {
        $perCriterion[$c] = if ($total -gt 0) { [math]::Round($counts[$c] / $total, 3) } else { $null }
    }

    return @{
        total         = $total
        overall_agreement = $perCriterion["overall"]
        per_criterion = $perCriterion
        comparisons   = $compared
    }
}

$mealCriteria = @("names_pass", "title_pass", "macros_pass", "count_pass", "overall")
$medCriteria  = @("names_pass", "count_pass", "no_inference_pass", "overall")

$mealAgreement = Compute-Agreement $llm.meal_judgements $humanMealMap $mealCriteria
$medAgreement  = Compute-Agreement $llm.medication_judgements $humanMedMap $medCriteria

$totalCompared = $mealAgreement.total + $medAgreement.total
$target = 0.85

# Combined overall = weighted average if both have data
$combinedOverall = $null
if ($totalCompared -gt 0) {
    $mealWeight = $mealAgreement.total / $totalCompared
    $medWeight  = $medAgreement.total  / $totalCompared
    $mealOA = if ($null -ne $mealAgreement.overall_agreement) { $mealAgreement.overall_agreement } else { 0 }
    $medOA  = if ($null -ne $medAgreement.overall_agreement)  { $medAgreement.overall_agreement  } else { 0 }
    $combinedOverall = [math]::Round($mealOA * $mealWeight + $medOA * $medWeight, 3)
}

$status = if ($totalCompared -eq 0)          { "no_data" }
          elseif ($totalCompared -lt 10)       { "insufficient_data" }
          elseif ($combinedOverall -ge $target) { "aligned" }
          else                                  { "needs_calibration" }

$alignment = @{
    schema_version    = "1.0.0"
    computed_at       = (Get-Date -Format "o")
    total_compared    = $totalCompared
    target_agreement  = $target
    status            = $status
    overall_agreement = $combinedOverall
    meal = @{
        total             = $mealAgreement.total
        overall_agreement = $mealAgreement.overall_agreement
        per_criterion     = $mealAgreement.per_criterion
        comparisons       = $mealAgreement.comparisons
    }
    medication = @{
        total             = $medAgreement.total
        overall_agreement = $medAgreement.overall_agreement
        per_criterion     = $medAgreement.per_criterion
        comparisons       = $medAgreement.comparisons
    }
}

$alignment | ConvertTo-Json -Depth 10 | Set-Content $outFile -Encoding utf8

# ── Report ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Alignment Report" -ForegroundColor Cyan
Write-Host "  Pairs compared : $totalCompared"
Write-Host "  Overall agreement : $(if ($null -ne $combinedOverall) { "$([math]::Round($combinedOverall * 100, 1))%" } else { 'n/a' })  (target: $([math]::Round($target * 100))%)"
Write-Host "  Status : $status"

if ($mealAgreement.total -gt 0) {
    Write-Host ""
    Write-Host "  [Meal] $($mealAgreement.total) pairs"
    foreach ($c in $mealCriteria) {
        $pct = if ($null -ne $mealAgreement.per_criterion[$c]) { "$([math]::Round($mealAgreement.per_criterion[$c] * 100, 1))%" } else { "n/a" }
        Write-Host "    $c`: $pct"
    }
}

if ($medAgreement.total -gt 0) {
    Write-Host ""
    Write-Host "  [Medication] $($medAgreement.total) pairs"
    foreach ($c in $medCriteria) {
        $pct = if ($null -ne $medAgreement.per_criterion[$c]) { "$([math]::Round($medAgreement.per_criterion[$c] * 100, 1))%" } else { "n/a" }
        Write-Host "    $c`: $pct"
    }
}

Write-Host ""
if ($status -eq "needs_calibration") {
    Write-Host "  Action: review comparisons in alignment.json, tighten judge prompt, re-run run_llm_judge.ps1" -ForegroundColor Yellow
} elseif ($status -eq "aligned") {
    Write-Host "  LLM judge trusted for unsupervised runs." -ForegroundColor Green
} else {
    Write-Host "  Fill more rows in human_judgements.json then re-run." -ForegroundColor Gray
}
