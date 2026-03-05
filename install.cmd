@echo off
setlocal enabledelayedexpansion

set "REPO=Varagos/rust-cli"
set "INSTALL_DIR=%USERPROFILE%\.bitloops\bin"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=latest"

call :validate_target "%TARGET%"
if errorlevel 1 exit /b 1

call :detect_target_triplet
if errorlevel 1 exit /b 1

call :require_cmd curl
if errorlevel 1 exit /b 1

call :require_cmd certutil
if errorlevel 1 exit /b 1

call :require_cmd tar
if errorlevel 1 exit /b 1

set "TMP_DIR=%TEMP%\bitloops-install-%RANDOM%%RANDOM%%RANDOM%"
mkdir "%TMP_DIR%" >nul 2>&1
if errorlevel 1 (
  echo Error: could not create temporary directory "%TMP_DIR%" >&2
  exit /b 1
)

set "ASSET_NAME=bitloops-%TARGET_TRIPLET%.zip"
set "CHECKSUMS_NAME=checksums-sha256.txt"
set "ASSET_PATH=%TMP_DIR%\%ASSET_NAME%"
set "CHECKSUMS_PATH=%TMP_DIR%\%CHECKSUMS_NAME%"
set "EXTRACT_DIR=%TMP_DIR%\extract"
set "TARGET_PATH=%INSTALL_DIR%\bitloops.exe"

if /I "%INSTALL_MODE%"=="latest" (
  set "ASSET_URL=https://github.com/%REPO%/releases/latest/download/%ASSET_NAME%"
  set "CHECKSUMS_URL=https://github.com/%REPO%/releases/latest/download/%CHECKSUMS_NAME%"
  set "DISPLAY_VERSION=latest"
) else (
  set "ASSET_URL=https://github.com/%REPO%/releases/download/%TAG%/%ASSET_NAME%"
  set "CHECKSUMS_URL=https://github.com/%REPO%/releases/download/%TAG%/%CHECKSUMS_NAME%"
  set "DISPLAY_VERSION=%TAG%"
)

echo Downloading %ASSET_NAME% (%DISPLAY_VERSION%)...
call :download_file "%ASSET_URL%" "%ASSET_PATH%"
if errorlevel 1 goto :fail

call :download_file "%CHECKSUMS_URL%" "%CHECKSUMS_PATH%"
if errorlevel 1 goto :fail

call :read_expected_checksum "%CHECKSUMS_PATH%" "%ASSET_NAME%"
if errorlevel 1 goto :fail

call :compute_sha256 "%ASSET_PATH%"
if errorlevel 1 goto :fail

if /I not "%EXPECTED_HASH%"=="%ACTUAL_HASH%" (
  echo Error: checksum mismatch for %ASSET_NAME% >&2
  echo Expected: %EXPECTED_HASH% >&2
  echo Actual:   %ACTUAL_HASH% >&2
  goto :fail
)

mkdir "%EXTRACT_DIR%" >nul 2>&1
if errorlevel 1 (
  echo Error: could not create extract directory "%EXTRACT_DIR%" >&2
  goto :fail
)

tar -xf "%ASSET_PATH%" -C "%EXTRACT_DIR%"
if errorlevel 1 (
  echo Error: failed to extract %ASSET_NAME% >&2
  goto :fail
)

set "BIN_PATH=%EXTRACT_DIR%\bitloops.exe"
if not exist "%BIN_PATH%" (
  for /r "%EXTRACT_DIR%" %%f in (bitloops.exe) do (
    set "BIN_PATH=%%f"
    goto :found_binary
  )
)

:found_binary
if not exist "%BIN_PATH%" (
  echo Error: extracted archive did not contain bitloops.exe >&2
  goto :fail
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" >nul 2>&1
if errorlevel 1 (
  echo Error: could not create install directory "%INSTALL_DIR%" >&2
  goto :fail
)

copy /Y "%BIN_PATH%" "%TARGET_PATH%" >nul
if errorlevel 1 (
  echo Error: failed to copy binary to %TARGET_PATH% >&2
  goto :fail
)

call :ensure_user_path "%INSTALL_DIR%"

echo Installed bitloops (%DISPLAY_VERSION%) to %TARGET_PATH%
if "%PATH_ADDED%"=="1" (
  echo Added %INSTALL_DIR% to user PATH. Restart your terminal for PATH changes to apply.
)

call :cleanup
exit /b 0

:fail
call :cleanup
exit /b 1

:cleanup
if defined TMP_DIR (
  if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%" >nul 2>&1
)
exit /b 0

:validate_target
set "INPUT=%~1"
if /I "%INPUT%"=="latest" (
  set "INSTALL_MODE=latest"
  exit /b 0
)

echo %INPUT% | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if not errorlevel 1 (
  set "INSTALL_MODE=tag"
  set "TAG=v%INPUT%"
  exit /b 0
)

echo %INPUT% | findstr /r "^v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if not errorlevel 1 (
  set "INSTALL_MODE=tag"
  set "TAG=%INPUT%"
  exit /b 0
)

echo Usage: %~nx0 [latest^|vX.Y.Z^|X.Y.Z] >&2
exit /b 1

:detect_target_triplet
if /I "%PROCESSOR_ARCHITEW6432%"=="ARM64" (
  set "TARGET_TRIPLET=aarch64-pc-windows-msvc"
  exit /b 0
)
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
  set "TARGET_TRIPLET=aarch64-pc-windows-msvc"
  exit /b 0
)
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set "TARGET_TRIPLET=x86_64-pc-windows-msvc"
  exit /b 0
)
if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
  set "TARGET_TRIPLET=x86_64-pc-windows-msvc"
  exit /b 0
)

echo Error: unsupported Windows architecture: arch=%PROCESSOR_ARCHITECTURE%, arch_w6432=%PROCESSOR_ARCHITEW6432% >&2
exit /b 1

:require_cmd
where "%~1" >nul 2>&1
if errorlevel 1 (
  echo Error: required command not found: %~1 >&2
  exit /b 1
)
exit /b 0

:download_file
set "URL=%~1"
set "OUTPUT=%~2"
curl -fsSL "%URL%" -o "%OUTPUT%"
if errorlevel 1 (
  echo Error: failed downloading %URL% >&2
  exit /b 1
)
exit /b 0

:read_expected_checksum
set "CHECKSUM_FILE=%~1"
set "ASSET=%~2"
set "EXPECTED_HASH="
for /f "usebackq tokens=1,2" %%a in ("%CHECKSUM_FILE%") do (
  if /I "%%b"=="%ASSET%" (
    set "EXPECTED_HASH=%%a"
    goto :checksum_found
  )
)

:checksum_found
if not defined EXPECTED_HASH (
  echo Error: checksum for %ASSET% not found in %CHECKSUM_FILE% >&2
  exit /b 1
)
exit /b 0

:compute_sha256
set "FILE_PATH=%~1"
set "ACTUAL_HASH="
for /f "skip=1 tokens=* delims=" %%i in ('certutil -hashfile "%FILE_PATH%" SHA256 ^| findstr /r /v /c:"^SHA256 hash of" /c:"^CertUtil:" /c:"^$"') do (
  set "ACTUAL_HASH=%%i"
  goto :hash_found
)

:hash_found
if not defined ACTUAL_HASH (
  echo Error: failed to compute SHA256 for %FILE_PATH% >&2
  exit /b 1
)

set "ACTUAL_HASH=%ACTUAL_HASH: =%"
exit /b 0

:ensure_user_path
set "PATH_ADDED=0"
set "TARGET_DIR=%~1"
set "USER_PATH="

for /f "tokens=2,*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul ^| find /i "Path"') do (
  set "USER_PATH=%%b"
)

if not defined USER_PATH (
  setx Path "%TARGET_DIR%" >nul
  if errorlevel 1 (
    echo Warning: failed to add %TARGET_DIR% to user PATH. >&2
    exit /b 0
  )
  set "PATH_ADDED=1"
  exit /b 0
)

echo ;%USER_PATH%; | findstr /I /C:";%TARGET_DIR%;" >nul
if errorlevel 1 (
  setx Path "%USER_PATH%;%TARGET_DIR%" >nul
  if errorlevel 1 (
    echo Warning: failed to add %TARGET_DIR% to user PATH. >&2
    exit /b 0
  )
  set "PATH_ADDED=1"
)
exit /b 0
