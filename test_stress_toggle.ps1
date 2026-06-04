param(
    [int]$Cycles   = 25,
    [int]$DelayMs  = 400,
    [switch]$Build
)

$ADB      = if ($env:ANDROID_ADB) { $env:ANDROID_ADB } else { Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe" }
$PKG      = "com.foodjournal.app"
$ACTIVITY = ".MainActivity"
$REPO     = $PSScriptRoot
$APP_DIR  = Join-Path $REPO "app"
$APK      = Join-Path $APP_DIR "build\app\outputs\flutter-apk\app-debug.apk"

$TASK  = "stress-toggle-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$SHOTS = Join-Path $REPO "scratch\$TASK"
New-Item -ItemType Directory -Force -Path $SHOTS | Out-Null

function Log-Ok    { param($m) Write-Host "[OK] $m" -ForegroundColor Green }
function Log-Step  { param($m) Write-Host "[..] $m" -ForegroundColor Cyan }
function Log-Done  { param($m) Write-Host "[>>] $m" -ForegroundColor Green }
function Log-Wait  { param($m) Write-Host "  ~  $m" -ForegroundColor Yellow }
function Log-Found { param($m) Write-Host "  v  $m" -ForegroundColor Green }
function Log-Warn  { param($m) Write-Host "[!!] $m" -ForegroundColor Yellow }
function Log-Fail  { param($m) Write-Host "[XX] $m" -ForegroundColor Red }
function Log-Perf  { param($m) Write-Host "[PP] $m" -ForegroundColor Magenta }

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

function Find-DateAnchor {
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml 2>$null | Out-String
    $m = [regex]::Match($xml, 'resource-id="(date-section-[\d-]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Tap-ById {
    param([string]$Id)
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    $xml = & $ADB -s $DEVICE shell cat /sdcard/ui.xml 2>$null | Out-String
    if ($xml -match "resource-id=""$([regex]::Escape($Id))""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""") {
        $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
        $cy = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
        & $ADB -s $DEVICE shell input tap $cx $cy
        return $true
    }
    return $false
}

function Save-Screenshot {
    param([string]$Name)
    cmd /c "`"$ADB`" -s $DEVICE exec-out screencap -p > `"$(Join-Path $SHOTS "$Name.png")`""
}

function Save-UIXml {
    & $ADB -s $DEVICE shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
    & $ADB -s $DEVICE pull /sdcard/ui.xml (Join-Path $SHOTS "ui.xml") | Out-Null
}

# -- device detect --
$lines = & $ADB devices | Where-Object { $_ -match "device$" -and $_ -notmatch "List" }
if (-not $lines) { Log-Fail "No device found."; exit 1 }
$DEVICE = ($lines -split "\s+")[0]
Log-Ok "Device: $DEVICE"

# -- optional build --
if ($Build) {
    Log-Step "BUILD..."
    Push-Location $APP_DIR
    flutter build apk --debug --no-pub
    if (-not (Test-Path $APK)) { Log-Fail "APK not found."; Pop-Location; exit 1 }
    Pop-Location
    Log-Done "BUILD complete"
    Log-Step "INSTALL..."
    & $ADB -s $DEVICE install -r $APK | Out-Null
    Log-Done "INSTALL complete"
}

# -- clear logs + launch --
& $ADB -s $DEVICE logcat -c
Log-Step "LAUNCH..."
& $ADB -s $DEVICE shell am start -n "$PKG/$ACTIVITY" | Out-Null

Wait-Foreground $PKG | Out-Null
$homeReady = (Wait-Element "btn-log-meal") -or (Wait-Element "home-empty-state" -TimeoutSec 5) -or (Wait-Element "home-meal-list" -TimeoutSec 5)
if (-not $homeReady) { Log-Warn "home anchor not detected - continuing anyway" }
Wait-SplashGone

Start-Sleep -Seconds 2

# -- log marker --
& $ADB -s $DEVICE shell log -t STRESS_TEST "=== START cycles=$Cycles delay=${DelayMs}ms ==="

# -- find date anchor --
Log-Step "Searching for date-section-* anchor..."
$anchor = Find-DateAnchor
if (-not $anchor) {
    Log-Fail "No date-section-* anchor found. No data? Add entries first."
    & $ADB -s $DEVICE logcat -d | Out-File -FilePath (Join-Path $SHOTS "flutter_log.txt") -Encoding utf8
    exit 1
}
Log-Ok "Using anchor: [$anchor]"
Save-Screenshot "00-before"

# -- stress loop --
$successCount = 0
$failCount    = 0

Log-Step "Running $Cycles open/close cycles (delay=${DelayMs}ms)..."
$startTime = Get-Date

for ($i = 1; $i -le $Cycles; $i++) {
    $ok = Tap-ById $anchor
    if ($ok) {
        $successCount++
        if ($i % 5 -eq 0) {
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
            Log-Perf "Cycle $i/$Cycles - ${elapsed}s elapsed, $failCount misses so far"
            & $ADB -s $DEVICE shell log -t STRESS_TEST "cycle=$i elapsed=${elapsed}s"
        }
    } else {
        $failCount++
        Log-Warn "Cycle $i - anchor not found (miss #$failCount)"
    }
    Start-Sleep -Milliseconds $DelayMs
}

$totalSec = [int]((Get-Date) - $startTime).TotalSeconds
& $ADB -s $DEVICE shell log -t STRESS_TEST "=== END cycles=$Cycles success=$successCount fail=$failCount elapsed=${totalSec}s ==="

Start-Sleep -Seconds 1
Save-Screenshot "01-after"
Save-UIXml

# -- capture logcat --
$logPath = Join-Path $SHOTS "flutter_log.txt"
& $ADB -s $DEVICE logcat -d | Out-File -FilePath $logPath -Encoding utf8
Log-Done "logs -> $logPath"

# -- analyze --
$log        = Get-Content $logPath -Raw
$gcCount    = ([regex]::Matches($log, 'GC_CONCURRENT|GC_FOR_ALLOC|GC_EXPLICIT')).Count
$jankFrames = ([regex]::Matches($log, 'Skipped \d+ frames')).Count
$exceptions = ([regex]::Matches($log, 'Exception|FlutterError|FATAL')).Count
$memWarns   = ([regex]::Matches($log, 'onTrimMemory|Low Memory|OutOfMemory')).Count

Write-Host ""
Log-Ok "=========================================="
Log-Ok "STRESS TEST RESULTS"
Log-Ok "  Cycles:      $Cycles  (success=$successCount  fail=$failCount)"
Log-Ok "  Duration:    ${totalSec}s  (~$([math]::Round($totalSec/$Cycles,2))s/cycle)"
Log-Ok "  GC events:   $gcCount"
Log-Ok "  Jank frames: $jankFrames"
Log-Ok "  Exceptions:  $exceptions"
Log-Ok "  Mem warns:   $memWarns"
Log-Ok "=========================================="

if ($gcCount -gt 10)    { Log-Warn "HIGH GC: $gcCount events - possible leak or rebuild storm" }
if ($jankFrames -gt 0)  { Log-Warn "JANK: skipped-frame events in log" }
if ($exceptions -gt 0)  { Log-Warn "EXCEPTIONS: $exceptions found - check flutter_log.txt" }
if ($memWarns -gt 0)    { Log-Warn "MEMORY PRESSURE: $memWarns trim/OOM events" }

Write-Host ""
Log-Ok "Output: $SHOTS"
Log-Ok "Log:    $logPath"
