# ==============================================================================
# Script Name: Run FFmpeg with your Wish.ps1
# Description: Modular FFmpeg Management & Execution Script
# ==============================================================================

# 1. Check Administrator Privileges
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

# 2. Check FFmpeg Installation
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue

if (-not $ffmpegExists) {
    Write-Host "[!] STATUS: FFmpeg is NOT installed on your system!" -ForegroundColor Red
    Write-Host ""
    
    $isAdmin = Test-IsAdmin
    
    if (-not $isAdmin) {
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED TO INSTALL FFMPEG:" -ForegroundColor Yellow
        Write-Host "1. Please CLOSE the current PowerShell/Terminal window." -ForegroundColor White
        Write-Host "2. Right-click PowerShell/Terminal -> Select 'Run as Administrator'." -ForegroundColor White
        Write-Host "3. Re-run the script command to continue." -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If you do not grant Admin rights or decline FFmpeg installation," -ForegroundColor DarkGray
        Write-Host "please close this window and exit." -ForegroundColor DarkGray
        Exit
    } else {
        $choice = Read-Host "Do you want to automatically install FFmpeg via Winget now? (Y/N)"
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Host ""
            Write-Host "[+] Installing FFmpeg via Winget..." -ForegroundColor Green
            winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
            
            Write-Host ""
            Write-Host "====================================================" -ForegroundColor Yellow
            Write-Host "INSTALLATION COMPLETED!" -ForegroundColor Green
            Write-Host "Please RESTART your Terminal (as Admin) to refresh PATH variables." -ForegroundColor Yellow
            Write-Host "====================================================" -ForegroundColor Yellow
            Exit
        } else {
            Write-Host "[!] FFmpeg installation cancelled. Exiting..." -ForegroundColor Red
            Exit
        }
    }
}

Write-Host "[V] FFmpeg Check: INSTALLED" -ForegroundColor Green

# 3. Initialize Working Directory (D:\FFmpeg or C:\FFmpeg)
$global:WorkingDir = ""
if (Test-Path "D:\") {
    $global:WorkingDir = "D:\FFmpeg"
} else {
    $global:WorkingDir = "C:\FFmpeg"
}

if (-not (Test-Path $global:WorkingDir)) {
    New-Item -Path $global:WorkingDir -ItemType Directory | Out-Null
    Write-Host "[+] Created default working directory at: $global:WorkingDir" -ForegroundColor Yellow
} else {
    Write-Host "[V] Working Directory: $global:WorkingDir" -ForegroundColor Green
}

# 4. Load Dynamic Menu from "FFmpeg-Functions" Folder
$functionsDir = Join-Path $PSScriptRoot "FFmpeg-Functions"

if (-not (Test-Path $functionsDir)) {
    $functionsDir = Join-Path $global:WorkingDir "FFmpeg-Functions"
    if (-not (Test-Path $functionsDir)) {
        New-Item -Path $functionsDir -ItemType Directory | Out-Null
    }
}

while ($true) {
    Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "MEDIA DIRECTORY: $global:WorkingDir" -ForegroundColor Yellow
    Write-Host "(Note: Please place your input media files in the directory above)" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "AVAILABLE FFMPEG FUNCTIONS:" -ForegroundColor Cyan

    $scriptFiles = Get-ChildItem -Path $functionsDir -Filter "*.ps1" | Sort-Object Name

    if ($scriptFiles.Count -eq 0) {
        Write-Host "[!] No function scripts (.ps1) found in: $functionsDir" -ForegroundColor Red
        Write-Host "    Please add module files into the directory above." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  0. Exit" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $scriptFiles.Count; $i++) {
            $menuName = $scriptFiles[$i].BaseName
            Write-Host "  $($i + 1). $menuName" -ForegroundColor White
        }
        Write-Host "  0. Exit" -ForegroundColor Gray
    }

    Write-Host ""
    $selection = Read-Host "Select a function number"

    if ($selection -eq '0') {
        Write-Host "Thank you for using the application!" -ForegroundColor Green
        break
    }

    if ($selection -match '^\d+$' -and [int]$selection -le $scriptFiles.Count -and [int]$selection -gt 0) {
        $selectedScript = $scriptFiles[[int]$selection - 1].FullName
        Write-Host ""
        Write-Host ">>> Executing: $($scriptFiles[[int]$selection - 1].BaseName) <<<" -ForegroundColor Green
        
        & $selectedScript
    } else {
        Write-Host "[!] Invalid selection. Please try again!" -ForegroundColor Red
    }
}