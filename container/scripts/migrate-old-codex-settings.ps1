#Requires -Version 5.1

# Re-launch in Windows Terminal if available (better copy/paste).
if (-not $env:WT_SESSION -and $Host.Name -eq 'ConsoleHost' -and (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    try {
        Start-Process -FilePath 'wt.exe' -ArgumentList @(
            'new-tab', '--title', 'Migrate Codex Settings',
            'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $MyInvocation.MyCommand.Path
        ) -ErrorAction Stop
        exit
    } catch { }
}

$Script:CleanExit = $false
function Wait-ForExit {
    Write-Host ""
    try { [void][Console]::ReadKey($true) } catch { Read-Host "Press Enter to exit" }
}

try {
    $ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ContainerDir = Split-Path -Parent $ScriptDir
    $TargetDir    = Join-Path $ContainerDir 'persistent-codex-settings'
    $OldVolume    = 'codex-home'

    Write-Host "Codex settings migration"
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "This copies your Codex auth, sessions, and config from the old"
    Write-Host "Docker named volume ('$OldVolume') into the new local folder:"
    Write-Host "  $TargetDir"
    Write-Host ""

    # Docker available?
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not installed." -ForegroundColor Yellow
        Write-Host "Install Docker Desktop first (use Install Docker.lnk), then run this again."
        return
    }
    & docker info 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker is not running. Start Docker Desktop first, then run this again." -ForegroundColor Yellow
        return
    }

    # Old volume present?
    & docker volume inspect $OldVolume 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No old '$OldVolume' volume found. Nothing to migrate." -ForegroundColor Green
        Write-Host "(This is the expected result if you've never run an older version.)"
        Start-Sleep -Seconds 3
        $Script:CleanExit = $true
        return
    }

    # Peek at what's in the volume's .codex subdir
    Write-Host "Found old '$OldVolume' volume. Preview of its .codex contents:"
    Write-Host ""
    & docker run --rm -v "${OldVolume}:/old" alpine sh -c "ls -la /old/.codex 2>/dev/null | head -20"
    Write-Host ""

    $confirm = Read-Host "Copy these contents into '$TargetDir', overwriting any existing files? (Y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Cancelled. No changes made."
        return
    }

    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Copying..."
    & docker run --rm -v "${OldVolume}:/old" -v "${TargetDir}:/new" alpine sh -c "cp -a /old/.codex/. /new/ && echo OK"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Copy failed (exit $LASTEXITCODE). Old volume left intact." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Migration complete." -ForegroundColor Green
    Write-Host "Your auth, sessions, and config now live in:" -ForegroundColor Green
    Write-Host "  $TargetDir"
    Write-Host ""

    $remove = Read-Host "Remove the old '$OldVolume' volume to reclaim disk space? (Y/N)"
    if ($remove -match '^[Yy]') {
        & docker volume rm $OldVolume
        Write-Host ""
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Old volume removed." -ForegroundColor Green
        } else {
            Write-Host "Could not remove old volume (it may still be attached to a stopped container)." -ForegroundColor Yellow
            Write-Host "Run 'Docker Cleanup.lnk' to prune unused containers, then try again."
        }
    }

    Start-Sleep -Seconds 2
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
    if (-not $Script:CleanExit) { Wait-ForExit }
}
