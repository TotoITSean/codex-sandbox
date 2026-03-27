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

REM Derive project and container name from the folder this script lives in
for %%I in ("%~dp0.") do set FOLDER_NAME=%%~nxI
set CONTAINER_NAME=%FOLDER_NAME%
set COMPOSE_PROJECT=%FOLDER_NAME%

echo Updating and building...
echo.
docker-compose -p %COMPOSE_PROJECT% -f docker/docker-compose.yaml build --pull > NUL
echo.

REM Check if the container already exists (running or stopped)
docker container inspect %CONTAINER_NAME% > NUL 2>&1
if %errorlevel% equ 0 (
    echo Restarting existing container...
    echo.
    docker start -ai %CONTAINER_NAME%
) else (
    echo Creating new container...
    echo.
    docker-compose -p %COMPOSE_PROJECT% -f docker/docker-compose.yaml run --service-ports --remove-orphans --name %CONTAINER_NAME% codex
)
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to remove the container and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

docker rm -f %CONTAINER_NAME% > NUL 2>&1
call "%~dp0docker-cleanup.bat" -y
echo.
echo Retrying...
echo.
docker-compose -p %COMPOSE_PROJECT% -f docker/docker-compose.yaml build --pull > NUL
docker-compose -p %COMPOSE_PROJECT% -f docker/docker-compose.yaml run --service-ports --remove-orphans --name %CONTAINER_NAME% codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
