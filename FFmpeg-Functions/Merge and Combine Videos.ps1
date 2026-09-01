# Module: Merge-And-Combine-Videos.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "            MERGE & COMBINE VIDEOS MODULE           " -ForegroundColor Cyan
Write-Host "   (Auto-Scale, Pad Black Bars & Normalize Audio)   " -ForegroundColor Cyan
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

# 2. Input Multiple Video Files & Bitrate Analysis
Write-Host ""
$countInput = Read-Host "How many video files do you want to merge?"
$videoCount = if ($countInput -match '^\d+$' -and [int]$countInput -gt 1) { [int]$countInput } else { 0 }

if ($videoCount -lt 2) {
    Write-Host "[!] Error: You need to input at least 2 video files to merge!" -ForegroundColor Red
    return
}

$inputFiles = @()
$bitrateList = @()

for ($i = 1; $i -le $videoCount; $i++) {
    $vName = Read-Host "Enter Video $i file name (e.g., clip$i.mp4)"
    $vPath = Join-Path $global:WorkingDir $vName
    if (Test-Path $vPath) {
        $inputFiles += $vPath
        
        # Check Bitrate via FFprobe
        $brRaw = (ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 `"$vPath`").Trim()
        if ($brRaw -match '^\d+$') {
            $bitrateList += [int]$brRaw
        }
    } else {
        Write-Host "[!] File '$vName' not found in $global:WorkingDir! Aborting." -ForegroundColor Red
        return
    }
}

# Calculate Bitrate Statistics
Write-Host ""
Write-Host "====================================================" -ForegroundColor DarkGray
Write-Host " INPUT VIDEOS BITRATE STATISTICS:" -ForegroundColor Yellow
if ($bitrateList.Count -gt 0) {
    $maxBitrateKbps = [math]::Round(($bitrateList | Measure-Object -Maximum).Maximum / 1000)
    $avgBitrateKbps = [math]::Round(($bitrateList | Measure-Object -Average).Average / 1000)
    Write-Host "  - Maximum Input Bitrate : $maxBitrateKbps Kbps" -ForegroundColor White
    Write-Host "  - Average Input Bitrate : $avgBitrateKbps Kbps" -ForegroundColor White
} else {
    Write-Host "  - Bitrate Analysis: Unable to read metadata for some files." -ForegroundColor DarkGray
    $avgBitrateKbps = 3500
}
Write-Host "====================================================" -ForegroundColor DarkGray

# 3. Select Target Resolution Standard
Write-Host ""
Write-Host "Select Output Resolution Standard:" -ForegroundColor Cyan
Write-Host "1. Full HD 1080p (1920x1080 - Recommended)" -ForegroundColor White
Write-Host "2. 2K QHD (2560x1440 - Sharper Quality)" -ForegroundColor White
Write-Host "3. 4K UHD (3840x2160 - Maximum Resolution)" -ForegroundColor White
Write-Host "4. Custom Resolution (User Specified Width x Height)" -ForegroundColor Yellow
$resChoice = Read-Host "Enter choice (1-4, Default is 1)"

$targetW = 1920; $targetH = 1080
switch ($resChoice) {
    "2" { $targetW = 2560; $targetH = 1440 }
    "3" { $targetW = 3840; $targetH = 2160 }
    "4" {
        Write-Host ""
        $customW = Read-Host "Enter target WIDTH (e.g., 1080, 1280, 2560)"
        $customH = Read-Host "Enter target HEIGHT (e.g., 1920, 720, 1080)"

        if ($customW -match '^\d+$' -and $customH -match '^\d+$' -and [int]$customW -gt 0 -and [int]$customH -gt 0) {
            $targetW = [int]$customW - ($customW % 2)
            $targetH = [int]$customH - ($customH % 2)
            Write-Host "[V] Custom resolution set: ${targetW}x${targetH}" -ForegroundColor Green
        } else {
            Write-Host "[!] Invalid custom values. Fallback to 1920x1080." -ForegroundColor Yellow
            $targetW = 1920; $targetH = 1080
        }
    }
}

# 4. Select Quality Option
Write-Host ""
Write-Host "Select Output Quality Profile:" -ForegroundColor Cyan
Write-Host "1. Custom Target Bitrate (User specified Kbps/Mbps - Precise Quality & Size)" -ForegroundColor Green
Write-Host "2. Smart High-Quality Balance (CRF/CQP 22 - Good balance)" -ForegroundColor White
Write-Host "3. Smart Compression HEVC (CRF/CQP 26 - Small file size)" -ForegroundColor Yellow

$qualityChoice = Read-Host "Enter choice (1-3, Default is 1)"

$videoEncoder = Get-TargetVideoEncoder -codecType "hevc"

# Build Encoder Quality Control Parameters
$encoderArgs = ""

switch ($qualityChoice) {
    "2" {
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
        switch -Wildcard ($videoEncoder) {
            "*_amf"   { $encoderArgs = "-rc cqp -qp_i 26 -qp_p 26 -quality quality" }
            "*_nvenc" { $encoderArgs = "-rc constqp -qp 26 -preset p6" }
            "*_qsv"   { $encoderArgs = "-global_quality 26" }
            "libx265" { $encoderArgs = "-crf 26 -preset fast" }
            Default   { $encoderArgs = "-crf 26" }
        }
        Write-Host "[i] Profile: SMART COMPRESSION HEVC (CRF 26)" -ForegroundColor Yellow
    }
    Default {
        # Custom Bitrate Input
        Write-Host ""
        $userBitrate = Read-Host "Enter target Bitrate in Kbps (e.g., 3500, 4500, 6000 - Default is $avgBitrateKbps)"
        if (-not ($userBitrate -match '^\d+$') -or [int]$userBitrate -le 0) {
            $userBitrate = $avgBitrateKbps
        }

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

# 5. Build Complex Filter Command (Auto-Scale, Pad Black Bars & Normalize Audio)
Write-Host ""
Write-Host "[+] Building auto-scaling and padding filters..." -ForegroundColor Yellow

$inputsCmd = ""
$filterComplex = ""

for ($idx = 0; $idx -lt $inputFiles.Count; $idx++) {
    $inputsCmd += "-i `"$($inputFiles[$idx])`" "
    
    $filterComplex += "[${idx}:v]scale=$targetW\:$targetH\:force_original_aspect_ratio=decrease," +
                      "pad=$targetW\:$targetH\:(ow-iw)/2\:(oh-ih)/2:black,setsar=1,fps=30[v${idx}]; " +
                      "[${idx}:a]aformat=sample_rates=48000:channel_layouts=stereo[a${idx}]; "
}

for ($idx = 0; $idx -lt $inputFiles.Count; $idx++) {
    $filterComplex += "[v${idx}][a${idx}]"
}
$filterComplex += "concat=n=$($inputFiles.Count):v=1:a=1[outv][outa]"

# 6. Output File Execution
$outputName = "MERGED-OUTPUT-$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host "[+] Merging $($inputFiles.Count) videos into $outputName ..." -ForegroundColor Green

$ffmpegArgs = "-y $inputsCmd -filter_complex `"$filterComplex`" -map `"[outv]`" -map `"[outa]`" -c:v $videoEncoder $encoderArgs -c:a aac -b:a 192k `"$outputPath`""

$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 7. Output Check
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] VIDEO MERGING COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "    Resolution : ${targetW}x${targetH} (30 FPS)" -ForegroundColor White
    Write-Host "    Output Location: $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "An error occurred during video merging!"
}