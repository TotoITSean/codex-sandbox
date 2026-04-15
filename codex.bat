@echo off

REM Check if Docker is installed
where docker > NUL 2>&1
if %errorlevel% neq 0 (
    echo Docker is not installed. Running install script as administrator...
    echo.
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~dp0install-docker.bat\"' -Verb RunAs -Wait"
    echo.
    echo Docker installed. Please restart your computer, then run this script again.
    echo.
    pause
    goto :eof
)

REM Check if Docker is running
docker info > NUL 2>&1
if %errorlevel% neq 0 (
    echo Docker Desktop is not running. Starting it...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo Waiting for Docker to start...
    :wait_loop
    timeout /t 3 /nobreak > NUL
    docker info > NUL 2>&1
    if %errorlevel% neq 0 goto wait_loop
    echo Docker is ready.
    echo.
)

REM Derive a raw name from the folder this script lives in
for %%I in ("%~dp0.") do set "FOLDER_NAME=%%~nxI"

REM Sanitize to a Docker-safe project/container name (lowercase, only [a-z0-9_-])
REM Pass via environment to avoid batch quoting issues with spaces/punctuation
set "RAW_NAME=%FOLDER_NAME%"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$n = $env:RAW_NAME.ToLower() -replace '[^a-z0-9_-]', '_' -replace '_+', '_' -replace '^_+|_+$', ''; if ($n -notmatch '^[a-z0-9]') { $n = 'c' + $n }; if (-not $n) { $n = 'codex' }; Write-Output $n"`) do set "SAFE_NAME=%%A"
set "CONTAINER_NAME=%SAFE_NAME%"
set "COMPOSE_PROJECT=%SAFE_NAME%"

REM Derive unique ports from raw folder name hash (via env to avoid quoting issues)
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[math]::Abs($env:RAW_NAME.GetHashCode()) %% 1000"`) do set "PORT_OFFSET=%%A"
set /a HTTP_PORT=8000 + %PORT_OFFSET%
set /a HTTPS_PORT=4400 + %PORT_OFFSET%
set /a RDP_PORT=33000 + %PORT_OFFSET%
set /a SSH_PORT=2200 + %PORT_OFFSET%

REM Parse ENABLE_XRDP from settings.txt (default: true)
set ENABLE_XRDP=true
if exist "%~dp0settings.txt" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%~dp0settings.txt") do (
        if /i "%%A"=="ENABLE_XRDP" set ENABLE_XRDP=%%B
    )
)

REM Title uses the sanitized name (no spaces/punctuation safety issues)
if /i "%ENABLE_XRDP%"=="true" (
    title %SAFE_NAME% - RDP: localhost:%RDP_PORT% - HTTP: http://localhost:%HTTP_PORT%
    start /b cmd /c "powershell -NoProfile -Command while($true){[Console]::Title='%SAFE_NAME% - RDP: localhost:%RDP_PORT% - HTTP: http://localhost:%HTTP_PORT%';Start-Sleep 3}" > NUL 2>&1
) else (
    title %SAFE_NAME% - HTTP: http://localhost:%HTTP_PORT%
    start /b cmd /c "powershell -NoProfile -Command while($true){[Console]::Title='%SAFE_NAME% - HTTP: http://localhost:%HTTP_PORT%';Start-Sleep 3}" > NUL 2>&1
)

echo Instance: %SAFE_NAME%  (folder: "%FOLDER_NAME%", XRDP: %ENABLE_XRDP%)
if /i "%ENABLE_XRDP%"=="true" (
    echo   HTTP: %HTTP_PORT%  HTTPS: %HTTPS_PORT%  RDP: %RDP_PORT%  SSH: %SSH_PORT%
) else (
    echo   HTTP: %HTTP_PORT%  HTTPS: %HTTPS_PORT%  SSH: %SSH_PORT%
)
echo.

echo Updating and building...
echo.
docker-compose -p "%COMPOSE_PROJECT%" -f docker/docker-compose.yaml build --pull > NUL
echo.

REM Check if the container already exists (running or stopped)
docker container inspect "%CONTAINER_NAME%" > NUL 2>&1
if %errorlevel% equ 0 (
    echo Restarting existing container...
    echo.
    docker start -ai "%CONTAINER_NAME%"
) else (
    echo Creating new container...
    echo.
    docker-compose -p "%COMPOSE_PROJECT%" -f docker/docker-compose.yaml run --service-ports --remove-orphans --name "%CONTAINER_NAME%" codex
)
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to remove the container and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

docker rm -f "%CONTAINER_NAME%" > NUL 2>&1
call "%~dp0docker-cleanup.bat" -y
echo.
echo Retrying...
echo.
docker-compose -p "%COMPOSE_PROJECT%" -f docker/docker-compose.yaml build --pull > NUL
docker-compose -p "%COMPOSE_PROJECT%" -f docker/docker-compose.yaml run --service-ports --remove-orphans --name "%CONTAINER_NAME%" codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
