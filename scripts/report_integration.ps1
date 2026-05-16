param(
    [string]$Label = ""
)

$REPO      = Split-Path $PSScriptRoot -Parent
$APP       = Join-Path $REPO "app"
$RPTS_INT  = Join-Path $REPO "reports\integration"
$HISTORY   = Join-Path $REPO "reports\history.jsonl"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OUT_FILE  = Join-Path $RPTS_INT "$TIMESTAMP.json"

New-Item -ItemType Directory -Force -Path $RPTS_INT | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $HISTORY) | Out-Null

$workerIndex = Join-Path $REPO "worker\src\index.js"
$AI_MODEL = if (Test-Path $workerIndex) {
    $line = Get-Content $workerIndex | Select-String "models/" | Select-Object -First 1
    if ($line -match 'models/([\w.\-]+)') { $Matches[1] } else { "unknown" }
} else { "unknown" }

# ── Require MEAL_PARSER_URL ────────────────────────────────────────────────────

if (-not $env:MEAL_PARSER_URL) {
    $envFile = Join-Path $APP ".env"
    if (Test-Path $envFile) {
        $envLine = Get-Content $envFile | Where-Object { $_ -match '^MEAL_PARSER_URL=' } | Select-Object -First 1
        if ($envLine) { $env:MEAL_PARSER_URL = ($envLine -split '=', 2)[1].Trim() }
    }
}

if (-not $env:MEAL_PARSER_URL) {
    Write-Host "[SKIP] MEAL_PARSER_URL not set - integration tests require a live worker" -ForegroundColor Yellow
    exit 0
}

$API_TARGET = $env:MEAL_PARSER_URL

# ── Run flutter test ───────────────────────────────────────────────────────────

Write-Host "[..] Running integration layer tests (live fire → $API_TARGET)..." -ForegroundColor Cyan
$START_TIME = Get-Date

Push-Location $APP
$rawLines = @(& flutter test test/integration/ai/ --reporter json 2>$null)
$EXIT_CODE = $LASTEXITCODE
Pop-Location

$WALL_MS = [int]((Get-Date) - $START_TIME).TotalMilliseconds

# ── Parse JSON event stream ────────────────────────────────────────────────────

$groups  = @{}
$tests   = @{}
$totalMs = 0

foreach ($line in $rawLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $ev = $line | ConvertFrom-Json } catch { continue }
    if (-not $ev -or -not $ev.type) { continue }

    switch ($ev.type) {
        "group" {
            if ($ev.group -and $null -ne $ev.group.name) {
                $groups["$($ev.group.id)"] = [string]$ev.group.name
            }
        }
        "testStart" {
            $t = $ev.test
            if (-not $t) { continue }
            $groupName = ""
            if ($t.groupIDs -and $t.groupIDs.Count -gt 0) {
                $gid = "$($t.groupIDs[-1])"
                if ($groups.ContainsKey($gid)) { $groupName = $groups[$gid] }
            }
            $filePath = ""
            if ($t.url) { $filePath = ($t.url -replace '^file:///', '') -replace '/', '\' }
            $tests["$($t.id)"] = @{
                id         = "$($t.id)"
                name       = [string]$t.name
                groupName  = $groupName
                filePath   = $filePath
                status     = "running"
                durationMs = 0
                hidden     = $false
                error      = $null
            }
        }
        "testDone" {
            $tid = "$($ev.testID)"
            if ($tests.ContainsKey($tid)) {
                $tests[$tid].status     = if ([bool]$ev.skipped) { "skip" } `
                    elseif ($ev.result -eq "success") { "pass" } else { "fail" }
                $tests[$tid].durationMs = [int]$ev.time
                $tests[$tid].hidden     = [bool]$ev.hidden
            }
        }
        "error" {
            $tid = "$($ev.testID)"
            if ($tests.ContainsKey($tid)) {
                $tests[$tid].error = @{ message = [string]$ev.error; stack = [string]$ev.stackTrace }
            }
        }
        "print" {
            $tid = "$($ev.testID)"
            if ($ev.message -and $tests.ContainsKey($tid)) {
                try {
                    $inner = $ev.message | ConvertFrom-Json -ErrorAction Stop
                    if ($inner.type -eq 'test_output') { $tests[$tid].testOutput = $inner }
                } catch {}
            }
        }
        "done" { $totalMs = [int]$ev.time }
    }
}

# ── Classify ───────────────────────────────────────────────────────────────────

function Get-ContractType {
    param([string]$groupName, [string]$testName)
    switch -Regex ($groupName) {
        'schema invariants'              { return 'INV' }
        'no-inference'                   { return 'INV' }
        'semantic assertions'            { return 'DIR' }
        'temporal reference|edge cases'  { return 'Scenario' }
        default                          { return 'Scenario' }
    }
}

$realTests = @($tests.Values | Where-Object {
    -not $_.hidden -and $_.name -notmatch '^loading ' -and $_.status -ne 'running'
})

$items = @($realTests | ForEach-Object {
    $ct = Get-ContractType $_.groupName $_.name
    @{
        id         = $_.id
        name       = $_.name
        group      = $_.groupName
        file       = $_.filePath
        status     = $_.status
        durationMs = $_.durationMs
        tags       = @($ct)
        failure    = $_.error
        testOutput = $_.testOutput
    }
})

# ── Summary ────────────────────────────────────────────────────────────────────

$total   = $items.Count
$passed  = @($items | Where-Object { $_.status -eq 'pass' }).Count
$failed  = @($items | Where-Object { $_.status -eq 'fail' }).Count
$skipped = @($items | Where-Object { $_.status -eq 'skip' }).Count
$rate    = if ($total -gt 0) { [math]::Round($passed / $total, 4) } else { 0.0 }

function Get-CategoryMetrics {
    param($items, [string]$tag)
    $cat = @($items | Where-Object { $_.tags -contains $tag })
    @{
        total      = $cat.Count
        passed     = @($cat | Where-Object { $_.status -eq 'pass' }).Count
        violations = @($cat | Where-Object { $_.status -eq 'fail' }).Count
    }
}

$genMetrics = @{
    inv      = Get-CategoryMetrics $items 'INV'
    dir      = Get-CategoryMetrics $items 'DIR'
    scenario = Get-CategoryMetrics $items 'Scenario'
}

# ── Build report ───────────────────────────────────────────────────────────────

$report = [ordered]@{
    meta = [ordered]@{
        run_id    = "integration_$TIMESTAMP"
        layer     = "integration"
        timestamp = (Get-Date -Format "o")
        durationMs = if ($totalMs -gt 0) { $totalMs } else { $WALL_MS }
        runner    = "flutter-test"
        model     = $AI_MODEL
        liveFire  = $true
        apiTarget = $API_TARGET
        exitCode  = $EXIT_CODE
        label     = $Label
    }
    summary = [ordered]@{
        total    = $total
        passed   = $passed
        failed   = $failed
        skipped  = $skipped
        passRate = $rate
    }
    generativeMetrics = $genMetrics
    tests = $items
}

$report | ConvertTo-Json -Depth 20 | Out-File -FilePath $OUT_FILE -Encoding utf8
Write-Host "[OK] Report  → $OUT_FILE" -ForegroundColor Green

# ── Append history ─────────────────────────────────────────────────────────────

$histEntry = [ordered]@{
    run_id     = $report.meta.run_id
    layer      = "integration"
    timestamp  = $report.meta.timestamp
    durationMs = $report.meta.durationMs
    passRate   = $rate
    liveFire   = $true
    apiTarget  = $API_TARGET
    model      = $AI_MODEL
    summary    = $report.summary
    generativeMetrics = $genMetrics
}
($histEntry | ConvertTo-Json -Compress -Depth 10) | Add-Content -Path $HISTORY -Encoding utf8
Write-Host "[OK] History → $HISTORY" -ForegroundColor Green

# ── Regenerate dashboard ───────────────────────────────────────────────────────

& (Join-Path $PSScriptRoot "_generate_dashboard_data.ps1")

# ── Print summary ──────────────────────────────────────────────────────────────

Write-Host ""
$col = if ($rate -ge 0.9) { "Green" } elseif ($rate -ge 0.75) { "Yellow" } else { "Red" }
Write-Host "Integration Layer (live fire): $passed/$total passed ($([math]::Round($rate * 100, 1))%)" -ForegroundColor $col

foreach ($key in @('inv', 'dir', 'scenario')) {
    $m = $genMetrics[$key]
    if ($m.total -gt 0) {
        $vc = if ($m.violations -eq 0) { "Green" } else { "Red" }
        Write-Host ("  {0,-10} {1}/{2}  violations: {3}" -f $key.ToUpper(), $m.passed, $m.total, $m.violations) -ForegroundColor $vc
    }
}

Write-Host ""
Write-Host "Open dashboard: $(Join-Path $REPO 'dashboard\index.html')" -ForegroundColor Cyan
