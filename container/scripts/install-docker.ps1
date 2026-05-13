#Requires -Version 5.1

# Self-elevate to admin if needed
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..."
    try {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`"" `
            -Verb RunAs
    } catch {
        Write-Host ""
        Write-Host "ERROR: Elevation was cancelled or denied." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }
    return
}

$Script:CleanExit = $false
function Wait-ForExit {
    Write-Host ""
    try { [void][Console]::ReadKey($true) } catch { Read-Host "Press Enter to exit" }
}

try {
    Write-Host "Installing Docker Desktop..."
    Write-Host ""

    $installed = $false

    # Try winget first
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { $installed = $true }
    }

    if (-not $installed) {
        Write-Host ""
        Write-Host "winget failed or not found, downloading installer directly..."
        $url = 'https://desktop.docker.com/win/main/amd64/Docker Desktop Installer.exe'
        $exe = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
        try {
            Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
            Start-Process -FilePath $exe -ArgumentList 'install', '--quiet', '--accept-license' -Wait
            $installed = ($LASTEXITCODE -eq 0)
        } finally {
            if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue }
        }
    }

    Write-Host ""
    if ($installed) {
        Write-Host "Done. You may need to restart your computer." -ForegroundColor Green
        Start-Sleep -Seconds 3
        $Script:CleanExit = $true
    } else {
        Write-Host "Docker Desktop installation did not complete successfully." -ForegroundColor Yellow
    }
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
