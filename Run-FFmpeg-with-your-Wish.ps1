# ==============================================================================
# File: Run-FFmpeg-with-your-Wish.ps1
# Description: Main Logic, Dependency Check & Dynamic Menu
# ==============================================================================

# 1. Function to Check Administrator Privileges
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

# 2. Check FFmpeg Dependency & Administrator Logic
$ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue

if (-not $ffmpegExists) {
    Write-Host "[!] STATUS: FFmpeg is NOT installed on your system!" -ForegroundColor Red
    Write-Host ""
    
    $isAdmin = Test-IsAdmin
    
    if (-not $isAdmin) {
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED TO INSTALL FFMPEG:" -ForegroundColor Yellow
        Write-Host "1. Please CLOSE this window." -ForegroundColor White
        Write-Host "2. Right-click 'Bootstrapper.bat' -> Select 'Run as Administrator'." -ForegroundColor White
        Write-Host "3. Or open PowerShell as Admin and re-run Setup.ps1" -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If you do not grant Admin rights or decline FFmpeg installation," -ForegroundColor DarkGray
        Write-Host "please close this window and exit." -ForegroundColor DarkGray
        Exit
    } else {
        # Running as Admin, ask for Winget installation
        $choice = Read-Host "Do you want to automatically install FFmpeg via Winget now? (Y/N)"
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Host ""
            Write-Host "[+] Installing FFmpeg via Winget..." -ForegroundColor Green
            winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
            
            Write-Host ""
            Write-Host "====================================================" -ForegroundColor Yellow
            Write-Host "INSTALLATION COMPLETED!" -ForegroundColor Green
            Write-Host "Please RESTART your Terminal/Bootstrapper (as Admin)" -ForegroundColor Yellow
            Write-Host "to refresh system PATH variables." -ForegroundColor Yellow
            Write-Host "====================================================" -ForegroundColor Yellow
            Exit
        } else {
            Write-Host "[!] FFmpeg installation cancelled. Exiting..." -ForegroundColor Red
            Exit
        }
    }
}

Write-Host "[V] FFmpeg Check: INSTALLED" -ForegroundColor Green

# 3. Working Directory Initialization (D:\FFmpeg or C:\FFmpeg)
$global:WorkingDir = if (Test-Path "D:\") { "D:\FFmpeg" } else { "C:\FFmpeg" }
if (-not (Test-Path $global:WorkingDir)) {
    New-Item -Path $global:WorkingDir -ItemType Directory | Out-Null
    Write-Host "[+] Created default working directory at: $global:WorkingDir" -ForegroundColor Yellow
} else {
    Write-Host "[V] Working Directory: $global:WorkingDir" -ForegroundColor Green
}

# 4. Dynamic Menu Scan (Local Folder)
$functionsDir = Join-Path $PSScriptRoot "FFmpeg-Functions"

while ($true) {
    Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "MEDIA DIRECTORY: $global:WorkingDir" -ForegroundColor Yellow
    Write-Host "(Note: Please place your input media files in the directory above)" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "AVAILABLE FFMPEG FUNCTIONS:" -ForegroundColor Cyan

    $scriptFiles = Get-ChildItem -Path $functionsDir -Filter "*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name

    if (-not $scriptFiles -or $scriptFiles.Count -eq 0) {
        Write-Host "[!] No function scripts (.ps1) found in: $functionsDir" -ForegroundColor Red
        Write-Host "    Please add module files into the directory above." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  0. Exit" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $scriptFiles.Count; $i++) {
            Write-Host "  $($i + 1). $($scriptFiles[$i].BaseName)" -ForegroundColor White
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
        
        # Call module file
        & $selectedScript
    } else {
        Write-Host "[!] Invalid selection. Please try again!" -ForegroundColor Red
    }
}