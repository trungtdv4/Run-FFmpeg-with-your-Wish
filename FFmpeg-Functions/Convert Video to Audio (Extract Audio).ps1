# Module: Convert-Video-To-Audio.ps1
Set-Location $global:WorkingDir

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "             CONVERT VIDEO TO AUDIO                 " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Get Input Media File
$inputName = Read-Host "Enter INPUT video file name (e.g., input.mp4)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

# 2. Select Output Audio Format
Write-Host ""
Write-Host "Select Target Audio Format:" -ForegroundColor Cyan
Write-Host "1. MP3  (High Compatibility - Default)" -ForegroundColor White
Write-Host "2. AAC  (Advanced Audio Coding)" -ForegroundColor White
Write-Host "3. WAV  (Uncompressed Lossless Audio)" -ForegroundColor White
Write-Host "4. FLAC (Compressed Lossless Audio)" -ForegroundColor White
Write-Host "5. COPY (Extract original stream without re-encoding - Fastest)" -ForegroundColor White

$formatChoice = Read-Host "Enter format choice (1-5, Default is 1)"

$audioCodec = ""
$extension = ""

switch ($formatChoice) {
    "2" { $audioCodec = "aac"; $extension = "m4a" }
    "3" { $audioCodec = "pcm_s16le"; $extension = "wav" }
    "4" { $audioCodec = "flac"; $extension = "flac" }
    "5" { $audioCodec = "copy"; $extension = "m4a" }
    Default { $audioCodec = "libmp3lame"; $extension = "mp3" }
}

# Special check if COPY mode is selected: detect extension or fallback
if ($audioCodec -eq "copy") {
    Write-Host "[i] Extracting original audio stream (No quality loss)..." -ForegroundColor Yellow
} else {
    Write-Host "[i] Re-encoding audio using codec: $audioCodec" -ForegroundColor Yellow
}

# 3. Construct Output Path
$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
$outputName = "${fileNameWithoutExt}-OUTPUT.${extension}"
$outputPath = Join-Path $global:WorkingDir $outputName

# 4. Execute FFmpeg
Write-Host ""
Write-Host "Processing: $inputName -> $outputName ..." -ForegroundColor Green

$ffmpegArgs = "-y -i `"$inputPath`" -vn -c:a $audioCodec `"$outputPath`""
$process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

# 5. Output Check
if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
    Write-Host ""
    Write-Host "[V] Audio extraction completed successfully!" -ForegroundColor Green
    Write-Host "    Output file saved at: $outputPath" -ForegroundColor White
} else {
    Write-Host ""
    Write-Error "An error occurred during audio extraction!"
}