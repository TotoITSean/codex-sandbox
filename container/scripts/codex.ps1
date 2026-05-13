#Requires -Version 5.1

# If we're in the legacy console host and Windows Terminal is available,
# re-launch into WT for proper Ctrl+C / Ctrl+V copy-paste. Falls back
# silently to the current console if wt.exe isn't installed or fails to launch.
if (-not $env:WT_SESSION -and $Host.Name -eq 'ConsoleHost' -and (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    try {
        Start-Process -FilePath 'wt.exe' -ArgumentList @(
            'new-tab', '--title', 'Codex',
            'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $MyInvocation.MyCommand.Path
        ) -ErrorAction Stop
        exit
    } catch {
        # WT launch failed; fall through and run in the current console.
    }
}

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ContainerDir = Split-Path -Parent $ScriptDir
$ProjectDir   = Split-Path -Parent $ContainerDir
$LogFile      = Join-Path $ScriptDir 'codex-last-run.log'

# Set to $true on clean exit paths so the window closes; left $false
# (the default) for errors so the user can read what went wrong.
$Script:CleanExit = $false
function Wait-ForExit {
    Write-Host ""
    try { [void][Console]::ReadKey($true) } catch { Read-Host "Press Enter to exit" }
}

# Fresh log
"Codex launcher started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $LogFile -Encoding utf8
function Log([string]$m) { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m | Add-Content -LiteralPath $LogFile }

function Test-DockerReady {
    & docker info 2>$null 1>$null
    return ($LASTEXITCODE -eq 0)
}

try {
    Log "ScriptDir    = $ScriptDir"
    Log "ContainerDir = $ContainerDir"
    Log "ProjectDir   = $ProjectDir"

    # Check if Docker is installed
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Log "docker.exe not found on PATH"
        Write-Host "Docker is not installed. Running install script as administrator..."
        Write-Host ""
        $installer = Join-Path $ScriptDir 'install-docker.ps1'
        if (Test-Path -LiteralPath $installer) {
            Start-Process -FilePath 'powershell.exe' `
                -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$installer`"" `
                -Verb RunAs -Wait
        } else {
            Write-Host "install-docker.ps1 not found at $installer" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Docker installed. Please restart your computer, then run this script again."
        return
    }
    Log "docker.exe found"

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
    Log "Compose command = $ComposeExe $($ComposeSub -join ' ')"

    # Check if Docker is running
    if (-not (Test-DockerReady)) {
        Log "Docker daemon not responsive - starting Docker Desktop"
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
    Log "Docker daemon is responsive"

    # Derive a name from the project folder
    $FolderName = Split-Path -Leaf $ProjectDir
    $SafeName = $FolderName.ToLower() -replace '[^a-z0-9_-]', '_' -replace '_+', '_' -replace '^_+|_+$', ''
    if ($SafeName -notmatch '^[a-z0-9]') { $SafeName = "c$SafeName" }
    if ([string]::IsNullOrEmpty($SafeName)) { $SafeName = 'codex' }
    $ContainerName  = $SafeName
    $ComposeProject = $SafeName
    Log "FolderName=$FolderName  SafeName=$SafeName"

    # Derive unique ports from raw folder name hash, and export them so
    # docker-compose's ${HTTP_PORT:-8080} etc. substitution picks them up.
    $PortOffset = [math]::Abs($FolderName.GetHashCode()) % 1000
    $HttpPort  = 8000  + $PortOffset
    $HttpsPort = 4400  + $PortOffset
    $RdpPort   = 33000 + $PortOffset
    $SshPort   = 2200  + $PortOffset
    $env:HTTP_PORT   = $HttpPort
    $env:HTTPS_PORT  = $HttpsPort
    $env:RDP_PORT    = $RdpPort
    $env:SSH_PORT    = $SshPort
    $env:FILES_MOUNT = $FolderName

    # Parse ENABLE_XRDP from Settings.txt (default: true)
    $EnableXrdp = 'true'
    $SettingsFile = Join-Path $ProjectDir 'Settings.txt'
    if (Test-Path -LiteralPath $SettingsFile) {
        foreach ($line in Get-Content -LiteralPath $SettingsFile) {
            if ($line -match '^\s*ENABLE_XRDP\s*=\s*([^\s#]+)') { $EnableXrdp = $Matches[1] }
        }
    }
    Log "ENABLE_XRDP=$EnableXrdp"

    if ($EnableXrdp -ieq 'true') {
        $Title = "$SafeName - RDP: localhost:$RdpPort - HTTP: http://localhost:$HttpPort"
    } else {
        $Title = "$SafeName - HTTP: http://localhost:$HttpPort"
    }
    try { [Console]::Title = $Title } catch { }

    Write-Host ("Instance: {0}  (folder: `"{1}`", XRDP: {2})" -f $SafeName, $FolderName, $EnableXrdp)
    if ($EnableXrdp -ieq 'true') {
        Write-Host ("  HTTP: {0}  HTTPS: {1}  RDP: {2}  SSH: {3}" -f $HttpPort, $HttpsPort, $RdpPort, $SshPort)
    } else {
        Write-Host ("  HTTP: {0}  HTTPS: {1}  SSH: {2}" -f $HttpPort, $HttpsPort, $SshPort)
    }
    Write-Host ""

    $ComposeFile = Join-Path $ContainerDir 'docker\docker-compose.yaml'
    if (-not (Test-Path -LiteralPath $ComposeFile)) {
        throw "Compose file not found: $ComposeFile"
    }
    Log "ComposeFile=$ComposeFile"

    Write-Host "Updating and building..."
    Write-Host ""
    & $ComposeExe @ComposeSub -p $ComposeProject -f $ComposeFile build --pull
    Log "build exit=$LASTEXITCODE"
    Write-Host ""

    # Check if the container already exists (running or stopped)
    & docker container inspect $ContainerName 2>$null 1>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Restarting existing container..."
        Write-Host ""
        & docker start -ai $ContainerName
    } else {
        Write-Host "Creating new container..."
        Write-Host ""
        & $ComposeExe @ComposeSub -p $ComposeProject -f $ComposeFile run --service-ports --remove-orphans --name $ContainerName codex
    }
    Log "container run exit=$LASTEXITCODE"
    if ($LASTEXITCODE -eq 0) { $Script:CleanExit = $true; return }

    Write-Host ""
    Write-Host "Codex failed to start."
    Write-Host ""
    $cleanup = Read-Host "Would you like to remove the container and retry? (Y/N)"
    if ($cleanup -notmatch '^[Yy]') { return }

    & docker rm -f $ContainerName 2>$null 1>$null
    $cleanupScript = Join-Path $ScriptDir 'docker-cleanup.ps1'
    if (Test-Path -LiteralPath $cleanupScript) {
        & $cleanupScript -Yes
    }
    Write-Host ""
    Write-Host "Retrying..."
    Write-Host ""
    & $ComposeExe @ComposeSub -p $ComposeProject -f $ComposeFile build --pull
    & $ComposeExe @ComposeSub -p $ComposeProject -f $ComposeFile run --service-ports --remove-orphans --name $ContainerName codex
    Log "retry exit=$LASTEXITCODE"
    if ($LASTEXITCODE -eq 0) { $Script:CleanExit = $true; return }

    Write-Host ""
    Write-Host "Codex failed to start again."
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host ("Type:  {0}" -f $_.Exception.GetType().FullName) -ForegroundColor DarkGray
    if ($_.InvocationInfo) {
        Write-Host ("At:    {0}:{1}" -f $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber) -ForegroundColor DarkGray
        Write-Host ("Line:  {0}" -f $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkGray
    }
    Log ("EXCEPTION: " + $_)
    Log ("STACK: " + $_.ScriptStackTrace)
}
finally {
    Log "Launcher finished (CleanExit=$Script:CleanExit)"
    if (-not $Script:CleanExit) { Wait-ForExit }
}
