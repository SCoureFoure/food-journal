@echo off
setlocal

:: ── config ──────────────────────────────────────────────────────────────────
if defined ANDROID_ADB (set ADB=%ANDROID_ADB%) else (set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe)
set PKG=com.foodjournal.app
set ACTIVITY=.MainActivity
set SCREENSHOTS_DIR=%~dp0screenshots
set APP_DIR=%~dp0app

:: ── detect device ───────────────────────────────────────────────────────────
"%ADB%" devices > "%TEMP%\adb_devices.txt" 2>&1
for /f "tokens=1" %%d in ('findstr /v "List" "%TEMP%\adb_devices.txt" ^| findstr /r "device$"') do (
    set DEVICE=%%d
    goto :found
)
echo No device found. Start emulator or plug in phone.
exit /b 1

:found
echo Device: %DEVICE%

:: ── build APK ───────────────────────────────────────────────────────────────
echo.
echo Building debug APK...
cd /d %APP_DIR%
flutter build apk --debug --no-pub
if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo Build failed - APK not found.
    exit /b 1
)

:: ── install ─────────────────────────────────────────────────────────────────
echo.
echo Installing...
"%ADB%" -s %DEVICE% install -r "build\app\outputs\flutter-apk\app-debug.apk"

:: ── pre-grant notification permission ──────────────────────────────────────
"%ADB%" -s %DEVICE% shell pm grant %PKG% android.permission.POST_NOTIFICATIONS 2>nul

:: ── clear old logcat ────────────────────────────────────────────────────────
"%ADB%" -s %DEVICE% logcat -c

:: ── launch app ──────────────────────────────────────────────────────────────
echo.
echo Launching app...
"%ADB%" -s %DEVICE% shell am start -n %PKG%/%ACTIVITY%
timeout /t 5 /nobreak >nul

:: ── capture screenshot ──────────────────────────────────────────────────────
set SCREENSHOT=%SCREENSHOTS_DIR%\latest.png
echo.
echo Capturing screenshot to %SCREENSHOT%...
"%ADB%" -s %DEVICE% exec-out screencap -p > "%SCREENSHOT%"

:: ── dump flutter logs ────────────────────────────────────────────────────────
set LOG_FILE=%SCREENSHOTS_DIR%\flutter_log_latest.txt
echo Dumping flutter logs to %LOG_FILE%...
"%ADB%" -s %DEVICE% logcat -d -s flutter > "%LOG_FILE%" 2>&1

echo.
echo Done.
echo   Screenshot: %SCREENSHOT%
echo   Log:        %LOG_FILE%
