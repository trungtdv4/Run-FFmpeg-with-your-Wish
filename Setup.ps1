# ==============================================================================
# Script Name: Setup.ps1 (Loader)
# Description: Download full GitHub repository and trigger local Execution
# ==============================================================================

# 1. Cấu hình GitHub Repository của bạn (THAY THÔNG TIN TẠI ĐÂY)
$githubUser = "trungtdv4"
$githubRepo = "Run-FFmpeg-with-your-Wish"
$branch     = "main"

# 2. Định vị thư mục cài đặt trong AppData của User
$installDir = Join-Path $env:LOCALAPPDATA "FFmpeg-Wish-App"
$zipPath    = Join-Path $env:TEMP "ffmpeg-app.zip"
$zipUrl     = "https://github.com/$githubUser/$githubRepo/archive/refs/heads/$branch.zip"

Clear-Host
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      INITIALIZING FFMPEG WISH APP LOADER           " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 3. Tải Repo Zip từ GitHub
Write-Host "[+] Downloading application package from GitHub..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
    Write-Host "[V] Download completed!" -ForegroundColor Green
} catch {
    Write-Error "[!] Failed to download repository. Please check your Repo URL/Public status."
    Exit
}

# 4. Làm sạch và Giải nén vào AppData
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "[+] Extracting files to Local AppData..." -ForegroundColor Yellow
Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force

# GitHub zip giải nén ra folder dạng: <RepoName>-<Branch>
$extractedFolder = Join-Path $env:TEMP "$githubRepo-$branch"

if (Test-Path $extractedFolder) {
    Move-Item -Path $extractedFolder -Destination $installDir -Force
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Write-Host "[V] App installed successfully at: $installDir" -ForegroundColor Green
} else {
    Write-Error "[!] Extraction failed. Directory structure mismatch."
    Exit
}

# 5. Kích hoạt Bootstrapper.bat trên Local
$batPath = Join-Path $installDir "Bootstrapper.bat"

if (Test-Path $batPath) {
    Write-Host ""
    Write-Host ">>> Launching App on Local environment... <<<" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    
    # Khởi chạy file BAT trong một cửa sổ Terminal mới
    Start-Process -FilePath $batPath -WorkingDirectory $installDir
} else {
    Write-Error "[!] Cannot find 'Bootstrapper.bat' in the repository!"
}