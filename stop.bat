@echo off
echo [food-journal] Stopping Flutter processes...

REM Kill dart (covers flutter run, build_runner, etc.)
taskkill /F /IM dart.exe /T >nul 2>&1
if %errorlevel% equ 0 (
    echo   dart.exe stopped
) else (
    echo   dart.exe not running
)

REM Kill flutter tool itself if stuck
taskkill /F /IM flutter.exe /T >nul 2>&1
if %errorlevel% equ 0 (
    echo   flutter.exe stopped
) else (
    echo   flutter.exe not running
)

echo Done.
