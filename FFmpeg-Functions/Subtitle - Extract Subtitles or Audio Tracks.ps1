# Module: Extract-Subtitles-Or-Audio-Tracks.ps1
# Author: Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved.
Set-Location $global:WorkingDir

Write-Host "========================================================================================================" -ForegroundColor Cyan
Write-Host "                               EXTRACT SUBTITLES & AUDIO TRACKS MODULE                                  " -ForegroundColor Cyan
Write-Host "  Copyright (c) 2026 Trung Nguyen (12345678+trungnguyen@users.noreply.github.com). All rights reserved. " -ForegroundColor DarkGray
Write-Host "                      Licensed under the GNU General Public License v3.0 (GPLv3).                       " -ForegroundColor DarkGray
Write-Host "========================================================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. GET INPUT FILE & SCAN STREAMS VIA FFPROBE
# ------------------------------------------------------------------------------
Write-Host ""
$inputName = Read-Host "Enter INPUT video file name (e.g., lecture.mkv, course.mp4)"
$inputPath = Join-Path $global:WorkingDir $inputName

if (-not (Test-Path $inputPath)) {
    Write-Host "[!] Error: File '$inputName' not found in $global:WorkingDir" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "[+] Scanning streams inside '$inputName'..." -ForegroundColor Yellow

# Query Subtitle Tracks
$subRaw = (ffprobe -v error -select_streams s -show_entries stream=index,codec_name:stream_tags=language,title -of csv=p=0 `"$inputPath`")
# Query Audio Tracks
$audioRaw = (ffprobe -v error -select_streams a -show_entries stream=index,codec_name:stream_tags=language,title -of csv=p=0 `"$inputPath`")

$subTracks = @()
if ($subRaw) {
    $lines = $subRaw -split "`n" | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) {
        $parts = $line -split ","
        $subTracks += [PSCustomObject]@{
            Index    = $parts[0].Trim()
            Codec    = $parts[1].Trim()
            Language = if ($parts.Count -gt 2 -and $parts[2]) { $parts[2].Trim() } else { "unk" }
            Title    = if ($parts.Count -gt 3 -and $parts[3]) { $parts[3].Trim() } else { "" }
        }
    }
}

$audioTracks = @()
if ($audioRaw) {
    $lines = $audioRaw -split "`n" | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) {
        $parts = $line -split ","
        $audioTracks += [PSCustomObject]@{
            Index    = $parts[0].Trim()
            Codec    = $parts[1].Trim()
            Language = if ($parts.Count -gt 2 -and $parts[2]) { $parts[2].Trim() } else { "unk" }
            Title    = if ($parts.Count -gt 3 -and $parts[3]) { $parts[3].Trim() } else { "" }
        }
    }
}

# ------------------------------------------------------------------------------
# 2. DISPLAY STREAM INFORMATION & TASK SELECTION
# ------------------------------------------------------------------------------
Write-Host "====================================================" -ForegroundColor DarkGray
Write-Host " DETECTED STREAMS IN FILE:" -ForegroundColor Yellow

Write-Host " [SUBTITLE TRACKS]:" -ForegroundColor Cyan
if ($subTracks.Count -gt 0) {
    for ($s = 0; $s -lt $subTracks.Count; $s++) {
        $st = $subTracks[$s]
        Write-Host "   Sub $($s + 1). [Stream #$($st.Index)] Lang: $($st.Language) | Codec: $($st.Codec) $($st.Title)" -ForegroundColor White
    }
} else {
    Write-Host "   (No embedded subtitle tracks found)" -ForegroundColor DarkGray
}

Write-Host " [AUDIO TRACKS]:" -ForegroundColor Cyan
if ($audioTracks.Count -gt 0) {
    for ($a = 0; $a -lt $audioTracks.Count; $a++) {
        $at = $audioTracks[$a]
        Write-Host "   Audio $($a + 1). [Stream #$($at.Index)] Lang: $($at.Language) | Codec: $($at.Codec) $($at.Title)" -ForegroundColor White
    }
} else {
    Write-Host "   (No audio tracks found)" -ForegroundColor DarkGray
}
Write-Host "====================================================" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Select Task to Perform:" -ForegroundColor Cyan
Write-Host "1. Extract Subtitle Track to .SRT File" -ForegroundColor White
Write-Host "2. Extract Audio Track to .MP3 File" -ForegroundColor White

$taskChoice = Read-Host "Enter choice (1-2, Default is 1)"

$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputName)

# ------------------------------------------------------------------------------
# 3. EXECUTE EXTRACTION
# ------------------------------------------------------------------------------
if ($taskChoice -eq "2") {
    # --- EXTRACT AUDIO TRACK ---
    if ($audioTracks.Count -eq 0) {
        Write-Host "[!] Error: No audio tracks available to extract!" -ForegroundColor Red
        return
    }

    $targetAudioIdx = 0
    if ($audioTracks.Count -gt 1) {
        $aSel = Read-Host "Select Audio Track number to extract (1-$($audioTracks.Count))"
        if ($aSel -match '^\d+$' -and [int]$aSel -gt 0 -and [int]$aSel -le $audioTracks.Count) {
            $targetAudioIdx = [int]$aSel - 1
        }
    }

    $selectedAudio = $audioTracks[$targetAudioIdx]
    $outputName = "${fileNameWithoutExt}_audio_$($selectedAudio.Language).mp3"
    $outputPath = Join-Path $global:WorkingDir $outputName

    Write-Host ""
    Write-Host "[+] Extracting Audio Stream #$($selectedAudio.Index) to MP3..." -ForegroundColor Green
    $ffmpegArgs = "-y -i `"$inputPath`" -map 0:$($selectedAudio.Index) -c:a libmp3lame -q:a 2 `"$outputPath`""
    
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "[V] AUDIO EXTRACTION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "  - File Path: $outputPath" -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Green
    } else {
        Write-Error "Audio extraction failed!"
    }

} else {
    # --- EXTRACT SUBTITLE TRACK ---
    if ($subTracks.Count -eq 0) {
        Write-Host "[!] Error: No embedded subtitle tracks found in this video!" -ForegroundColor Red
        return
    }

    $targetSubIdx = 0
    if ($subTracks.Count -gt 1) {
        $sSel = Read-Host "Select Subtitle Track number to extract (1-$($subTracks.Count))"
        if ($sSel -match '^\d+$' -and [int]$sSel -gt 0 -and [int]$sSel -le $subTracks.Count) {
            $targetSubIdx = [int]$sSel - 1
        }
    }

    $selectedSub = $subTracks[$targetSubIdx]
    $outputName = "${fileNameWithoutExt}_sub_$($selectedSub.Language).srt"
    $outputPath = Join-Path $global:WorkingDir $outputName

    Write-Host ""
    Write-Host "[+] Extracting Subtitle Stream #$($selectedSub.Index) to SubRip (.srt)..." -ForegroundColor Green
    $ffmpegArgs = "-y -i `"$inputPath`" -map 0:$($selectedSub.Index) -c:s srt `"$outputPath`""
    
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "[V] SUBTITLE EXTRACTION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
        Write-Host "  - Output Subtitle: $outputName" -ForegroundColor White
        Write-Host "  - File Path       : $outputPath" -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Green
    } else {
        Write-Error "Subtitle extraction failed!"
    }
}