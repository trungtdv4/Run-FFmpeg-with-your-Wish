# Module: Optimize Meeting Recording (Increase Speed, Volume, Compress File).ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "          OPTIMIZE MEETING RECORDING MEDIA          " -ForegroundColor Cyan
Write-Host "  (Increase Speed, Increase Volume, Compress File)  " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Hardware Detection Function
function Get-TargetVideoEncoder {
    param ([string]$codecType = "h264")

    Write-Host ""
    Write-Host "Select Hardware Acceleration Mode:" -ForegroundColor Cyan
    Write-Host "1. CPU (Software Encoding - High Compatibility)" -ForegroundColor White
    Write-Host "2. NVIDIA (NVENC Hardware Acceleration)" -ForegroundColor White
    Write-Host "3. AMD (AMF Hardware Acceleration)" -ForegroundColor White
    Write-Host "4. Intel (QuickSync Hardware Acceleration)" -ForegroundColor White
    
    $gpuChoice = Read-Host "Enter hardware choice (1-4, Default is 1)"
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

# 2. Get Input Media File
$inputName = Read-Host "Enter INPUT media file name (e.g., meeting.mp4 or recording.m4a)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

# 3. User Parameters Input
Write-Host ""
$speedInput = Read-Host "Enter speed multiplier (e.g., 1.2, 1.5, 2.0 - Default is 1.25)"
if (-not [float]::TryParse($speedInput, [ref]1.0) -or [float]$speedInput -le 0) { $speedInput = "1.25" }

$volumeInput = Read-Host "Enter volume boost multiplier (e.g., 1.5, 2.0, 3.0 - Default is 1.5)"
if (-not [float]::TryParse($volumeInput, [ref]1.0) -or [float]$volumeInput -le 0) { $volumeInput = "1.5" }

# 4. Codec & Hardware Selection
Write-Host ""
Write-Host "Select Output Format / Codec:" -ForegroundColor Cyan
Write-Host "1. MP4 / H.264 (Standard Video - Best Compatibility)" -ForegroundColor White
Write-Host "2. MP4 / HEVC (H.265 High Compression Video)" -ForegroundColor White
Write-Host "3. MP3 Audio Only (Extract & Process Audio Only)" -ForegroundColor White

$codecChoice = Read-Host "Enter choice (1-3, Default is 1)"

$isVideo = $true
$videoCodec = ""
$audioCodec = "aac"
$extension = "mp4"

switch ($codecChoice) {
    "2" {
        $videoEncoder = Get-TargetVideoEncoder -codecType "hevc"
    }
    "3" {
        $isVideo = $false
        $audioCodec = "libmp3lame"
        $extension = "mp3"
    }
    Default {
        $videoEncoder = Get-TargetVideoEncoder -codecType "h264"
    }
}

# 5. Build FFmpeg Filter Strings & Encoder Quality Control Parameters
$ptsScale = [math]::Round(1.0 / [float]$speedInput, 4)
$ptsScaleStr = $ptsScale.ToString("0.0000", [System.Globalization.CultureInfo]::InvariantCulture)
$speedStr = ([float]$speedInput).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
$volumeStr = ([float]$volumeInput).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)

$audioFilter = "atempo=$speedStr,volume=$volumeStr"
$videoFilter = "setpts=$ptsScaleStr*PTS"

# === ĐOẠN MỚI THÊM: CẤU HÌNH BỘ NÉN CHỐNG PHÌNH DUNG LƯỢNG ===
$encoderArgs = ""
if ($isVideo) {
    switch -Wildcard ($videoEncoder) {
        "*_amf" { 
            # Dành cho AMD AMF: Ép chất lượng CQP = 28 để file ra siêu nhẹ
            $encoderArgs = "-rc cqp -qp_i 28 -qp_p 28 -quality quality" 
        }
        "*_nvenc" { 
            # Dành cho NVIDIA NVENC: Ép CQ = 28
            $encoderArgs = "-rc constqp -qp 28 -preset p6" 
        }
        "*_qsv" { 
            # Dành cho Intel QuickSync: Ép CQP = 28
            $encoderArgs = "-global_quality 28" 
        }
        "libx26*" { 
            # Dành cho CPU (libx264 / libx265): Ép CRF = 26
            $encoderArgs = "-crf 26 -preset fast" 
        }
        Default { 
            $encoderArgs = "-crf 26" 
        }
    }
}

# 6. Execute Processing
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$outputName = "${fileNameWithoutExt}-OPTIMIZED.${extension}"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host ""
Write-Host "Processing: $inputName -> $outputName ..." -ForegroundColor Green
Write-Host "[i] Speed: ${speedInput}x | Volume Boost: ${volumeInput}x" -ForegroundColor Yellow

# Đã ghép thêm biến $encoderArgs vào câu lệnh bên dưới
if ($isVideo) {
    $ffmpegArgs = "-y -i `"$inputPath`" -vf `"$videoFilter`" -c:v $videoEncoder $encoderArgs -af `"$audioFilter`" -c:a $audioCodec `"$outputPath`""
} else {
    $ffmpegArgs = "-y -i `"$inputPath`" -vn -af `"$audioFilter`" -c:a $audioCodec `"$outputPath`""
}

$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 7. Output Check
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    Write-Host ""
    Write-Host "[V] Meeting recording optimized successfully!" -ForegroundColor Green
    Write-Host "    Output file saved at: $outputPath" -ForegroundColor White
} else {
    Write-Host ""
    Write-Error "An error occurred during media processing!"
}