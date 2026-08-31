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


# ==============================================================================
# 4. LOAD DYNAMIC MENU FROM GITHUB VIA API OR LOCAL FOLDER
# ==============================================================================

# Khai báo cấu hình Repo GitHub của bạn
$githubUser = "trungtdv4"     # Thay Username GitHub của bạn
$githubRepo = "Run-FFmpeg-with-your-Wish"           # Thay Tên Repository của bạn
$branch     = "main"

# Thư mục lưu file con ở Local
$localFunctionsDir = Join-Path $global:WorkingDir "FFmpeg-Functions"
if (-not (Test-Path $localFunctionsDir)) {
    New-Item -Path $localFunctionsDir -ItemType Directory | Out-Null
}

while ($true) {
    Write-Host ""
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "MEDIA DIRECTORY: $global:WorkingDir" -ForegroundColor Yellow
    Write-Host "(Note: Please place your input media files in the directory above)" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "AVAILABLE FFMPEG FUNCTIONS:" -ForegroundColor Cyan

    # 1. Kiểm tra xem script đang chạy qua iex hay chạy file Local
    $functionFiles = @()

    if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        # Đang chạy qua irm | iex -> Dùng GitHub API để lấy danh sách file con từ xa
        $apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents/FFmpeg-Functions?ref=$branch"
        
        try {
            $apiResponse = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            $functionFiles = $apiResponse | Where-Object { $_.name -like "*.ps1" } | Sort-Object name
        } catch {
            Write-Host "[!] Could not fetch functions from GitHub API. Checking local cache..." -ForegroundColor Yellow
            $functionFiles = Get-ChildItem -Path $localFunctionsDir -Filter "*.ps1" | Sort-Object Name
        }
    } else {
        # Đang chạy Local file -> Quét thư mục kế bên file cha
        $localDir = Join-Path $PSScriptRoot "FFmpeg-Functions"
        if (Test-Path $localDir) {
            $functionFiles = Get-ChildItem -Path $localDir -Filter "*.ps1" | Sort-Object Name
        }
    }

    # 2. Hiển thị Menu
    if ($functionFiles.Count -eq 0) {
        Write-Host "[!] No function scripts found!" -ForegroundColor Red
        Write-Host "  0. Exit" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $functionFiles.Count; $i++) {
            $displayName = if ($functionFiles[$i].name) { $functionFiles[$i].name -replace '\.ps1$', '' } else { $functionFiles[$i].BaseName }
            Write-Host "  $($i + 1). $displayName" -ForegroundColor White
        }
        Write-Host "  0. Exit" -ForegroundColor Gray
    }

    Write-Host ""
    $selection = Read-Host "Select a function number"

    if ($selection -eq '0') {
        Write-Host "Thank you for using the application!" -ForegroundColor Green
        break
    }

    if ($selection -match '^\d+$' -and [int]$selection -le $functionFiles.Count -and [int]$selection -gt 0) {
        $selectedItem = $functionFiles[[int]$selection - 1]
        
        # Nếu chạy qua iex, tải code file con về thực thi
        if ([string]::IsNullOrEmpty($PSScriptRoot)) {
            $rawUrl = "https://raw.githubusercontent.com/$githubUser/$githubRepo/$branch/FFmpeg-Functions/$($selectedItem.name)"
            Write-Host ""
            Write-Host ">>> Fetching and Executing: $($selectedItem.name) <<<" -ForegroundColor Green
            
            # Tải nội dung script con và chạy trực tiếp bằng iex
            $scriptContent = Invoke-RestMethod -Uri $rawUrl
            Invoke-Expression $scriptContent
        } else {
            # Chạy file Local
            Write-Host ""
            Write-Host ">>> Executing: $($selectedItem.BaseName) <<<" -ForegroundColor Green
            & $selectedItem.FullName
        }
    } else {
        Write-Host "[!] Invalid selection. Please try again!" -ForegroundColor Red
    }
}