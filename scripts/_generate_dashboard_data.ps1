$REPO        = Split-Path $PSScriptRoot -Parent
$REPORTS_DIR = Join-Path $REPO "reports"
$HISTORY     = Join-Path $REPORTS_DIR "history.jsonl"
$DASH_DIR    = Join-Path $REPO "dashboard"
$DATA_FILE   = Join-Path $DASH_DIR "data.js"

New-Item -ItemType Directory -Force -Path $DASH_DIR | Out-Null

$layers = @("ai", "unit", "integration", "e2e")
$layerData = [ordered]@{}

foreach ($layer in $layers) {
    $dir = Join-Path $REPORTS_DIR $layer
    $latest = $null
    if (Test-Path $dir) {
        $f = Get-ChildItem $dir -Filter "*.json" -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First 1
        if ($f) {
            try { $latest = Get-Content $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json }
            catch {}
        }
    }
    $layerData[$layer] = [ordered]@{ latest = $latest; history = @() }
}

# Distribute history entries to layers, keep last 50 per layer
if (Test-Path $HISTORY) {
    $histByLayer = @{}
    foreach ($l in $layers) { $histByLayer[$l] = [System.Collections.Generic.List[object]]::new() }

    foreach ($line in (Get-Content $HISTORY -Encoding utf8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $e = $line | ConvertFrom-Json
            if ($e.layer -and $histByLayer.ContainsKey($e.layer)) {
                $histByLayer[$e.layer].Add($e)
            }
        } catch { continue }
    }

    foreach ($l in $layers) {
        $all = @($histByLayer[$l])
        $layerData[$l].history = if ($all.Count -gt 50) {
            @($all | Select-Object -Last 50)
        } else { $all }
    }
}

# Build JSON manually — avoids PS5.1 collapsing single-element arrays to objects
$layerParts = @{}
foreach ($l in $layers) {
    $ld = $layerData[$l]
    $latestJson = if ($ld.latest) { $ld.latest | ConvertTo-Json -Depth 25 -Compress } else { "null" }
    $histItems  = @($ld.history)
    $histJson   = if ($histItems.Count -eq 0) {
        "[]"
    } else {
        "[" + (($histItems | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 10 }) -join ",") + "]"
    }
    $layerParts[$l] = "{`"latest`":$latestJson,`"history`":$histJson}"
}

$layersJson  = "{" + (($layers | ForEach-Object { "`"$_`":" + $layerParts[$_] }) -join ",") + "}"
$generated   = (Get-Date -Format "o") -replace '"', '\"'
$outputJson  = "{`"generated`":`"$generated`",`"layers`":$layersJson}"

"window.DASHBOARD_DATA = $outputJson;" | Out-File -FilePath $DATA_FILE -Encoding utf8
Write-Host "[OK] data.js  → $DATA_FILE" -ForegroundColor Green
