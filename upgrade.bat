@echo off
echo Stopping and removing codex container...
docker rm -f codex > NUL 2>&1
echo Rebuilding image (no cache)...
docker-compose -f docker/docker-compose.yaml build --pull --no-cache
echo.
echo Done. Run codex.bat to start fresh.
echo.
pause
