# Module: Convert-Or-Compress-Gif.ps1
# Author: Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved.
Set-Location $global:WorkingDir

Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host "                             GIF CONVERTER & COMPRESSOR ULTRA-OPTIMIZED                                 " -ForegroundColor Cyan
Write-Host "  Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved. " -ForegroundColor DarkGray
Write-Host "                      Licensed under the GNU General Public License v3.0 (GPLv3).                       " -ForegroundColor DarkGray
Write-Host "========================================================================================================" -ForegroundColor Cyan

# 1. Get Input Media File (Accepts both Video & existing .GIF)
Write-Host ""
$inputName = Read-Host "Enter INPUT file name (Video or .gif - e.g., demo.mp4, heavy.gif)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

$ext = [System.IO.Path]::GetExtension($inputName).ToLower()
$isInputGif = ($ext -eq ".gif")

if ($isInputGif) {
    Write-Host "[i] Detected input format: Existing GIF file (Compress Mode)" -ForegroundColor Yellow
} else {
    Write-Host "[i] Detected input format: Video file (Convert to GIF Mode)" -ForegroundColor Green
}

# 2. Select Compression Level / Quality Profile
Write-Host ""
Write-Host "Select GIF Compression Profile:" -ForegroundColor Cyan
Write-Host "1. Small Size (Extreme Compress - 10 FPS, Scale 320px, 128 Colors - Ideal for Chat/Memes)" -ForegroundColor White
Write-Host "2. Medium Quality (Balanced - 15 FPS, Scale 480px, 192 Colors - Recommended)" -ForegroundColor White
Write-Host "3. High Quality (Clear Details - 20 FPS, Scale 640px, 256 Colors - Larger File)" -ForegroundColor White
Write-Host "4. Custom Configuration (User-defined FPS, Scale Width & Color Palette)" -ForegroundColor Yellow

$profileChoice = Read-Host "Enter choice (1-4, Default is 2)"

$fps = 15
$scaleWidth = 480
$maxColors = 192

switch ($profileChoice) {
    "1" {
        $fps = 10
        $scaleWidth = 320
        $maxColors = 128
        Write-Host "[i] Profile: SMALL SIZE (Extreme Compress)" -ForegroundColor Yellow
    }
    "3" {
        $fps = 20
        $scaleWidth = 640
        $maxColors = 256
        Write-Host "[i] Profile: HIGH QUALITY" -ForegroundColor Green
    }
    "4" {
        Write-Host ""
        $userFps = Read-Host "Enter Target FPS (e.g., 10, 12, 15 - Default is 15)"
        if ($userFps -match '^\d+$' -and [int]$userFps -gt 0) { $fps = [int]$userFps }

        $userWidth = Read-Host "Enter Target Scale Width in px (e.g., 240, 320, 480, 640 - Default is 480)"
        if ($userWidth -match '^\d+$' -and [int]$userWidth -gt 0) { $scaleWidth = [int]$userWidth }

        $userColors = Read-Host "Enter Max Colors (e.g., 64, 128, 192, 256 - Default is 192)"
        if ($userColors -match '^\d+$' -and [int]$userColors -ge 32 -and [int]$userColors -le 256) { $maxColors = [int]$userColors }

        Write-Host "[V] Custom Profile set: FPS=$fps, Width=${scaleWidth}px, Colors=$maxColors" -ForegroundColor Green
    }
    Default {
        $fps = 15
        $scaleWidth = 480
        $maxColors = 192
        Write-Host "[i] Profile: MEDIUM QUALITY (Balanced)" -ForegroundColor Green
    }
}

# 3. Optional: Trim Segment
Write-Host ""
Write-Host "Do you want to trim a specific segment or processing FULL file?" -ForegroundColor Cyan
Write-Host "1. Full Length" -ForegroundColor White
Write-Host "2. Trim Specific Segment (Enter Start Time & Duration)" -ForegroundColor White

$trimChoice = Read-Host "Enter choice (1-2, Default is 1)"

$timeArgs = ""
if ($trimChoice -eq "2") {
    $startTime = Read-Host "Enter START time (e.g., 00:00:05 or 5)"
    $duration  = Read-Host "Enter DURATION in seconds (e.g., 5, 10)"
    
    if ($startTime -ne "" -and $duration -match '^\d+$') {
        $timeArgs = "-ss $startTime -t $duration"
        Write-Host "[i] Trim Range: Start at $startTime for $duration seconds." -ForegroundColor Yellow
    }
}

# 4. Output Filename & FFmpeg Execution
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$suffix = if ($isInputGif) { "COMPRESSED" } else { "OPTIMIZED" }
$outputName = "${fileNameWithoutExt}-${suffix}.gif"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host ""
Write-Host "[+] Processing & Optimizing GIF with Palettegen & Bayer Dithering..." -ForegroundColor Green

# Chuỗi filter complex tối ưu hóa GIF siêu nhẹ
$vfFilter = "fps=$fps,scale=$scaleWidth\:-1\:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=$maxColors[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3"

$ffmpegArgs = "-y $timeArgs -i `"$inputPath`" -vf `"$vfFilter`" -loop 0 `"$outputPath`""

$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 5. Result Check & Compression Ratio
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    $originalSizeMB = [math]::Round((Get-Item $inputPath).Length / 1MB, 2)
    $gifSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
    $savedPercent = if ($originalSizeMB -gt 0) { [math]::Round((1 - ($gifSizeMB / $originalSizeMB)) * 100, 1) } else { 0 }

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] GIF PROCESSING COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  - Input File Size  : $originalSizeMB MB" -ForegroundColor White
    Write-Host "  - Output GIF Size   : $gifSizeMB MB (Saved $savedPercent%)" -ForegroundColor Green
    Write-Host "  - Output Location   : $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "An error occurred during GIF processing!"
}