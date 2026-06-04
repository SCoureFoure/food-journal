param(
    [string]$Label = ""
)

$REPO      = Split-Path $PSScriptRoot -Parent
$APP       = Join-Path $REPO "app"
$RPTS_UNIT = Join-Path $REPO "reports\unit"
$HISTORY   = Join-Path $REPO "reports\history.jsonl"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OUT_FILE  = Join-Path $RPTS_UNIT "$TIMESTAMP.json"

New-Item -ItemType Directory -Force -Path $RPTS_UNIT | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $HISTORY) | Out-Null

# ── Sanitizer ──────────────────────────────────────────────────────────────────
# Reports are committed — strip the absolute repo path (embeds local username)
# to a relative path before persisting file paths / stack traces.
$REPO_FWD = $REPO -replace '\\', '/'
function Hide-Repo([string]$s) {
    if (-not $s) { return $s }
    foreach ($p in @("$REPO\", $REPO, "$REPO_FWD/", $REPO_FWD)) {
        $s = $s -replace [regex]::Escape($p), ''
    }
    return $s
}

# Unit tests: models, services (non-AI), widgets, top-level files
# Excludes meal_memory/ (ai layer) and integration/ (integration layer)
$testPaths = @(
    "test/export_import_test.dart",
    "test/widget_test.dart",
    "test/models/",
    "test/services/import_selection_test.dart",
    "test/services/worker_ai_service_test.dart",
    "test/widgets/"
)

# ── Run flutter test ───────────────────────────────────────────────────────────

Write-Host "[..] Running unit layer tests..." -ForegroundColor Cyan
$START_TIME = Get-Date

Push-Location $APP
$rawLines = @(& flutter test @testPaths --reporter json 2>$null)
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
            if ($t.url) { $filePath = Hide-Repo ((($t.url -replace '^file:///', '') -replace '/', '\')) }
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
                $tests[$tid].error = @{ message = Hide-Repo ([string]$ev.error); stack = Hide-Repo ([string]$ev.stackTrace) }
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

# ── Classify by contract type ──────────────────────────────────────────────────

function Get-ContractType {
    param([hashtable]$t)
    $groupName = $t.groupName

    # Priority 1: enriched testOutput.testTheory
    if ($t.testOutput -and $t.testOutput.testTheory) {
        switch ($t.testOutput.testTheory) {
            'MFT'        { return 'MFT'      }
            'INV'        { return 'INV'      }
            'DIR'        { return 'DIR'      }
            'BVA'        { return 'Boundary' }
            'EQUIV'      { return 'Scenario' }
            'FP'         { return 'Scenario' }
            'REGRESSION' { return 'Scenario' }
        }
    }

    # Priority 2: [XXX] bracket prefix in group name
    if ($groupName -match '^\[(\w+)\]') {
        switch ($Matches[1].ToUpper()) {
            'MFT' { return 'MFT'      }
            'INV' { return 'INV'      }
            'DIR' { return 'DIR'      }
            'BVA' { return 'Boundary' }
        }
    }

    # Priority 3: fallback for un-tagged groups
    switch -Regex ($groupName) {
        'round.trip|round_trip|invariant|invarianc' { return 'INV'      }
        'static helpers|rendering|formatting'       { return 'MFT'      }
        'boundary|edge|null field'                  { return 'Boundary' }
        default                                     { return 'Scenario' }
    }
}

$realTests = @($tests.Values | Where-Object {
    -not $_.hidden -and $_.name -notmatch '^loading ' -and $_.status -ne 'running'
})

$items = @($realTests | ForEach-Object {
    $ct  = Get-ContractType $_
    $out = $_.testOutput
    @{
        id          = $_.id
        name        = $_.name
        group       = $_.groupName
        file        = $_.filePath
        status      = $_.status
        durationMs  = $_.durationMs
        tags        = @($ct)
        failure     = $_.error
        testOutput  = $out
        contract    = if ($out) { $out.contract }    else { $null }
        implication = if ($out) { $out.implication } else { $null }
        rationale   = if ($out) { $out.rationale }   else { $null }
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
    mft      = Get-CategoryMetrics $items 'MFT'
    inv      = Get-CategoryMetrics $items 'INV'
    dir      = Get-CategoryMetrics $items 'DIR'
    boundary = Get-CategoryMetrics $items 'Boundary'
    scenario = Get-CategoryMetrics $items 'Scenario'
}

# ── Build report ───────────────────────────────────────────────────────────────

$report = [ordered]@{
    meta = [ordered]@{
        run_id     = "unit_$TIMESTAMP"
        layer      = "unit"
        timestamp  = (Get-Date -Format "o")
        durationMs = if ($totalMs -gt 0) { $totalMs } else { $WALL_MS }
        runner     = "flutter-test"
        exitCode   = $EXIT_CODE
        label      = $Label
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

# ── Append history entry ───────────────────────────────────────────────────────

$histEntry = [ordered]@{
    run_id     = $report.meta.run_id
    layer      = "unit"
    timestamp  = $report.meta.timestamp
    durationMs = $report.meta.durationMs
    passRate   = $rate
    summary    = $report.summary
    generativeMetrics = $genMetrics
}
($histEntry | ConvertTo-Json -Compress -Depth 10) | Add-Content -Path $HISTORY -Encoding utf8
Write-Host "[OK] History → $HISTORY" -ForegroundColor Green

# ── Regenerate dashboard data.js ───────────────────────────────────────────────

& (Join-Path $PSScriptRoot "_generate_dashboard_data.ps1")

# ── Print summary ──────────────────────────────────────────────────────────────

Write-Host ""
$col = if ($rate -ge 0.9) { "Green" } elseif ($rate -ge 0.75) { "Yellow" } else { "Red" }
Write-Host "Unit Layer: $passed/$total passed ($([math]::Round($rate * 100, 1))%)" -ForegroundColor $col

foreach ($key in @('mft', 'inv', 'dir', 'boundary', 'scenario')) {
    $m = $genMetrics[$key]
    if ($m.total -gt 0) {
        $vc = if ($m.violations -eq 0) { "Green" } else { "Red" }
        Write-Host ("  {0,-10} {1}/{2}  violations: {3}" -f $key.ToUpper(), $m.passed, $m.total, $m.violations) -ForegroundColor $vc
    }
}

Write-Host ""
Write-Host "Open dashboard: $(Join-Path $REPO 'dashboard\index.html')" -ForegroundColor Cyan
