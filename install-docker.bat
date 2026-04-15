@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires administrator privileges.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)

echo Installing Docker Desktop...
winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
if %errorlevel% neq 0 (
    echo winget failed or not found, downloading installer directly...
    curl -L -o "%TEMP%\DockerDesktopInstaller.exe" "https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
    "%TEMP%\DockerDesktopInstaller.exe" install --quiet --accept-license
    del "%TEMP%\DockerDesktopInstaller.exe" 2>nul
)

echo Done. You may need to restart your computer.
pause
