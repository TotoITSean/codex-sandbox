#Requires -Version 5.1

# Read USE_WINDOWS_TERMINAL from Settings.txt (default: true).
$UseWindowsTerminal = $true
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$SettingsFile = Join-Path $ProjectRoot 'Settings.txt'
if (Test-Path -LiteralPath $SettingsFile) {
    foreach ($line in Get-Content -LiteralPath $SettingsFile) {
        if ($line -match '^\s*USE_WINDOWS_TERMINAL\s*=\s*([^\s#]+)') {
            $UseWindowsTerminal = ($Matches[1] -ieq 'true')
        }
    }
}

# Re-launch in Windows Terminal if available (better copy/paste).
# Skipped when USE_WINDOWS_TERMINAL=false in Settings.txt.
if ($UseWindowsTerminal -and -not $env:WT_SESSION -and $Host.Name -eq 'ConsoleHost' -and (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    try {
        $selfPath = $MyInvocation.MyCommand.Path
        $wtArgs = "new-tab --title `"Migrate Codex Settings`" powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""
        Start-Process -FilePath 'wt.exe' -ArgumentList $wtArgs -ErrorAction Stop
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
    $ProjectDir   = Split-Path -Parent $ContainerDir
    $TargetDir    = Join-Path $ContainerDir 'persistent-codex-settings'

    # Compute this project's compose-project name (same sanitization codex.ps1 uses)
    $FolderName = Split-Path -Leaf $ProjectDir
    $SafeName   = $FolderName.ToLower() -replace '[^a-z0-9_-]', '_' -replace '_+', '_' -replace '^_+|_+$', ''
    if ($SafeName -notmatch '^[a-z0-9]') { $SafeName = "c$SafeName" }
    if ([string]::IsNullOrEmpty($SafeName)) { $SafeName = 'codex' }

    Write-Host "Codex settings migration"
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "This copies your Codex auth, sessions, and config from an old"
    Write-Host "Docker named volume into the new local folder:"
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

    # Discover candidate volumes. Compose prefixes named volumes with the project
    # name, so 'codex-home' from the old compose lives as '<project>_codex-home'.
    $allVolumes = @(& docker volume ls --format '{{.Name}}' 2>$null)
    $candidates = @($allVolumes | Where-Object { $_ -match 'codex-home' })

    $OldVolume = $null
    $preferred = "${SafeName}_codex-home"
    if ($candidates -contains $preferred) {
        $OldVolume = $preferred
        Write-Host "Found matching volume for this project: $OldVolume" -ForegroundColor Cyan
    } elseif ($candidates.Count -eq 0) {
        Write-Host "No old '*codex-home' volume found. Nothing to migrate." -ForegroundColor Green
        Write-Host "(This is the expected result if you've never run an older version.)"
        Start-Sleep -Seconds 3
        $Script:CleanExit = $true
        return
    } elseif ($candidates.Count -eq 1) {
        $OldVolume = $candidates[0]
        Write-Host "Found one old volume: $OldVolume" -ForegroundColor Cyan
    } else {
        Write-Host "Multiple old volumes found (one per old project checkout):"
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host ("  {0}) {1}" -f ($i + 1), $candidates[$i])
        }
        Write-Host ""
        $choice = Read-Host "Pick the one to migrate from (1-$($candidates.Count)) or N to cancel"
        if ($choice -notmatch '^[0-9]+$') {
            Write-Host "Cancelled."
            return
        }
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $candidates.Count) {
            Write-Host "Invalid selection. Cancelled."
            return
        }
        $OldVolume = $candidates[$idx]
    }
    Write-Host ""

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
