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

try {
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
