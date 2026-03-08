@echo off
setlocal enabledelayedexpansion

:: ─────────────────────────────────────────────────────────
:: codex-gvisor.bat — Launch Codex with gVisor sandboxing
:: ─────────────────────────────────────────────────────────
:: No --privileged needed. gVisor's user-space kernel provides
:: syscall-level isolation without hardware virtualisation.
:: ─────────────────────────────────────────────────────────

set COMPOSE_FILE=docker/docker-compose.gvisor.yaml
set CONTAINER_NAME=codex-gvisor-session

:: ── Check gVisor runtime is available ───────────────────

docker info 2>nul | findstr /c:"runsc" >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: runsc runtime not found in Docker.
    echo Run gvisor-setup.bat first, then restart Docker Desktop.
    echo.
    set /p cont="Continue anyway? (Y/N): "
    if /i not "!cont!"=="Y" exit /b 1
)

:: ── Stop orphaned container from a previous session ─────

docker container inspect -f "{{.State.Running}}" %CONTAINER_NAME% 2>nul | findstr "true" >nul 2>&1
if %errorlevel% equ 0 (
    echo Stopping previous session...
    docker stop %CONTAINER_NAME% >nul 2>&1
)

:: ── Check if image needs rebuilding ─────────────────────

:: Get current image ID from compose
for /f "tokens=*" %%i in ('docker compose -f %COMPOSE_FILE% images -q 2^>nul') do set "CURRENT_IMAGE=%%i"

:: Get image ID the container was created from
for /f "tokens=*" %%i in ('docker container inspect -f "{{.Image}}" %CONTAINER_NAME% 2^>nul') do set "CONTAINER_IMAGE=%%i"

:: If images differ, remove old container so it gets recreated
if defined CURRENT_IMAGE if defined CONTAINER_IMAGE (
    if not "!CURRENT_IMAGE!"=="!CONTAINER_IMAGE!" (
        echo Image changed, recreating container...
        docker rm -f %CONTAINER_NAME% >nul 2>&1
    )
)

:: ── Reuse existing container or create new ──────────────

docker container inspect %CONTAINER_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo Resuming gVisor session...
    echo.
    docker start -ai %CONTAINER_NAME%
) else (
    echo Building image...
    echo.
    docker compose -f %COMPOSE_FILE% build > NUL
    echo Starting codex [gVisor sandbox]...
    echo.
    docker compose -f %COMPOSE_FILE% run --service-ports --name %CONTAINER_NAME% codex
)

:: ── Stop container on exit ──────────────────────────────

docker stop %CONTAINER_NAME% >nul 2>&1
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start.
echo.
set /p cleanup="Would you like to remove the container and retry? (Y/N): "
if /i not "%cleanup%"=="Y" goto :eof

echo.
echo Removing container...
docker rm -f %CONTAINER_NAME% >nul 2>&1
docker compose -f %COMPOSE_FILE% down --remove-orphans
echo.
echo Rebuilding...
echo.
docker compose -f %COMPOSE_FILE% build > NUL
docker compose -f %COMPOSE_FILE% run --service-ports --name %CONTAINER_NAME% codex
if %errorlevel% equ 0 goto :eof

echo.
echo Codex failed to start again.
pause
