# ==============================================================================
# Script Name: Run-FFmpeg-with-your-Wish.ps1
# Description: Local Dynamic Modular Runner
# ==============================================================================

function Test-IsAdmin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

Clear-Host
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "       FFMPEG WISH MANAGEMENT & EXECUTION SYSTEM    " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Check FFmpeg
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue

if (-not $ffmpegExists) {
    Write-Host "[!] STATUS: FFmpeg is NOT installed on your system!" -ForegroundColor Red
    Write-Host ""
    
    if (-not (Test-IsAdmin)) {
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED TO INSTALL FFMPEG:" -ForegroundColor Yellow
        Write-Host "1. Please CLOSE the current window." -ForegroundColor White
        Write-Host "2. Right-click 'Bootstrapper.bat' -> Select 'Run as Administrator'." -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Yellow
        Exit
    } else {
        $choice = Read-Host "Do you want to automatically install FFmpeg via Winget now? (Y/N)"
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Host "[+] Installing FFmpeg via Winget..." -ForegroundColor Green
            winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
            Write-Host "INSTALLATION COMPLETED! Please restart Bootstrapper.bat." -ForegroundColor Green
            Exit
        } else {
            Exit
        }
    }
}

Write-Host "[V] FFmpeg Check: INSTALLED" -ForegroundColor Green

# Working Directory
$global:WorkingDir = if (Test-Path "D:\") { "D:\FFmpeg" } else { "C:\FFmpeg" }
if (-not (Test-Path $global:WorkingDir)) {
    New-Item -Path $global:WorkingDir -ItemType Directory | Out-Null
}
Write-Host "[V] Working Directory: $global:WorkingDir" -ForegroundColor Green

# Dynamic Menu Local Scan
$functionsDir = Join-Path $PSScriptRoot "FFmpeg-Functions"

while ($true) {
    Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "MEDIA DIRECTORY: $global:WorkingDir" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "AVAILABLE FFMPEG FUNCTIONS:" -ForegroundColor Cyan

    $scriptFiles = Get-ChildItem -Path $functionsDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name

    if (-not $scriptFiles -or $scriptFiles.Count -eq 0) {
        Write-Host "[!] No function scripts (.ps1) found in: $functionsDir" -ForegroundColor Red
        Write-Host "  0. Exit" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $scriptFiles.Count; $i++) {
            Write-Host "  $($i + 1). $($scriptFiles[$i].BaseName)" -ForegroundColor White
        }
        Write-Host "  0. Exit" -ForegroundColor Gray
    }

    Write-Host ""
    $selection = Read-Host "Select a function number"

    if ($selection -eq '0') { break }

    if ($selection -match '^\d+$' -and [int]$selection -le $scriptFiles.Count -and [int]$selection -gt 0) {
        $selectedScript = $scriptFiles[[int]$selection - 1].FullName
        Write-Host ""
        Write-Host ">>> Executing: $($scriptFiles[[int]$selection - 1].BaseName) <<<" -ForegroundColor Green
        & $selectedScript
    } else {
        Write-Host "[!] Invalid selection!" -ForegroundColor Red
    }
}