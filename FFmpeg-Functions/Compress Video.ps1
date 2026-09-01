# Module: Smart-Compress-Video.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "             SMART VIDEO COMPRESSOR                 " -ForegroundColor Cyan
Write-Host "  (Analyze Metadata & Optimize Quality/Size)        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Hardware Detection Function
function Get-TargetVideoEncoder {
    param ([string]$codecType = "hevc")

    Write-Host ""
    Write-Host "Select Hardware Acceleration Mode:" -ForegroundColor Cyan
    Write-Host "1. CPU (Software Encoding - Best Quality/Size Ratio)" -ForegroundColor White
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
$inputName = Read-Host "Enter INPUT video file name (e.g., video.mp4)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

# 3. Analyze Video Metadata using FFprobe
Write-Host ""
Write-Host "[+] Analyzing video metadata via FFprobe..." -ForegroundColor Yellow

$probeWidth   = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$probeHeight  = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()
$probeBitrate = (ffprobe -v error -select_streams v:0 -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 `"$inputPath`").Trim()

$originalSizeMB = [math]::Round((Get-Item $inputPath).Length / 1MB, 2)
$originalBitrateKbps = if ($probeBitrate -match '^\d+$') { [math]::Round([int]$probeBitrate / 1000) } else { "Unknown" }

Write-Host "====================================================" -ForegroundColor DarkGray
Write-Host " CURRENT VIDEO INFORMATION:" -ForegroundColor Yellow
Write-Host "  - File Size: $originalSizeMB MB" -ForegroundColor White
Write-Host "  - Resolution: ${probeWidth}x${probeHeight}" -ForegroundColor White
Write-Host "  - Total Bitrate: $originalBitrateKbps Kbps" -ForegroundColor White
Write-Host "====================================================" -ForegroundColor DarkGray

# 4. Codec & Hardware Selection
Write-Host ""
Write-Host "Select Output Compression Profile:" -ForegroundColor Cyan
Write-Host "1. High Quality Compression (Recommended: HEVC / H.265 - Small size, clear image)" -ForegroundColor White
Write-Host "2. Balanced Compression (H.264 - Good compatibility across all devices)" -ForegroundColor White

$codecChoice = Read-Host "Enter choice (1-2, Default is 1)"

$codecType = if ($codecChoice -eq "2") { "h264" } else { "hevc" }
$videoEncoder = Get-TargetVideoEncoder -codecType $codecType

# 5. Build Hardware Compression Parameters (Optimized Presets & QP)
$encoderArgs = ""

switch -Wildcard ($videoEncoder) {
    "*_amf" { 
        # AMD AMF: CQP=28 cho HEVC, CQP=26 cho H264
        $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }
        $encoderArgs = "-rc cqp -qp_i $qpVal -qp_p $qpVal -quality quality" 
    }
    "*_nvenc" { 
        # NVIDIA NVENC: ConstQP=28 (HEVC) / 26 (H264), Slow Preset để tối ưu bitrate
        $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }
        $encoderArgs = "-rc constqp -qp $qpVal -preset p6" 
    }
    "*_qsv" { 
        # Intel QuickSync: CQP=28
        $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }
        $encoderArgs = "-global_quality $qpVal" 
    }
    "libx265" { 
        # CPU HEVC: CRF=28 - Medium preset giúp nén dung lượng nhỏ nhất mà nét
        $encoderArgs = "-crf 28 -preset medium" 
    }
    "libx264" { 
        # CPU H264: CRF=24
        $encoderArgs = "-crf 24 -preset medium" 
    }
    Default { 
        $encoderArgs = "-crf 26" 
    }
}

# Option hạ Resolution nếu file gốc quá lớn (Ví dụ: 4K -> 1080p)
$scaleFilter = ""
if ([int]$probeWidth -gt 1920) {
    Write-Host ""
    $downscale = Read-Host "Original video is above 1080p ($probeWidth x $probeHeight). Downscale to 1080p for massive size reduction? (Y/N, Default is Y)"
    if ($downscale -ne 'N' -and $downscale -ne 'n') {
        $scaleFilter = "-vf scale=1920:-2"
        Write-Host "[i] Resolution will be scaled down to 1080p." -ForegroundColor Yellow
    }
}

# 6. Execute Processing
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$outputName = "${fileNameWithoutExt}-COMPRESSED.mp4"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host ""
Write-Host "Compressing: $inputName -> $outputName ..." -ForegroundColor Green

$ffmpegArgs = "-y -i `"$inputPath`" $scaleFilter -c:v $videoEncoder $encoderArgs -c:a aac -b:a 128k `"$outputPath`""
$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 7. Output Check & Size Comparison
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    $newSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
    $savedPercent = [math]::Round((($originalSizeMB - $newSizeMB) / $originalSizeMB) * 100, 1)

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] VIDEO COMPRESSION SUCCESSFUL!" -ForegroundColor Green
    Write-Host "  - Original Size : $originalSizeMB MB" -ForegroundColor White
    Write-Host "  - Compressed Size: $newSizeMB MB" -ForegroundColor Green
    Write-Host "  - Space Saved    : $savedPercent %" -ForegroundColor Yellow
    Write-Host "  - Output Location: $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "An error occurred during video compression!"
}