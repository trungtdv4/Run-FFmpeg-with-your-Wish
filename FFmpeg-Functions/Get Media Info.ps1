# Module: Get-Media-Info.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "             GET MEDIA FILE INFORMATION             " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Function to Display Detailed Media Info via FFprobe
function Show-MediaDetail {
    param ([string]$filePath)

    $fileName = Split-Path $filePath -Leaf
    $fileSizeMB = [math]::Round((Get-Item $filePath).Length / 1MB, 2)

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host " FILE: $fileName ($fileSizeMB MB)" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor DarkGray

    # Check media streams via ffprobe
    $formatName = (ffprobe -v error -show_entries format=format_long_name -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
    $durationSec = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
    $bitrate = (ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()

    # Time formatting
    $durationStr = "Unknown"
    if ($durationSec -match '^\d+(\.\d+)?$') {
        $ts = [timespan]::FromSeconds([double]$durationSec)
        $durationStr = "{0:D2}:{1:D2}:{2:D2}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
    }

    $bitrateKbps = if ($bitrate -match '^\d+$') { "$([math]::Round([int]$bitrate / 1000)) Kbps" } else { "Unknown" }

    Write-Host " [GENERAL]" -ForegroundColor Cyan
    Write-Host "  - Container Format : $formatName" -ForegroundColor White
    Write-Host "  - Duration         : $durationStr" -ForegroundColor White
    Write-Host "  - Overall Bitrate  : $bitrateKbps" -ForegroundColor White

    # Video Stream Info
    $vCodec  = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
    if ($vCodec) {
        $vWidth  = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
        $vHeight = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
        $vFps    = (ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
        
        # Calculate readable FPS
        if ($vFps -like "*/*") {
            $parts = $vFps -split '/'
            if ([int]$parts[1] -gt 0) { $vFps = [math]::Round([int]$parts[0] / [int]$parts[1], 2) }
        }

        Write-Host " [VIDEO STREAM]" -ForegroundColor Green
        Write-Host "  - Video Codec      : $vCodec" -ForegroundColor White
        Write-Host "  - Resolution       : ${vWidth}x${vHeight}" -ForegroundColor White
        Write-Host "  - Frame Rate (FPS) : $vFps fps" -ForegroundColor White
    } else {
        Write-Host " [VIDEO STREAM]     : No Video Stream Detected" -ForegroundColor DarkGray
    }

    # Audio Stream Info
    $aCodec = (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
    if ($aCodec) {
        $aSampleRate = (ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()
        $aChannels   = (ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 `"$filePath`").Trim()

        Write-Host " [AUDIO STREAM]" -ForegroundColor Magenta
        Write-Host "  - Audio Codec      : $aCodec" -ForegroundColor White
        Write-Host "  - Sample Rate      : $aSampleRate Hz" -ForegroundColor White
        Write-Host "  - Audio Channels   : $aChannels channel(s)" -ForegroundColor White
    } else {
        Write-Host " [AUDIO STREAM]     : No Audio Stream Detected" -ForegroundColor DarkGray
    }
}

# 2. Main Selection Menu
Write-Host ""
Write-Host "Select Inspection Mode:" -ForegroundColor Cyan
Write-Host "1. Inspect Single File (Enter filename)" -ForegroundColor White
Write-Host "2. Inspect ALL Media Files in Working Directory ($global:WorkingDir)" -ForegroundColor White

$modeChoice = Read-Host "Enter choice (1-2, Default is 1)"

if ($modeChoice -eq "2") {
    # Scan all media files
    $mediaExtensions = "*.mp4", "*.mkv", "*.avi", "*.mov", "*.flv", "*.mp3", "*.wav", "*.m4a", "*.flac"
    $files = Get-ChildItem -Path $global:WorkingDir -Include $mediaExtensions -Recurse -ErrorAction SilentlyContinue

    if (-not $files -or $files.Count -eq 0) {
        Write-Host "[!] No media files found in $global:WorkingDir!" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "[+] Found $($files.Count) media file(s). Displaying information..." -ForegroundColor Green
    foreach ($file in $files) {
        Show-MediaDetail -filePath $file.FullName
    }
} else {
    # Inspect Single File
    Write-Host ""
    $inputName = Read-Host "Enter INPUT media file name (e.g., video.mp4)"
    $inputPath = Join-Path $global:WorkingDir $inputName

    if (Test-Path $inputPath) {
        Show-MediaDetail -filePath $inputPath
    } else {
        Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    }
}