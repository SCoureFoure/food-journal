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

# Taps near the TOP of an element's bounds — use for ExpansionTile headers
# when the tile may be expanded (center would land in content, not header)
function Tap-ElementHeader {
    param([string]$Id, [int]$TopOffset = 50)
    Log-Step "tapping header of [$Id]..."
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml 2>$null | Out-String
    if ($xml -match "resource-id=""$([regex]::Escape($Id))""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""") {
        $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
        $cy = [int]$Matches[2] + $TopOffset
        & $ADB -s $DEVICE shell input tap $cx $cy
        Log-Found "tapped header of [$Id] at ($cx, $cy)"
        return $true
    }
    Log-Warn "[$Id] not found for header tap"
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

function Go-Collapsible {
    # Step 1: initial home state
    Log-Step "COLLAPSIBLE: capturing initial home state..."
    Save-Screenshot "01-home-initial"

    # Discover visible meal tiles
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml | Out-String
    $mealIds = [regex]::Matches($xml, 'resource-id="(meal-tile-\d+)"') | ForEach-Object { $_.Groups[1].Value }

    if ($mealIds.Count -eq 0) {
        Log-Warn "No meal-tile-* anchors found - is Today section expanded?"
        return
    }
    Log-Ok "Found $($mealIds.Count) meal tile(s): $($mealIds -join ', ')"

    # Step 2: expand first meal tile
    $first = $mealIds[0]
    Log-Step "COLLAPSIBLE: expanding [$first]..."
    Tap-Element $first
    Start-Sleep -Seconds 2
    Save-Screenshot "02-meal1-expanded"

    # Step 3: scroll down to show full expanded content + second meal tile
    & $ADB -s $DEVICE shell input swipe 540 1200 540 400 500
    Start-Sleep -Seconds 1
    Save-Screenshot "03-meal1-scrolled"

    # Step 4: expand second meal tile - tap from current scroll position
    # (meal-tile-10 is visible in the scrolled view, no need to scroll back up)
    if ($mealIds.Count -gt 1) {
        $second = $mealIds[1]
        Log-Step "COLLAPSIBLE: expanding [$second]..."
        Tap-Element $second
        Start-Sleep -Seconds 2
        Save-Screenshot "04-meal2-expanded"
    }

    # Step 5: scroll to top, then collapse first meal tile via header tap
    & $ADB -s $DEVICE shell input keyevent KEYCODE_MOVE_HOME
    & $ADB -s $DEVICE shell input swipe 540 400 540 1800 800
    Start-Sleep -Seconds 1
    Log-Step "COLLAPSIBLE: collapsing [$first]..."
    Tap-ElementHeader $first
    Start-Sleep -Seconds 1
    Save-Screenshot "05-meal1-collapsed"

    Log-Ok "COLLAPSIBLE test sequence complete"
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
    "home"         { <# already there #> }
    "log-meal"     { Go-LogMeal }
    "export"       { Go-Export }
    "collapsible"  { Go-Collapsible }
    default        { Log-Warn "Unknown scenario '$Scenario' - staying on home" }
}

# ── capture ───────────────────────────────────────────────────────────────────
Save-Screenshot $Scenario
Save-UIXml
Save-Logs

Write-Host ""
Log-Ok "DONE  task=$TASK"
Log-Ok "      $SHOTS"
