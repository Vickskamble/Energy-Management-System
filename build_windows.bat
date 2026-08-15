@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================================
REM PowerEMS - Windows release build + installer pipeline
REM Publisher: Brilliants Automation and Software Solutions
REM
REM Pipeline:
REM   1. Read version from pubspec.yaml
REM   2. flutter clean
REM   3. flutter pub get
REM   4. flutter build windows --release
REM   5. Verify release output (exe, engine dll, data\app.so, icudtl.dat, flutter_assets)
REM   6. Stage app-local VC++ runtime DLLs from the official Visual Studio
REM      redistributable folder (no client-side redist installation needed)
REM   7. Verify runtime DLLs and ems.exe imports via dumpbin
REM   8. Sign ems.exe (self-signed, best-effort)
REM   9. Compile the Inno Setup installer (PowerEMS.iss)
REM  10. Sign the installer (self-signed, best-effort)
REM  Output: dist\PowerEMS_Setup_vX.X.X.exe
REM
REM Stops with a clear error if any required file is missing.
REM
REM NOTE on cmd quirks: never echo a variable containing parentheses
REM (e.g. C:\Program Files (x86)\...) inside a parenthesized block, and keep
REM parenthesis-containing values quoted when used inside blocks.
REM ============================================================================

cd /d "%~dp0"

REM ---------------- 1. Version from pubspec.yaml ----------------
for /f "usebackq tokens=2 delims=: " %%v in (`findstr /b "^version:" pubspec.yaml`) do set "FULL_VERSION=%%v"
for /f "delims=+" %%a in ("%FULL_VERSION%") do set "APP_VERSION=%%a"
if "%APP_VERSION%"=="" (
  echo [ERROR] Could not read version from pubspec.yaml
  exit /b 1
)
echo [1/9] Application version: %APP_VERSION%

REM ---------------- 2. Locate Flutter ----------------
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter not found on PATH. Install Flutter and add it to PATH.
  exit /b 1
)
echo [2/9] flutter found.

REM ---------------- 3. Clean ----------------
echo [3/9] flutter clean ...
call flutter clean
if errorlevel 1 (
  echo [ERROR] flutter clean failed.
  exit /b 1
)

REM ---------------- 4. Pub get ----------------
echo [4/9] flutter pub get ...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed.
  exit /b 1
)

REM ---------------- 5. Build ----------------
echo [5/9] flutter build windows --release ...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] flutter build windows --release failed.
  exit /b 1
)

REM ---------------- 6. Verify release output ----------------
set "RELEASE_DIR=build\windows\x64\runner\Release"
set "FAILED="
if not exist "%RELEASE_DIR%\ems.exe"               set "FAILED=%FAILED% ems.exe"
if not exist "%RELEASE_DIR%\flutter_windows.dll"   set "FAILED=%FAILED% flutter_windows.dll"
if not exist "%RELEASE_DIR%\data\app.so"           set "FAILED=%FAILED% data\app.so"
if not exist "%RELEASE_DIR%\data\icudtl.dat"       set "FAILED=%FAILED% data\icudtl.dat"
if not exist "%RELEASE_DIR%\data\flutter_assets"   set "FAILED=%FAILED% data\flutter_assets"
if defined FAILED goto :err_release
echo [6/9] Release output verified: %RELEASE_DIR%

REM ---------------- 7. Stage app-local VC++ runtime DLLs ----------------
set "VSPATH="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :err_vswhere
for /f "usebackq delims=" %%v in (`"%VSWHERE%" -all -products * -property installationPath`) do set "VSPATH=%%v"
if "%VSPATH%"=="" goto :err_vs

set "CRT_DIR="
for /f "delims=" %%d in ('dir /b /ad "%VSPATH%\VC\Redist\MSVC" 2^>nul') do (
  if not defined CRT_DIR for /d %%e in ("%VSPATH%\VC\Redist\MSVC\%%d\x64\Microsoft.VC1*.CRT") do set "CRT_DIR=%%e"
)
if not defined CRT_DIR goto :err_crt

for %%d in (msvcp140.dll vcruntime140.dll vcruntime140_1.dll) do (
  if not exist "%CRT_DIR%\%%d" goto :err_missing_crt
  copy /y "%CRT_DIR%\%%d" "%RELEASE_DIR%\%%d" >nul
  if errorlevel 1 goto :err_copy
)
for %%d in (msvcp140.dll vcruntime140.dll vcruntime140_1.dll) do (
  if not exist "%RELEASE_DIR%\%%d" goto :err_missing_runtime
)
echo [7/9] App-local VC++ runtime staged: msvcp140.dll vcruntime140.dll vcruntime140_1.dll

REM ---------------- 8. Verify imports of ems.exe ----------------
set "DUMPBIN="
for /f "delims=" %%d in ('dir /b /ad "%VSPATH%\VC\Tools\MSVC" 2^>nul') do (
  if not defined DUMPBIN if exist "%VSPATH%\VC\Tools\MSVC\%%d\bin\Hostx64\x64\dumpbin.exe" set "DUMPBIN=%VSPATH%\VC\Tools\MSVC\%%d\bin\Hostx64\x64\dumpbin.exe"
)
if not defined DUMPBIN (
  echo [WARNING] dumpbin not found - skipping import verification.
  goto :compile
)
"%DUMPBIN%" /dependents "%RELEASE_DIR%\ems.exe" > "%TEMP%\powerems_imports.txt" 2>nul
findstr /i "MSVCP140.dll VCRUNTIME140.dll VCRUNTIME140_1.dll" "%TEMP%\powerems_imports.txt" >nul
if errorlevel 1 (
  echo [WARNING] could not confirm VC++ imports on ems.exe.
  goto :compile
)
del "%TEMP%\powerems_imports.txt" >nul 2>nul
echo [8/9] Dependency check passed: ems.exe resolves MSVCP140/VCRUNTIME140 app-local.

REM ---------------- 8b. Sign ems.exe (self-signed, best-effort) ----------------
powershell -NoProfile -ExecutionPolicy Bypass -File "windows\sign_powerems.ps1" -Target "%RELEASE_DIR%\ems.exe"
if errorlevel 1 echo [WARNING] could not sign ems.exe - continuing unsigned.

:compile
REM ---------------- 9. Compile Inno Setup installer ----------------
set "ISCC="
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not defined ISCC goto :err_iscc

echo [9/9] Compiling installer with Inno Setup ...
"%ISCC%" windows\PowerEMS.iss /DAppVersion=%APP_VERSION%
if errorlevel 1 goto :err_iscc_build

set "INSTALLER=dist\PowerEMS_Setup_v%APP_VERSION%.exe"
if not exist "%INSTALLER%" goto :err_installer

REM ---------------- 10. Sign installer (self-signed, best-effort) ----------------
powershell -NoProfile -ExecutionPolicy Bypass -File "windows\sign_powerems.ps1" -Target "%INSTALLER%"
if errorlevel 1 echo [WARNING] could not sign installer - continuing unsigned.

echo.
echo ============================================================================
echo BUILD SUCCESSFUL
echo   Version:     %APP_VERSION%
echo   Release dir: %RELEASE_DIR%
echo   Installer:   %INSTALLER%
echo ============================================================================
endlocal
exit /b 0

REM ---------------- Error handlers ----------------
:err_release
echo [ERROR] Missing required release files:%FAILED%
echo         Expected complete Flutter output in %RELEASE_DIR%
exit /b 1

:err_vswhere
echo [ERROR] vswhere not found. Visual Studio Build Tools are required.
exit /b 1

:err_vs
echo [ERROR] Visual Studio installation not found.
exit /b 1

:err_crt
echo [ERROR] VC++ redistributable x64 CRT folder not found under %VSPATH%\VC\Redist\MSVC
exit /b 1

:err_missing_crt
echo [ERROR] a required VC++ runtime DLL was not found in %CRT_DIR%
exit /b 1

:err_copy
echo [ERROR] failed to copy %CRT_DIR% to %RELEASE_DIR%
exit /b 1

:err_missing_runtime
echo [ERROR] a staged runtime DLL is missing from the release dir.
exit /b 1

:err_iscc
echo [ERROR] Inno Setup 6 (ISCC.exe) not found. Install Inno Setup 6.
exit /b 1

:err_iscc_build
echo [ERROR] Inno Setup compilation failed.
exit /b 1

:err_installer
echo [ERROR] Installer not created: %INSTALLER%
exit /b 1