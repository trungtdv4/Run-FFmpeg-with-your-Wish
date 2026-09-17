# Module: Convert-Video-Formats.ps1
# Author: Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved.
Set-Location $global:WorkingDir

Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host "                CONVERT VIDEO FORMATS MODULE (Format Transcoding & Resolution Scaling)                  " -ForegroundColor Cyan
Write-Host "  Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved. " -ForegroundColor DarkGray
Write-Host "                      Licensed under the GNU General Public License v3.0 (GPLv3).                       " -ForegroundColor DarkGray
Write-Host "========================================================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. HARDWARE DETECTION FUNCTION
# ------------------------------------------------------------------------------
function Get-TargetVideoEncoder {
    param ([string]$codecType = "h264")

    Write-Host ""
    Write-Host "Select Hardware Acceleration Mode:" -ForegroundColor Cyan
    Write-Host "1. CPU (Software Encoding - Best Quality/Size Ratio)" -ForegroundColor White
    Write-Host "2. NVIDIA (NVENC Hardware Acceleration)" -ForegroundColor White
    Write-Host "3. AMD (AMF Hardware Acceleration)" -ForegroundColor White
    Write-Host "4. Intel (QuickSync Hardware Acceleration)" -ForegroundColor White
    
    $gpuChoice = Read-Host "Enter hardware choice [1-4, Default is 1]"
    $gpus = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    $selectedEncoder = ""

    switch ($gpuChoice) {
        "2" {
            if ($gpus -match "NVIDIA") {
                $selectedEncoder = if ($codecType -eq "hevc") { "hevc_nvenc" } else { "h264_nvenc" }
                Write-Host "[V] NVIDIA GPU detected. Using NVENC Encoder: $selectedEncoder" -ForegroundColor Green
            } else {
                Write-Host "[!] WARNING: No NVIDIA GPU detected! Fallback to CPU." -ForegroundColor Yellow
            }
        }
        "3" {
            if ($gpus -match "AMD" -or $gpus -match "Radeon") {
                $selectedEncoder = if ($codecType -eq "hevc") { "hevc_amf" } else { "h264_amf" }
                Write-Host "[V] AMD GPU detected. Using AMF Encoder: $selectedEncoder" -ForegroundColor Green
            } else {
                Write-Host "[!] WARNING: No AMD GPU detected! Fallback to CPU." -ForegroundColor Yellow
            }
        }
        "4" {
            if ($gpus -match "Intel") {
                $selectedEncoder = if ($codecType -eq "hevc") { "hevc_qsv" } else { "h264_qsv" }
                Write-Host "[V] Intel GPU detected. Using QuickSync Encoder: $selectedEncoder" -ForegroundColor Green
            } else {
                Write-Host "[!] WARNING: No Intel GPU detected! Fallback to CPU." -ForegroundColor Yellow
            }
        }
    }

    if (-not $selectedEncoder) {
        $selectedEncoder = if ($codecType -eq "hevc") { "libx265" } else { "libx264" }
        Write-Host "[i] Encoder Mode Set: CPU ($selectedEncoder)" -ForegroundColor White
    }

    return $selectedEncoder
}

# ------------------------------------------------------------------------------
# 2. INPUT FILE & FULL METADATA ANALYSIS VIA FFPROBE
# ------------------------------------------------------------------------------
Write-Host ""
$inputName = Read-Host "Enter INPUT video file name (e.g., sample.mkv, clip.mov)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

Write-Host "[+] Analyzing source video metadata..." -ForegroundColor Yellow

# Probe Metadata via FFprobe
$brRaw   = (ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$wRaw    = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$hRaw    = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$vCodec  = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$aCodec  = (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()

$inputBitrateKbps = if ($brRaw -match '^\d+$') { [math]::Round([int]$brRaw / 1000) } else { 3500 }
$resolutionStr = if ($wRaw -match '^\d+$' -and $hRaw -match '^\d+$') { "${wRaw}x${hRaw}" } else { "Unknown" }

Write-Host ""
Write-Host "====================================================" -ForegroundColor DarkGray
Write-Host " SOURCE VIDEO METADATA (ORIGINAL FILE INFO):" -ForegroundColor Yellow
Write-Host "  - File Name     : $inputName" -ForegroundColor White
Write-Host "  - Resolution    : $resolutionStr" -ForegroundColor White
Write-Host "  - Video Codec   : $vCodec" -ForegroundColor White
Write-Host "  - Audio Codec   : $aCodec" -ForegroundColor White
Write-Host "  - Source Bitrate: $inputBitrateKbps Kbps" -ForegroundColor White
Write-Host "====================================================" -ForegroundColor DarkGray

# ------------------------------------------------------------------------------
# 3. SELECT TARGET FORMAT (CONTAINER)
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Target Output Format (Extension):" -ForegroundColor Cyan
Write-Host "1. MP4  (.mp4  - Universal Compatibility)" -ForegroundColor White
Write-Host "2. MKV  (.mkv  - Matroska Multimedia Container)" -ForegroundColor White
Write-Host "3. MOV  (.mov  - Apple QuickTime Format)" -ForegroundColor White
Write-Host "4. FLV  (.flv  - Flash Video Format)" -ForegroundColor White
Write-Host "5. AVI  (.avi  - Audio Video Interleave)" -ForegroundColor White
Write-Host "6. TS   (.ts   - MPEG Transport Stream)" -ForegroundColor White
Write-Host "7. WEBM (.webm - Web Friendly Format)" -ForegroundColor White
Write-Host "8. Custom Extension (User specified extension, e.g., 3gp, ogv)" -ForegroundColor Yellow

$formatChoice = Read-Host "Enter choice [1-8, Default is 1]"
$targetExt = "mp4"

switch ($formatChoice) {
    "2" { $targetExt = "mkv" }
    "3" { $targetExt = "mov" }
    "4" { $targetExt = "flv" }
    "5" { $targetExt = "avi" }
    "6" { $targetExt = "ts"  }
    "7" { $targetExt = "webm" }
    "8" {
        $userExt = (Read-Host "Enter extension without dot (e.g., 3gp, ogv, vob)").Trim().ToLower()
        if (-not [string]::IsNullOrWhiteSpace($userExt)) { $targetExt = $userExt }
    }
    Default { $targetExt = "mp4" }
}
Write-Host "[V] Target Container Set to: .$targetExt" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 4. SELECT TARGET RESOLUTION STANDARD
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Output Resolution Standard:" -ForegroundColor Cyan
Write-Host "1. Original Resolution (Keep source $resolutionStr)" -ForegroundColor White
Write-Host "2. Full HD 1080p (1920x1080)" -ForegroundColor White
Write-Host "3. 2K QHD (2560x1440)" -ForegroundColor White
Write-Host "4. 4K UHD (3840x2160)" -ForegroundColor White
Write-Host "5. Custom Resolution (User Specified Width x Height)" -ForegroundColor Yellow
$resChoice = Read-Host "Enter choice [1-5, Default is 1]"

$scaleFilter = ""
switch ($resChoice) {
    "2" { $scaleFilter = "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1" }
    "3" { $scaleFilter = "scale=2560:1440:force_original_aspect_ratio=decrease,pad=2560:1440:(ow-iw)/2:(oh-ih)/2:black,setsar=1" }
    "4" { $scaleFilter = "scale=3840:2160:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black,setsar=1" }
    "5" {
        Write-Host ""
        $customW = Read-Host "Enter target WIDTH (e.g., 1280, 1920, 2560)"
        $customH = Read-Host "Enter target HEIGHT (e.g., 720, 1080, 1440)"

        if ($customW -match '^\d+$' -and $customH -match '^\d+$' -and [int]$customW -gt 0 -and [int]$customH -gt 0) {
            $tW = [int]$customW - ($customW % 2)
            $tH = [int]$customH - ($customH % 2)
            $scaleFilter = "scale=${tW}:${tH}:force_original_aspect_ratio=decrease,pad=${tW}:${tH}:(ow-iw)/2:(oh-ih)/2:black,setsar=1"
            Write-Host "[V] Custom resolution set: ${tW}x${tH}" -ForegroundColor Green
        } else {
            Write-Host "[!] Invalid custom values. Keeping original resolution." -ForegroundColor Yellow
        }
    }
    Default {
        Write-Host "[i] Keeping Original Resolution ($resolutionStr)." -ForegroundColor White
    }
}

# ------------------------------------------------------------------------------
# 5. SELECT QUALITY OPTION & CODEC SELECTION
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Codec Standard:" -ForegroundColor Cyan
Write-Host "1. H.264 / AVC (High compatibility - Standard Default)" -ForegroundColor White
Write-Host "2. H.265 / HEVC (Better compression & smaller file size)" -ForegroundColor White
$codecChoice = Read-Host "Enter choice [1-2, Default is 1]"
$codecType = if ($codecChoice -eq "2") { "hevc" } else { "h264" }

Write-Host ""
Write-Host "Select Output Quality Profile:" -ForegroundColor Cyan
Write-Host "1. Custom Target Bitrate (Source is $inputBitrateKbps Kbps - Precise Quality & Size)" -ForegroundColor Green
Write-Host "2. Smart High-Quality Balance (CRF/CQP 22 - Good balance)" -ForegroundColor White
Write-Host "3. Smart Compression (CRF/CQP 26 - Small file size)" -ForegroundColor Yellow

$qualityChoice = Read-Host "Enter choice [1-3, Default is 1]"

$encoderArgs = ""

switch ($qualityChoice) {
    "2" {
        $videoEncoder = Get-TargetVideoEncoder -codecType $codecType
        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $encoderArgs = "-rc cqp -qp_i 22 -qp_p 22 -quality quality" }
            "*_nvenc" { $encoderArgs = "-rc constqp -qp 22 -preset p6" }
            "*_qsv"   { $encoderArgs = "-global_quality 22" }
            "libx265" { $encoderArgs = "-crf 22 -preset medium" }
            Default   { $encoderArgs = "-crf 22" }
        }
        Write-Host "[i] Profile: SMART HIGH-QUALITY BALANCE (CRF 22)" -ForegroundColor White
    }
    "3" {
        $videoEncoder = Get-TargetVideoEncoder -codecType $codecType
        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $encoderArgs = "-rc cqp -qp_i 26 -qp_p 26 -quality quality" }
            "*_nvenc" { $encoderArgs = "-rc constqp -qp 26 -preset p6" }
            "*_qsv"   { $encoderArgs = "-global_quality 26" }
            "libx265" { $encoderArgs = "-crf 26 -preset fast" }
            Default   { $encoderArgs = "-crf 26" }
        }
        Write-Host "[i] Profile: SMART COMPRESSION (CRF 26)" -ForegroundColor Yellow
    }
    Default {
        Write-Host ""
        $userBitrate = Read-Host "Enter target Bitrate in Kbps (Source is $inputBitrateKbps Kbps - Default is $inputBitrateKbps)"
        if (-not ($userBitrate -match '^\d+$') -or [int]$userBitrate -le 0) {
            $userBitrate = $inputBitrateKbps
        }

        $videoEncoder = Get-TargetVideoEncoder -codecType $codecType

        $bitrateK = "${userBitrate}k"
        $maxBitrateK = "$([int]$userBitrate * 1.2)k"

        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $encoderArgs = "-rc vbr_peak -b:v $bitrateK -maxrate $maxBitrateK -quality quality" }
            "*_nvenc" { $encoderArgs = "-rc vbr -b:v $bitrateK -maxrate $maxBitrateK -preset p6" }
            "*_qsv"   { $encoderArgs = "-b:v $bitrateK -maxrate $maxBitrateK" }
            "libx265" { $encoderArgs = "-b:v $bitrateK -maxrate $maxBitrateK -preset medium" }
            Default   { $encoderArgs = "-b:v $bitrateK -maxrate $maxBitrateK" }
        }
        Write-Host "[i] Profile: CUSTOM TARGET BITRATE ($bitrateK)" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# 6. EXECUTION & AUTOMATIC SAFE FALLBACK ENGINE
# ------------------------------------------------------------------------------
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$outputName = "${fileNameWithoutExt}-CONVERTED.${targetExt}"
$outputPath = Join-Path $global:WorkingDir $outputName

$vfArg = if ($scaleFilter -ne "") { "-vf `"$scaleFilter`"" } else { "" }
$audioCodec = if ($targetExt -eq "webm") { "-c:a libvorbis" } else { "-c:a aac -b:a 192k" }

Write-Host ""
Write-Host "[+] Transcoding '$inputName' to '$outputName'..." -ForegroundColor Green

# 1st Attempt: Execute user selected configuration
$ffmpegArgs = "-y -i `"$inputPath`" $vfArg -c:v $videoEncoder $encoderArgs $audioCodec `"$outputPath`""
$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# AUTOMATIC FALLBACK TO SAFE DEFAULTS (H.264 CPU + AAC) IF PROCESS FAILS OR PRODUCES NO VIDEO
$isSuccess = ($process.ExitCode -eq 0 -and (Test-Path $outputPath))
if ($isSuccess) {
    # Check if video stream exists in the generated file
    $hasVideoStream = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 `"$outputPath`").Trim()
    if ([string]::IsNullOrWhiteSpace($hasVideoStream)) {
        $isSuccess = $false
        Remove-Item -Path $outputPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not $isSuccess) {
    Write-Host ""
    Write-Host "[!] WARNING: Transcoding failed with selected codec/container configuration." -ForegroundColor Yellow
    Write-Host "[+] Activating AUTO-FALLBACK: Re-encoding with Universal Safe Defaults (H.264 CPU + AAC)..." -ForegroundColor Cyan
    
    $fallbackArgs = "-y -i `"$inputPath`" $vfArg -c:v libx264 -crf 22 -c:a aac -b:a 192k `"$outputPath`""
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList $fallbackArgs -Wait -NoNewWindow -PassThru
}

# ------------------------------------------------------------------------------
# 7. FINAL RESULT CHECK
# ------------------------------------------------------------------------------
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    $origMB = [math]::Round((Get-Item $inputPath).Length / 1MB, 2)
    $outMB  = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] VIDEO CONVERSION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  - Input File Size  : $origMB MB ($resolutionStr)" -ForegroundColor White
    Write-Host "  - Output File Size : $outMB MB (.$targetExt)" -ForegroundColor Green
    Write-Host "  - Output Location  : $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "An error occurred during video conversion even after safe fallback!"
}