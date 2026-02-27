@echo off
setlocal enabledelayedexpansion
echo Updating, building, and cleaning...
echo.
docker-compose build --pull > NUL
echo.
echo Starting codex...
echo.

:: Stop orphaned container from a previous session if still running
docker container inspect -f "{{.State.Running}}" codex-session 2>nul | findstr "true" >nul 2>&1
if %errorlevel% equ 0 (
    echo Stopping previous session...
    docker stop codex-session >nul 2>&1
)

:: If container exists, check if the image has changed
docker container inspect codex-session >nul 2>&1
if %errorlevel% equ 0 (
    :: Get the image ID the container was created from
    for /f "tokens=*" %%i in ('docker container inspect -f "{{.Image}}" codex-session 2^>nul') do set CONTAINER_IMAGE=%%i
    :: Get the current image ID after build
    for /f "tokens=*" %%i in ('docker-compose images -q codex 2^>nul') do set CURRENT_IMAGE=%%i
    if not "!CONTAINER_IMAGE!"=="!CURRENT_IMAGE!" (
        echo Image updated, recreating container...
        docker rm -f codex-session >nul 2>&1
    )
)

:: Reuse existing container if it exists (stopped), otherwise create one
docker container inspect codex-session >nul 2>&1
if %errorlevel% equ 0 (
    docker start -ai codex-session
) else (
    docker-compose run --service-ports --name codex-session codex
)

:: Stop container on exit (clean exit via /exit)
docker stop codex-session >nul 2>&1
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to stop containers, and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

echo.
echo Shutting down containers...
docker rm -f codex-session >nul 2>&1
docker-compose down --remove-orphans
echo.
echo Retrying...
echo.
docker-compose build --pull > NUL
docker-compose run --service-ports --name codex-session codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
