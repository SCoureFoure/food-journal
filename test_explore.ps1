param(
    [string]$Scenario = "home"
)

$ADB      = "C:\Users\SCora\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$PKG      = "com.foodjournal.app"
$ACTIVITY = ".MainActivity"
$REPO     = $PSScriptRoot
$APP_DIR  = Join-Path $REPO "app"
$APK      = Join-Path $APP_DIR "build\app\outputs\flutter-apk\app-debug.apk"

$TASK     = "explore-$Scenario-$(Get-Date -Format 'yyyyMMdd-HHmm')"
$SHOTS    = Join-Path $REPO "scratch\$TASK"
New-Item -ItemType Directory -Force -Path $SHOTS | Out-Null
$TASK | Out-File -FilePath (Join-Path $REPO "scratch\.last") -Encoding utf8 -NoNewline

# ── task folder ───────────────────────────────────────────────────────────────
# All outputs land in scratch/<task>/ — find past runs there.

# ── logging ───────────────────────────────────────────────────────────────────
function Log-Ok    { param($m) Write-Host "[OK] $m" -ForegroundColor Green }
function Log-Step  { param($m) Write-Host "[..] $m" -ForegroundColor Cyan }
function Log-Done  { param($m) Write-Host "[>>] $m" -ForegroundColor Green }
function Log-Wait  { param($m) Write-Host "  ~  $m" -ForegroundColor Yellow }
function Log-Found { param($m) Write-Host "  v  $m" -ForegroundColor Green }
function Log-Warn  { param($m) Write-Host "[!!] $m" -ForegroundColor Yellow }
function Log-Fail  { param($m) Write-Host "[XX] $m" -ForegroundColor Red }

# ── adb helpers ───────────────────────────────────────────────────────────────

function Wait-Foreground {
    param([string]$Pkg, [int]$TimeoutSec = 20)
    Log-Wait "app foreground ($Pkg)..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $line = & $ADB -s $DEVICE shell dumpsys activity activities | Select-String "topResumedActivity"
        if ($line -match [regex]::Escape($Pkg)) { Log-Found "app in foreground"; return $true }
        Start-Sleep -Milliseconds 400
    }
    Log-Warn "TIMEOUT waiting for foreground"
    return $false
}

function Wait-Element {
    param([string]$Id, [int]$TimeoutSec = 30)
    Log-Wait "element [$Id]..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
        $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml 2>$null
        if ($xml -match "resource-id=""$([regex]::Escape($Id))""") { Log-Found "found [$Id]"; return $true }
        Start-Sleep -Milliseconds 600
    }
    Log-Warn "TIMEOUT waiting for [$Id]"
    return $false
}

function Wait-SplashGone {
    param([int]$TimeoutSec = 15)
    Log-Wait "splash to dismiss..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $splash = & $ADB -s $DEVICE shell dumpsys window | Select-String "Splash Screen $PKG"
        if (-not $splash) { Log-Found "splash gone"; return }
        Start-Sleep -Milliseconds 300
    }
    Log-Warn "splash timeout (continuing)"
}

function Tap-Element {
    param([string]$Id)
    Log-Step "tapping [$Id]..."
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml 2>$null | Out-String
    if ($xml -match "resource-id=""$([regex]::Escape($Id))""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""") {
        $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
        $cy = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
        & $ADB -s $DEVICE shell input tap $cx $cy
        Log-Found "tapped [$Id] at ($cx, $cy)"
        return $true
    }
    Log-Warn "[$Id] not found for tap"
    return $false
}

function Save-Screenshot {
    param([string]$Name = "latest")
    $path = Join-Path $SHOTS "$Name.png"
    cmd /c "`"$ADB`" -s $DEVICE exec-out screencap -p > `"$path`""
    Log-Done "screenshot -> $path"
    return $path
}

function Save-UIXml {
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    & $ADB -s $DEVICE pull /sdcard/ui.xml (Join-Path $SHOTS "ui.xml") | Out-Null
    Log-Done "ui.xml -> $SHOTS\ui.xml"
}

function Save-Logs {
    $path = Join-Path $SHOTS "flutter_log_latest.txt"
    & $ADB -s $DEVICE logcat -d -s flutter | Out-File -FilePath $path -Encoding utf8
    Log-Done "logs -> $path"
}

# ── scenario navigation ───────────────────────────────────────────────────────
# Each scenario: navigate from home to target, return anchor to wait for

function Go-LogMeal {
    Tap-Element "btn-log-meal"
    Wait-Element "log-meal-input" | Out-Null   # anchor: text input on log meal screen
}

function Go-Export {
    Tap-Element "btn-export"
    Wait-Element "export-screen" | Out-Null    # anchor: export screen root
}

# ── device detect ─────────────────────────────────────────────────────────────
$lines = & $ADB devices | Where-Object { $_ -match "device$" -and $_ -notmatch "List" }
if (-not $lines) { Log-Fail "No device found."; exit 1 }
$DEVICE = ($lines -split "\s+")[0]
Log-Ok "Device: $DEVICE"

# ── build ─────────────────────────────────────────────────────────────────────
Log-Step "BUILD starting..."
Push-Location $APP_DIR
flutter build apk --debug --no-pub
if (-not (Test-Path $APK)) { Log-Fail "APK not found after build."; Pop-Location; exit 1 }
Pop-Location
Log-Done "BUILD complete"

# ── install ───────────────────────────────────────────────────────────────────
Log-Step "INSTALL starting..."
$result = & $ADB -s $DEVICE install -r $APK
Log-Done "INSTALL $($result -join ' ')"

# ── pre-grant + launch ────────────────────────────────────────────────────────
& $ADB -s $DEVICE shell pm grant $PKG android.permission.POST_NOTIFICATIONS 2>$null
& $ADB -s $DEVICE logcat -c
Log-Step "LAUNCH ($Scenario)..."
& $ADB -s $DEVICE shell am start -n "$PKG/$ACTIVITY" | Out-Null

# ── wait for home (always baseline) ──────────────────────────────────────────
Wait-Foreground $PKG | Out-Null
$homeReady = (Wait-Element "btn-log-meal") -or (Wait-Element "home-empty-state" -TimeoutSec 5)
if (-not $homeReady) { Log-Warn "home anchors not detected" }
Wait-SplashGone

# ── navigate to scenario ──────────────────────────────────────────────────────
switch ($Scenario) {
    "home"     { <# already there #> }
    "log-meal" { Go-LogMeal }
    "export"   { Go-Export }
    default    { Log-Warn "Unknown scenario '$Scenario' - staying on home" }
}

# ── capture ───────────────────────────────────────────────────────────────────
Save-Screenshot $Scenario
Save-UIXml
Save-Logs

Write-Host ""
Log-Ok "DONE  task=$TASK"
Log-Ok "      $SHOTS"
