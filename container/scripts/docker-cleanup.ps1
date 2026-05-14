#Requires -Version 5.1
[CmdletBinding()]
param(
    [Alias('y')]
    [switch]$Yes
)

$Script:CleanExit = $false
function Wait-ForExit {
    Write-Host ""
    try { [void][Console]::ReadKey($true) } catch { Read-Host "Press Enter to exit" }
}
function Test-DockerReady {
    & docker info 2>$null 1>$null
    return ($LASTEXITCODE -eq 0)
}

try {
    # Make sure Docker is installed and running before doing anything else.
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not installed." -ForegroundColor Yellow
        Write-Host "Install it first (double-click 'Install Docker.cmd' in the project root)."
        return
    }
    if (-not (Test-DockerReady)) {
        Write-Host "Docker Desktop is not running. Starting it..."
        $dd = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        if (Test-Path -LiteralPath $dd) {
            Start-Process -FilePath $dd
        } else {
            Write-Host "Docker Desktop not found at $dd - please start it manually." -ForegroundColor Yellow
        }
        Write-Host "Waiting for Docker to start..."
        while (-not (Test-DockerReady)) { Start-Sleep -Seconds 3 }
        Write-Host "Docker is ready."
        Write-Host ""
    }

    # Pick a compose command: 'docker compose' (new) or 'docker-compose' (legacy)
    & docker compose version 2>$null 1>$null
    if ($LASTEXITCODE -eq 0) {
        $ComposeExe = 'docker'
        $ComposeSub = @('compose')
    } elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $ComposeExe = 'docker-compose'
        $ComposeSub = @()
    } else {
        throw "Neither 'docker compose' nor 'docker-compose' is available."
    }

    if (-not $Yes) {
        Write-Host "WARNING: This will stop all running Codex containers and" -ForegroundColor Yellow
        Write-Host "interrupt any active sessions in this sandbox." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "Shutting down containers..."
    Write-Host ""
    & $ComposeExe @ComposeSub down --remove-orphans
    Write-Host ""

    Write-Host "Running docker prune - this will remove any containers not actively running, or any images not being used"
    Write-Host ""
    if ($Yes) {
        & docker system prune -f
    } else {
        & docker system prune
    }
    Write-Host ""
    if (-not $Yes) { Start-Sleep -Seconds 2 }
    $Script:CleanExit = $true
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host ("At:   {0}:{1}" -f $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber) -ForegroundColor DarkGray
        Write-Host ("Line: {0}" -f $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkGray
    }
}
finally {
    if (-not $Yes -and -not $Script:CleanExit) { Wait-ForExit }
}
