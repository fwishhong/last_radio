# tools/build_trailer.ps1
# Builds the 60-second Steam trailer from screenshots + BGM.
#
# Output:
#   build/trailer/trailer_60s_zh.mp4  (1280x720, H.264, 30fps, with BGM)
#   build/trailer/trailer_60s_en.mp4
#
# Pipeline (see docs/store/trailer_script.md for shot list):
#   1. For each shot: ffmpeg still image -> 5s MP4 with burned caption
#   2. Concatenate segments
#   3. Mux BGM with fade in/out
#   4. Output final mp4
#
# Requires:
#   - ffmpeg on PATH (download static build from https://www.gyan.dev/ffmpeg/builds/
#     or winget install Gyan.FFmpeg)
#   - screenshots/store/night_shift_*.png  (9 captures already in repo)
#   - assets/audio/music_night_early.mp3   (or fallback to silence)

[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$OutputDir = "build\trailer",
    [string]$FfmpegPath = "ffmpeg"
)

$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
Set-Location $RepoRoot

Write-Host "=== Last Radio v2 trailer build ===" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"
Write-Host "Output: $OutputDir"
Write-Host ""

# ---- Sanity -----------------------------------------------------------------

if (-not (Get-Command $FfmpegPath -ErrorAction SilentlyContinue)) {
    Write-Warning "ffmpeg not found at '$FfmpegPath'. Install from https://www.gyan.dev/ffmpeg/builds/ or via 'winget install Gyan.FFmpeg', then re-run."
    Write-Warning "Skipping trailer render. Other Steam store assets still ship without it."
    exit 0
}

$shotsDir = "screenshots\store"
if (-not (Test-Path $shotsDir)) {
    Write-Warning "Screenshots folder '$shotsDir' missing. Run 'tools/capture_night_shift_screens.gd' first."
    exit 0
}

$bgmPath = "assets\audio\music_night_early.mp3"
if (-not (Test-Path $bgmPath)) {
    Write-Warning "BGM '$bgmPath' missing. Trailer will render without music."
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$segDir = Join-Path $OutputDir "segments"
New-Item -ItemType Directory -Path $segDir -Force | Out-Null

# ---- Shot list (mirrors docs/store/trailer_script.md) -----------------------

$shots = @(
    @{ id = "01"; image = "night_shift_00_cover.png";          zh = "旧体育馆,十个夜晚"; en = "The old stadium. Ten nights."; dur = 4.5 }
    @{ id = "02"; image = "night_shift_01_start.png";          zh = "白天做选择";         en = "Spend the day choosing.";      dur = 4.5 }
    @{ id = "03"; image = "night_shift_13_day_upgrade_choices.png"; zh = "木板、零件、电池、药品"; en = "Planks. Parts. Batteries. Medicine."; dur = 4.5 }
    @{ id = "04"; image = "night_shift_03_double_window.png";  zh = "夜晚,你亲自上场";   en = "At night, you hold the line."; dur = 4.5 }
    @{ id = "05"; image = "night_shift_07_back_door.png";      zh = "门窗、电力、避难者"; en = "Doors. Power. Survivors.";    dur = 4.5 }
    @{ id = "06"; image = "night_shift_06_antenna.png";        zh = "天线架起来,Elias 才清晰"; en = "Raise the antenna. Elias comes in clear."; dur = 4.5 }
    @{ id = "07"; image = "night_shift_08_final_wave.png";     zh = "第十夜,最后的冲击"; en = "Night ten. The last wave.";   dur = 4.5 }
    @{ id = "08"; image = "night_shift_09_success.png";        zh = "守住了";             en = "You held.";                   dur = 4.5 }
    @{ id = "09"; image = "night_shift_10_failure.png";        zh = "失守,也会有报告";   en = "A lost night still gets a report."; dur = 4.5 }
    @{ id = "10"; image = "night_shift_11_medbay_treating.png"; zh = "Nora 和 Elias 会累,会犯错"; en = "Nora and Elias tire. They miss."; dur = 4.5 }
    @{ id = "11"; image = "night_shift_05_medbay.png";         zh = "信任、暴露、资源,三个数字"; en = "Trust. Exposure. Stores. Three numbers."; dur = 5.0 }
    @{ id = "12"; image = "night_shift_17_final.png";          zh = "第一章,十夜";       en = "Chapter one. Ten nights.";    dur = 4.0 }
    @{ id = "13"; image = "night_shift_00_cover.png";          zh = "末日电台:旧体育馆守夜"; en = "Last Radio: Old Stadium Watch"; dur = 4.0 }
    @{ id = "14"; image = "night_shift_00_cover.png";          zh = "";                    en = "";                            dur = 1.5 }
)

# ---- Render per-locale --------------------------------------------------------

foreach ($locale in @("zh", "en")) {
    Write-Host ""
    Write-Host "--- Locale: $locale ---" -ForegroundColor Yellow
    $localeSegDir = Join-Path $segDir $locale
    New-Item -ItemType Directory -Path $localeSegDir -Force | Out-Null

    $segFiles = @()
    foreach ($s in $shots) {
        $segPath = Join-Path $localeSegDir "seg_$($s.id).mp4"
        $imgPath = Join-Path $shotsDir $s.image
        $caption = if ($locale -eq "zh") { $s.zh } else { $s.en }

        if (-not (Test-Path $imgPath)) {
            Write-Warning "  Missing shot $($s.id): $imgPath — skipping"
            continue
        }

        if ($caption -eq "") {
            # Black tail card
            & $FfmpegPath -y -f lavfi -i "color=black:s=1280x720:d=$($s.dur):r=30" `
                -c:v libx264 -pix_fmt yuv420p -r 30 $segPath 2>&1 | Out-Null
        } else {
            # Escape single quotes / colons for drawtext
            $captionSafe = $caption -replace ":", "\\:" -replace "'", "\\'"
            & $FfmpegPath -y -loop 1 -framerate 30 -t $s.dur -i $imgPath `
                -vf "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,`drawtext=text='$captionSafe':fontcolor=white:fontsize=46:box=1:boxcolor=black@0.55:boxborderw=18:x=(w-text_w)/2:y=h-90" `
                -c:v libx264 -pix_fmt yuv420p -r 30 $segPath 2>&1 | Out-Null
        }
        if (Test-Path $segPath) {
            Write-Host "  shot $($s.id) ($($s.dur)s): OK"
            $segFiles += $segPath
        } else {
            Write-Warning "  shot $($s.id) FAILED"
        }
    }

    # Concat segments
    $concatList = Join-Path $OutputDir "concat_$locale.txt"
    $segFiles | ForEach-Object { "file '$($_ -replace '\\', '/')'" } | Set-Content -Path $concatList -Encoding UTF8
    $outVideo = Join-Path $OutputDir "trailer_60s_$locale.mp4"
    & $FfmpegPath -y -f concat -safe 0 -i $concatList -c copy $outVideo 2>&1 | Out-Null

    # Mux BGM with fade
    if (Test-Path $bgmPath) {
        $tmpOut = Join-Path $OutputDir "trailer_60s_${locale}_nomux.mp4"
        Move-Item $outVideo $tmpOut -Force
        & $FfmpegPath -y -i $tmpOut -i $bgmPath -filter_complex "[1:a]afade=t=in:st=0:d=3,afade=t=out:st=55:d=4.5[aout];[0:a]anullsrc=channel_layout=stereo:sample_rate=44100[a0];[a0][aout]amix=inputs=2:duration=first[a]" `
            -map 0:v -map "[a]" -c:v copy -c:a aac -shortest $outVideo 2>&1 | Out-Null
        Remove-Item $tmpOut -ErrorAction SilentlyContinue
    }

    if (Test-Path $outVideo) {
        $size = (Get-Item $outVideo).Length
        Write-Host ""
        Write-Host "  Output: $outVideo ($('{0:N1}' -f ($size / 1MB)) MB)" -ForegroundColor Green
    } else {
        Write-Warning "  Trailer build failed for locale $locale"
    }
}

Write-Host ""
Write-Host "=== Trailer build complete ===" -ForegroundColor Cyan
