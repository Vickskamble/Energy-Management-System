@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================================
REM PowerEMS - Web build + deploy-folder pipeline (Vercel / app.brilliants.in)
REM
REM   1. Read version from pubspec.yaml
REM   2. flutter build web --release  (serves at root "/")
REM   3. Sync build\web -^> web-deploy\  (deployable folder, git repo for Vercel)
REM   4. Commit hint (you push; Vercel auto-deploys)
REM ============================================================================

cd /d "%~dp0"

for /f "usebackq tokens=2 delims=: " %%v in (`findstr /b "^version:" pubspec.yaml`) do set "FULL_VERSION=%%v"
for /f "delims=+" %%a in ("%FULL_VERSION%") do set "APP_VERSION=%%a"
if "%APP_VERSION%"=="" (
  echo [ERROR] Could not read version from pubspec.yaml
  exit /b 1
)
echo [1/4] Application version: %APP_VERSION%

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter not found on PATH.
  exit /b 1
)
echo [2/4] flutter build web --release ...
call flutter build web --release --base-href /
if errorlevel 1 (
  echo [ERROR] flutter build web failed.
  exit /b 1
)
if not exist "build\web\index.html" (
  echo [ERROR] build\web\index.html missing.
  exit /b 1
)

echo [3/4] Syncing to web-deploy\ ...
if not exist "web-deploy" mkdir "web-deploy"
robocopy "build\web" "web-deploy" /MIR /XD .git /NJH /NJS /NFL /NDL
if errorlevel 8 (
  echo [ERROR] robocopy failed with code %errorlevel%
  exit /b 1
)

echo [4/4] Deploy folder ready: web-deploy\  (v%APP_VERSION%)
echo.
echo Next steps ^(one-time, done after creating the GitHub repo^):
echo   cd web-deploy
echo   git add -A
echo   git commit -m "PowerEMS web v%APP_VERSION%"
echo   git push origin main
echo   Vercel auto-deploys to app.brilliants.in
echo.
endlocal
exit /b 0