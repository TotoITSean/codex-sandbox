@echo off
if /i not "%~1"=="-y" (
    echo WARNING: This will stop all running Codex containers and
    echo interrupt any active sessions in this sandbox.
    echo.
)
echo Shutting down containers...
echo.
docker-compose down --remove-orphans
echo.
echo Running docker prune - this will remove any containers not actively running, or any images not being used
echo.
if /i "%~1"=="-y" (
    docker system prune -f
) else (
    docker system prune
)
echo.
if /i not "%~1"=="-y" pause
