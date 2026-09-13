# Module: Trim-And-Cut-Video.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "               TRIM & CUT VIDEO MODULE              " -ForegroundColor Cyan
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

# 3. Choose Cut Mode
Write-Host ""
Write-Host "Select Cutting Mode:" -ForegroundColor Cyan
Write-Host "1. Trim Head/Tail (Keep middle part only)" -ForegroundColor White
Write-Host "2. Custom Cut N Segments (Extract multiple clips)" -ForegroundColor White

$cutMode = Read-Host "Enter choice (1-2, Default is 1)"

$segments = @()

if ($cutMode -eq "2") {
    $countInput = Read-Host "How many segments do you want to cut?"
    $segmentCount = if ($countInput -match '^\d+$' -and [int]$countInput -gt 0) { [int]$countInput } else { 1 }

    for ($i = 1; $i -le $segmentCount; $i++) {
        Write-Host ""
        Write-Host "--- Segment $i ---" -ForegroundColor Yellow
        $start = Read-Host "Enter START time (e.g., 00:01:20 or 80)"
        $end   = Read-Host "Enter END time   (e.g., 00:03:45 or 225)"
        $segments += [PSCustomObject]@{ Start = $start; End = $end }
    }
} else {
    Write-Host ""
    Write-Host "--- Trim Keep Middle ---" -ForegroundColor Yellow
    $start = Read-Host "Enter START time to keep (e.g., 00:00:30 or 30)"
    $end   = Read-Host "Enter END time to keep   (e.g., 00:05:00 or 300)"
    $segments += [PSCustomObject]@{ Start = $start; End = $end }
}

# 4. Output Mode Selection (For Multiple Segments)
$mergeSegments = $false
if ($segments.Count -gt 1) {
    Write-Host ""
    Write-Host "Select Output Handling for Multiple Segments:" -ForegroundColor Cyan
    Write-Host "1. Merge all cut segments into 01 single video file" -ForegroundColor White
    Write-Host "2. Export as individual separate clip files" -ForegroundColor White
    $outChoice = Read-Host "Enter choice (1-2, Default is 1)"
    if ($outChoice -ne "2") { $mergeSegments = $true }
}

# 5. Select Encoder & Processing Mode
Write-Host ""
Write-Host "Select Output Processing Mode:" -ForegroundColor Cyan
Write-Host "1. ULTRA FAST COPY (-c copy: Instant speed, 100% original quality, no re-encode)" -ForegroundColor Green
Write-Host "   (Note: Cuts at nearest Keyframe. May have 1-2s black screen at start if time is unaligned)" -ForegroundColor DarkGray
Write-Host "2. HEVC / H.265 - Balanced (Frame-accurate cut, high compression)" -ForegroundColor White
Write-Host "3. H.264 - Balanced (Frame-accurate cut, maximum compatibility)" -ForegroundColor White
Write-Host "4. Visually Lossless (Frame-accurate cut, maximum image clarity)" -ForegroundColor White

$qualityChoice = Read-Host "Enter choice (1-4, Default is 1)"

$useStreamCopy = $false
$codecType = "hevc"
$isLossless = $false

switch ($qualityChoice) {
    "2" { $codecType = "hevc" }
    "3" { $codecType = "h264" }
    "4" { $codecType = "hevc"; $isLossless = $true }
    Default { $useStreamCopy = $true }
}

# Bắt buộc chọn phần cứng nếu không dùng Stream Copy
if (-not $useStreamCopy) {
    $videoEncoder = Get-TargetVideoEncoder -codecType $codecType

    $encoderArgs = ""
    if ($isLossless) {
        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $encoderArgs = "-rc cqp -qp_i 18 -qp_p 18 -quality quality" }
            "*_nvenc" { $encoderArgs = "-rc constqp -qp 18 -preset p7" }
            "*_qsv"   { $encoderArgs = "-global_quality 18" }
            "libx265" { $encoderArgs = "-crf 18 -preset slow" }
            "libx264" { $encoderArgs = "-crf 17 -preset slow" }
            Default   { $encoderArgs = "-crf 18" }
        }
    } else {
        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }; $encoderArgs = "-rc cqp -qp_i $qpVal -qp_p $qpVal -quality quality" }
            "*_nvenc" { $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }; $encoderArgs = "-rc constqp -qp $qpVal -preset p6" }
            "*_qsv"   { $qpVal = if ($codecType -eq "hevc") { "28" } else { "26" }; $encoderArgs = "-global_quality $qpVal" }
            "libx265" { $encoderArgs = "-crf 28 -preset medium" }
            "libx264" { $encoderArgs = "-crf 24 -preset medium" }
            Default   { $encoderArgs = "-crf 26" }
        }
    }
}

# 6. Process Cutting
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$tempDir = Join-Path $global:WorkingDir "temp_trim"
if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory | Out-Null }

$cutFiles = @()

Write-Host ""
Write-Host "[+] Cutting segments..." -ForegroundColor Green

for ($idx = 0; $idx -lt $segments.Count; $idx++) {
    $seg = $segments[$idx]
    $segName = "${fileNameWithoutExt}_part$($idx + 1).mp4"
    $segPath = Join-Path $tempDir $segName

    Write-Host " -> Cutting Segment $($idx + 1): $($seg.Start) to $($seg.End)" -ForegroundColor Yellow
    
    if ($useStreamCopy) {
        # Đặt -ss và -to TRƯỚC -i để Fast Seeking nhảy đến Keyframe chính xác nhất
        $ffmpegArgs = "-y -ss $($seg.Start) -to $($seg.End) -i `"$inputPath`" -c copy `"$segPath`""
    } else {
        # Re-encode chuẩn chính xác từng Frame
        $ffmpegArgs = "-y -ss $($seg.Start) -to $($seg.End) -i `"$inputPath`" -c:v $videoEncoder $encoderArgs -c:a aac -b:a 192k `"$segPath`""
    }
    
    $proc = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -eq 0 -and (Test-Path $segPath)) {
        $cutFiles += $segPath
    }
}

# 7. Final Handling (Export or Merge)
if ($cutFiles.Count -eq 0) {
    Write-Error "[!] Cutting failed for all segments!"
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    return
}

if ($mergeSegments -and $cutFiles.Count -gt 1) {
    Write-Host ""
    Write-Host "[+] Merging cut segments into a single file..." -ForegroundColor Yellow
    
    $concatListPath = Join-Path $tempDir "concat_list.txt"
    $concatContent = $cutFiles | ForEach-Object { "file '$($_ -replace '\\', '/')" }
    Set-Content -Path $concatListPath -Value $concatContent

    $finalName = "${fileNameWithoutExt}-CUT-MERGED.mp4"
    $finalPath = Join-Path $global:WorkingDir $finalName

    $mergeArgs = "-y -f concat -safe 0 -i `"$concatListPath`" -c copy `"$finalPath`""
    $mergeProc = Start-Process -FilePath "ffmpeg" -ArgumentList $mergeArgs -Wait -NoNewWindow -PassThru

    if ($mergeProc.ExitCode -eq 0 -and (Test-Path $finalPath)) {
        Write-Host ""
        Write-Host "[V] Successfully trimmed and merged video!" -ForegroundColor Green
        Write-Host "    Saved at: $finalPath" -ForegroundColor White
    }
} else {
    foreach ($file in $cutFiles) {
        $dest = Join-Path $global:WorkingDir (Split-Path $file -Leaf)
        Move-Item -Path $file -Destination $dest -Force
    }
    Write-Host ""
    Write-Host "[V] Successfully cut segment(s) to individual file(s)!" -ForegroundColor Green
    Write-Host "    Files saved in: $global:WorkingDir" -ForegroundColor White
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue