# Module: Record-Screen.ps1
# Author: Designed by trungtdv4@gmail.com. All Rights Reserved.
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "         SMART SCREEN RECORDER (MULTI-MONITOR)      " -ForegroundColor Cyan
Write-Host "  Designed by trungtdv4@gmail.com. All Rights Reserved. " -ForegroundColor DarkGray
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. SELECT CAPTURE TARGET & DISPLAY MONITOR HANDLING
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Display Monitor Option:" -ForegroundColor Cyan
Write-Host "1. All Monitors Combined / Virtual Desktop (Default)" -ForegroundColor White
Write-Host "2. Select Specific Display Screen (Monitor 1, Monitor 2...)" -ForegroundColor White

$monChoice = Read-Host "Enter choice (1-2, Default is 1)"

Add-Type -AssemblyName System.Windows.Forms
$screens = [System.Windows.Forms.Screen]::AllScreens
$captureArgs = ""

if ($monChoice -eq "2") {
    Write-Host ""
    Write-Host "[+] Detected Display Screens:" -ForegroundColor Yellow
    for ($s = 0; $s -lt $screens.Count; $s++) {
        $scr = $screens[$s]
        $primaryTag = if ($scr.Primary) { " (Primary)" } else { "" }
        Write-Host "  $($s + 1). Screen $($s + 1): $($scr.Bounds.Width)x$($scr.Bounds.Height) at Offset X=$($scr.Bounds.X), Y=$($scr.Bounds.Y)$primaryTag" -ForegroundColor White
    }
    
    $sSel = Read-Host "Select screen number to record"
    if ($sSel -match '^\d+$' -and [int]$sSel -gt 0 -and [int]$sSel -le $screens.Count) {
        $chosenScr = $screens[[int]$sSel - 1]
        $w = $chosenScr.Bounds.Width
        $h = $chosenScr.Bounds.Height
        $x = $chosenScr.Bounds.X
        $y = $chosenScr.Bounds.Y

        $captureArgs = "-f gdigrab -offset_x $x -offset_y $y -video_size ${w}x${h} -i desktop"
        Write-Host "[V] Screen $($sSel) Selected (${w}x${h})." -ForegroundColor Green
    } else {
        Write-Host "[!] Invalid choice. Fallback to All Monitors." -ForegroundColor Yellow
        $captureArgs = "-f gdigrab -i desktop"
    }
} else {
    # Default: All Monitors Combined
    $vWidth  = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
    $vHeight = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
    $vLeft   = [System.Windows.Forms.SystemInformation]::VirtualScreen.Left
    $vTop    = [System.Windows.Forms.SystemInformation]::VirtualScreen.Top

    $captureArgs = "-f gdigrab -offset_x $vLeft -offset_y $vTop -video_size ${vWidth}x${vHeight} -i desktop"
    Write-Host "[V] Recording Display Resolution: ${vWidth}x${vHeight}" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 2. SELECT QUALITY PROFILE
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Video Quality Profile:" -ForegroundColor Cyan
Write-Host "1. Medium Quality (Smallest file size)" -ForegroundColor White
Write-Host "2. High Quality (Balanced clarity & size - Recommended)" -ForegroundColor White
Write-Host "3. Ultra Quality (Maximum sharpness - Larger size)" -ForegroundColor White

$qualityChoice = Read-Host "Enter choice (1-3, Default is 2)"

$crfVal = "22"
switch ($qualityChoice) {
    "1" { $crfVal = "28"; Write-Host "[i] Profile: MEDIUM (Small File)" -ForegroundColor Yellow }
    "3" { $crfVal = "18"; Write-Host "[i] Profile: ULTRA (Max Quality)" -ForegroundColor Green }
    Default { $crfVal = "22"; Write-Host "[i] Profile: HIGH (Balanced)" -ForegroundColor Green }
}

# ------------------------------------------------------------------------------
# 3. AUDIO SOURCE HANDLING (MUTE VS RECORD WITH AUDIO & DUAL-INPUT MIC SUPPORT)
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "Select Audio Capture Mode:" -ForegroundColor Cyan
Write-Host "1. Record Mute (No Audio / Video Only)" -ForegroundColor White
Write-Host "2. Record with Audio (System Sound & Optional Microphone)" -ForegroundColor White

$audioChoice = Read-Host "Enter choice (1-2, Default is 1)"

$audioArgs = ""
$filterAudioArgs = ""

if ($audioChoice -eq "2") {
    Write-Host ""
    Write-Host "[+] Scanning DirectShow audio devices on system..." -ForegroundColor Yellow
    
    $dsRaw = ffmpeg -hide_banner -list_devices true -f dshow -i dummy 2>&1
    
    $audioDevices = @()
    foreach ($line in $dsRaw) {
        if ($line -match '"([^"]+)"') {
            $devName = $matches[1]
            if ($devName -notmatch 'Camera|Webcam|Video|Virtual') {
                if (-not ($audioDevices -contains $devName)) {
                    $audioDevices += $devName
                }
            }
        }
    }

    # Tự động tìm thiết bị Stereo Mix/Wave Out mặc định trong danh sách
    $stereoMixDev = $audioDevices | Where-Object { $_ -match "Stereo Mix" -or $_ -match "Wave Out" } | Select-Object -First 1

    Write-Host ""
    Write-Host "Do you have/want to record a Microphone?" -ForegroundColor Cyan
    Write-Host "1. No  (Record System Sound / Stereo Mix only)" -ForegroundColor White
    Write-Host "2. Yes (Select Microphone device to mix with System Sound)" -ForegroundColor White
    $hasMicChoice = Read-Host "Enter choice (1-2, Default is 1)"

    if ($hasMicChoice -eq "2" -and $audioDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor DarkGray
        Write-Host " DETECTED AUDIO INPUT DEVICES FOR MICROPHONE:" -ForegroundColor Yellow
        for ($a = 0; $a -lt $audioDevices.Count; $a++) {
            Write-Host "  $($a + 1). $($audioDevices[$a])" -ForegroundColor White
        }
        Write-Host "====================================================" -ForegroundColor DarkGray
        
        $aChoice = Read-Host "Select Microphone Device number"
        if ($aChoice -match '^\d+$' -and [int]$aChoice -gt 0 -and [int]$aChoice -le $audioDevices.Count) {
            $selectedMicDev = $audioDevices[[int]$aChoice - 1]
            
            if ($stereoMixDev) {
                # Cấu hình 2 nguồn Audio (Stereo Mix + Mic) rồi dùng filter amix để hòa trộn
                $audioArgs = "-f dshow -i audio=`"$stereoMixDev`" -f dshow -i audio=`"$selectedMicDev`""
                $filterAudioArgs = "-filter_complex `"[1:a][2:a]amix=inputs=2:duration=first[aout]`" -map 0:v -map `"[aout]`""
                Write-Host "[V] Audio Mode: DUAL INPUT -> System Sound ($stereoMixDev) + Mic ($selectedMicDev)" -ForegroundColor Green
            } else {
                # Trường hợp máy không có Stereo Mix thì quay với 1 Nguồn Mic được chọn
                $audioArgs = "-f dshow -i audio=`"$selectedMicDev`""
                Write-Host "[V] Audio Mode: Single Microphone Input ($selectedMicDev)" -ForegroundColor Green
            }
        } else {
            Write-Host "[!] Invalid selection. Fallback to System Sound only." -ForegroundColor Yellow
            if ($stereoMixDev) { $audioArgs = "-f dshow -i audio=`"$stereoMixDev`"" }
        }
    } else {
        # Tùy chọn "No Mic": Thu âm thanh hệ thống qua Stereo Mix
        if ($stereoMixDev) {
            $audioArgs = "-f dshow -i audio=`"$stereoMixDev`""
            Write-Host "[V] Audio Mode: System Sound / Stereo Mix ($stereoMixDev)" -ForegroundColor Green
        } else {
            Write-Host "[!] NOTICE: 'Stereo Mix' device not found in Windows Sound settings." -ForegroundColor Yellow
            Write-Host "    To record System/Game Sound: Press Win+R -> type 'mmsys.cpl' -> Recording tab -> Enable 'Stereo Mix'." -ForegroundColor Cyan
            Write-Host "    Recording video in MUTE mode..." -ForegroundColor DarkGray
        }
    }
}

# ------------------------------------------------------------------------------
# 4. EXECUTION & SAVE RECORDING
# ------------------------------------------------------------------------------
$outputName = "SCREEN-REC-$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host ""
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "               READY TO RECORD SCREEN               " -ForegroundColor Yellow
Write-Host "  - Output File: $outputName" -ForegroundColor White
Write-Host "  - To STOP recording: Click on this window & press 'Q'" -ForegroundColor Red
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host ""
$null = Read-Host "Press ENTER to START recording now..."

# Ghép cờ mã hóa âm thanh nếu có dữ liệu Audio
$audioCodecArgs = if ($audioArgs -ne "") { "-c:a aac -b:a 128k" } else { "" }
$ffmpegArgs = "-y $captureArgs $audioArgs $filterAudioArgs -framerate 30 -c:v libx264 -preset ultrafast -crf $crfVal -pix_fmt yuv420p $audioCodecArgs `"$outputPath`""

Write-Host ""
Write-Host "[+] RECORDING IN PROGRESS... Press 'Q' on terminal to Stop!" -ForegroundColor Green

$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

if (Test-Path $outputPath) {
    $recSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] SCREEN RECORDING SAVED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  - Size : $recSizeMB MB" -ForegroundColor White
    Write-Host "  - Path : $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "Recording failed or output file was not generated."
}