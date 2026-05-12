@echo off
setlocal

set APP_DIR=%~dp0app

echo [food-journal] Setup starting...

REM --- verify flutter available ---
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: flutter not found in PATH. Install Flutter SDK first.
    exit /b 1
)

REM --- verify .env exists ---
if not exist "%APP_DIR%\.env" (
    echo ERROR: app\.env not found. Create it with ANTHROPIC_API_KEY=sk-ant-...
    exit /b 1
)

cd /d "%APP_DIR%"

REM --- dependencies ---
echo.
echo [1/3] flutter pub get...
call flutter pub get
if %errorlevel% neq 0 (
    echo FAILED: flutter pub get
    exit /b 1
)

REM --- drift codegen ---
echo.
echo [2/3] drift codegen (build_runner)...
call dart run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo FAILED: build_runner
    exit /b 1
)

REM --- launch ---
echo.
echo [3/3] Launching app (flutter run)...
echo       Hot reload: r  ^|  Hot restart: R  ^|  Quit: q
echo.
flutter run
