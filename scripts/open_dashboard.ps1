$REPO      = Split-Path $PSScriptRoot -Parent
$DASH_HTML = Join-Path $REPO "dashboard\index.html"

# Regenerate data.js from whatever reports exist on disk
& (Join-Path $PSScriptRoot "_generate_dashboard_data.ps1")

# Open in default browser
Start-Process $DASH_HTML
Write-Host "[>>] Dashboard open: $DASH_HTML" -ForegroundColor Cyan
