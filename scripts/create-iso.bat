@echo off
REM === create-iso.bat ===
REM Batch script to create an ISO from a folder using mkisofs on Windows

REM Set mkisofs path (update if you install elsewhere)
set "MKISOFS_PATH=%~dp0mkisofs-md5-2.01-Binary\Binary\MinGW\Gcc-4.4.5\mkisofs.exe"
set "MKISOFS_ZIP_URL=https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/mkisofs-md5/mkisofs-md5-2.01-Binary.zip"
set "MKISOFS_ZIP=%TEMP%\mkisofs-md5-2.01-Binary.zip"
set "MKISOFS_EXTRACT=%~dp0"
set "OUTPUT_ISO=%USERPROFILE%\Downloads\output.iso"

REM Check if mkisofs exists, if not, download and extract automatically
if not exist "%MKISOFS_PATH%" (
    echo mkisofs.exe not found. Attempting to download and extract mkisofs-md5-2.01-Binary.zip ...
    powershell -Command "try { Invoke-WebRequest -Uri '%MKISOFS_ZIP_URL%' -OutFile '%MKISOFS_ZIP%' -ErrorAction Stop } catch { Write-Host 'Download failed. Please download manually from %MKISOFS_ZIP_URL%' -ForegroundColor Red; exit 1 }"
    if exist "%MKISOFS_ZIP%" (
        powershell -Command "Expand-Archive -Path '%MKISOFS_ZIP%' -DestinationPath '%MKISOFS_EXTRACT%' -Force"
        del /Q "%MKISOFS_ZIP%"
    )
)

REM Check again after extraction
if not exist "%MKISOFS_PATH%" (
    echo ERROR: mkisofs.exe not found at %MKISOFS_PATH%
    echo Please download and extract mkisofs from:
    echo %MKISOFS_ZIP_URL%
    echo and update MKISOFS_PATH in this script if needed.
    pause
    exit /b 1
)

REM Delete previous ISO if exists
REM if exist "%OUTPUT_ISO%" del /Q "%OUTPUT_ISO%"

echo --------------------------------------------------------------
set /p Input=Enter the folder name (relative to this script, or . for current directory):

REM Create ISO
"%MKISOFS_PATH%" -J -l -R -iso-level 4 -o "%OUTPUT_ISO%" "%Input%"

echo --------------------------------------------------------------
if exist "%OUTPUT_ISO%" (
    echo ISO created: %OUTPUT_ISO%
) else (
    echo ERROR: ISO creation failed.
)
echo Done. Exiting in 5 seconds!
ping 127.0.0.1 -n 5 > nul
