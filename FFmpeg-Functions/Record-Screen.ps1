# Module: Record-Screen.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "              SMART SCREEN RECORDER                 " -ForegroundColor Cyan
Write-Host "   (Fast, Lightweight & Easy Screen Capture)        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Select Recording Target (Full Screen vs Window)
Write-Host ""
Write-Host "Select Capture Target:" -ForegroundColor Cyan
Write-Host "1. Full Screen (Capture entire desktop)" -ForegroundColor White
Write-Host "2. Specific Window (Select active application window)" -ForegroundColor White

$targetChoice = Read-Host "Enter choice (1-2, Default is 1)"

$captureInput = "desktop"
$windowTitle = ""

if ($targetChoice -eq "2") {
    Write-Host ""
    Write-Host "[+] Scanning active windows..." -ForegroundColor Yellow
    
    # Get active windows with visible titles
    $processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object Id, ProcessName, MainWindowTitle
    
    if (-not $processes -or $processes.Count -eq 0) {
        Write-Host "[!] No active application windows found! Fallback to Full Screen." -ForegroundColor Yellow
    } else {
        Write-Host "====================================================" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $processes.Count; $i++) {
            Write-Host "  $($i + 1). [$($processes[$i].ProcessName)] $($processes[$i].MainWindowTitle)" -ForegroundColor White
        }
        Write-Host "====================================================" -ForegroundColor DarkGray
        
        $winChoice = Read-Host "Select window number to record"
        if ($winChoice -match '^\d+$' -and [int]$winChoice -gt 0 -and [int]$winChoice -le $processes.Count) {
            $windowTitle = $processes[[int]$winChoice - 1].MainWindowTitle
            $captureInput = "title=$windowTitle"
            Write-Host "[V] Target Window Selected: '$windowTitle'" -ForegroundColor Green
        } else {
            Write-Host "[!] Invalid choice! Fallback to Full Screen." -ForegroundColor Yellow
        }
    }
}

# 2. Select Quality & Compression Profile
Write-Host ""
Write-Host "Select Video Quality & Size Profile:" -ForegroundColor Cyan
Write-Host "1. Medium Quality (Smallest file size - Ideal for long meetings/tutorials)" -ForegroundColor White
Write-Host "2. High Quality (Balanced clarity & size - Recommended)" -ForegroundColor White
Write-Host "3. Ultra Quality (Maximum sharpness - Larger file size)" -ForegroundColor White

$qualityChoice = Read-Host "Enter choice (1-3, Default is 2)"

$crfVal = "24"
switch ($qualityChoice) {
    "1" { $crfVal = "28"; Write-Host "[i] Quality Mode: MEDIUM (Small size)" -ForegroundColor Yellow }
    "3" { $crfVal = "18"; Write-Host "[i] Quality Mode: ULTRA (Max clarity)" -ForegroundColor Green }
    Default { $crfVal = "22"; Write-Host "[i] Quality Mode: HIGH (Balanced)" -ForegroundColor Green }
}

# 3. Audio Source Selection
Write-Host ""
Write-Host "Select Audio Capture Source:" -ForegroundColor Cyan
Write-Host "1. No Audio (Mute / Video Only)" -ForegroundColor White
Write-Host "2. Capture Audio (Microphone / System Sound via DirectShow)" -ForegroundColor White

$audioChoice = Read-Host "Enter choice (1-2, Default is 1)"

$audioArgs = ""
if ($audioChoice -eq "2") {
    Write-Host ""
    Write-Host "[+] DirectShow Audio Devices available on your system:" -ForegroundColor Yellow
    
    # Query DirectShow audio devices
    $dsRaw = ffmpeg -list_devices true -f dshow -i dummy 2>&1
    $audioDevices = @()
    
    $isAudioSection = $false
    foreach ($line in $dsRaw) {
        if ($line -match 'DirectShow audio devices') { $isAudioSection = $true; continue }
        if ($line -match 'DirectShow video devices') { $isAudioSection = $false }
        if ($isAudioSection -and $line -match '"([^"]+)"') {
            $audioDevices += $matches[1]
        }
    }

    if ($audioDevices.Count -gt 0) {
        Write-Host "====================================================" -ForegroundColor DarkGray
        for ($a = 0; $a -lt $audioDevices.Count; $a++) {
            Write-Host "  $($a + 1). $($audioDevices[$a])" -ForegroundColor White
        }
        Write-Host "====================================================" -ForegroundColor DarkGray
        
        $aChoice = Read-Host "Select Audio Device number to record"
        if ($aChoice -match '^\d+$' -and [int]$aChoice -gt 0 -and [int]$aChoice -le $audioDevices.Count) {
            $selectedAudioDev = $audioDevices[[int]$aChoice - 1]
            $audioArgs = "-f dshow -i audio=`"$selectedAudioDev`" -c:a aac -b:a 128k"
            Write-Host "[V] Audio Device Set: '$selectedAudioDev'" -ForegroundColor Green
        } else {
            Write-Host "[!] No valid audio device selected. Recording video only." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] No DirectShow audio device detected. Recording video only." -ForegroundColor Yellow
    }
}

# 4. Prepare Output File & Instructions
$outputName = "SCREEN-REC-$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4"
$outputPath = Join-Path $global:WorkingDir $outputName

Write-Host ""
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "               READY TO RECORD SCREEN               " -ForegroundColor Yellow
Write-Host "  - Output File: $outputName" -ForegroundColor White
Write-Host "  - To STOP recording: Press 'Q' or 'Ctrl + C' in this window" -ForegroundColor Red
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host ""
$null = Read-Host "Press ENTER to START recording now..."

# 5. Execute Screen Recording Command
$ffmpegArgs = "-y -f gdigrab -framerate 30 -i $captureInput $audioArgs -c:v libx264 -preset ultrafast -crf $crfVal -pix_fmt yuv420p `"$outputPath`""

Write-Host "[+] RECORDING IN PROGRESS... Press 'Q' on this terminal window to Stop!" -ForegroundColor Green

$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 6. Final Output Check
if (Test-Path $outputPath) {
    $recSizeMB = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "[V] SCREEN RECORDING SAVED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  - File Size: $recSizeMB MB" -ForegroundColor White
    Write-Host "  - File Path: $outputPath" -ForegroundColor White
    Write-Host "====================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "Recording failed or output file not created."
}