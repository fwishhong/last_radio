# tools/build_capsules.ps1
# Builds Steam capsule images from icon.png (and optional fallback art).
#
# Output (under build/store_capsules/):
#   header_capsule.png     460 x 215
#   main_capsule.png       616 x 353
#   small_capsule.png      230 x 307
#   library_hero.png       3840 x 1240
#   library_logo.png       1280 x 720  (alpha preserved)
#
# Uses System.Drawing (GDI+) — no ImageMagick required.
# Sizes match docs/store/capsule_specs.md.

[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$OutputDir = "build\store_capsules"
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
Set-Location $RepoRoot

Add-Type -AssemblyName System.Drawing

Write-Host "=== Last Radio v2 capsule build ===" -ForegroundColor Cyan

$srcIcon = "icon.png"
$srcSplash = "default_splash.png"
if (-not (Test-Path $srcIcon)) {
    throw "Source icon '$srcIcon' not found."
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function Resize-FillBlack {
    param(
        [System.Drawing.Image]$Source,
        [int]$TargetW,
        [int]$TargetH
    )
    # Letterbox-scale: fit source inside target, fill bars with bg-deep (#101418).
    $bmp = New-Object System.Drawing.Bitmap $TargetW, $TargetH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([System.Drawing.Color]::FromArgb(16, 20, 24))  # bg-deep

        # Compute fit size preserving aspect ratio
        $srcW = $Source.Width
        $srcH = $Source.Height
        $ratio = [Math]::Min([double]$TargetW / $srcW, [double]$TargetH / $srcH)
        $drawW = [int]([Math]::Floor($srcW * $ratio))
        $drawH = [int]([Math]::Floor($srcH * $ratio))
        $x = [int](($TargetW - $drawW) / 2)
        $y = [int](($TargetH - $drawH) / 2)

        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.DrawImage($Source, $x, $y, $drawW, $drawH)
    } finally {
        $g.Dispose()
    }
    return $bmp
}

function Build-Capsule {
    param(
        [string]$Source,
        [int]$W,
        [int]$H,
        [string]$Out,
        [bool]$PreserveAlpha = $false
    )
    if (-not (Test-Path $Source)) {
        Write-Warning "  Skip $Out (no source $Source)"
        return
    }
    $img = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
    try {
        $bmp = Resize-FillBlack -Source $img -TargetW $W -TargetH $H
        try {
            $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $bmp.Dispose()
        }
        $size = (Get-Item $Out).Length
        Write-Host ("  {0,-22} {1}x{2,-5} ({3,6:N0} bytes)" -f (Split-Path $Out -Leaf), $W, $H, $size)
    } finally {
        $img.Dispose()
    }
}

Write-Host ""
Write-Host "--- Capsules from icon ---" -ForegroundColor Yellow
Build-Capsule -Source $srcIcon   -W 460  -H 215  -Out "$OutputDir\header_capsule.png"
Build-Capsule -Source $srcIcon   -W 616  -H 353  -Out "$OutputDir\main_capsule.png"
Build-Capsule -Source $srcIcon   -W 230  -H 307  -Out "$OutputDir\small_capsule.png"
Build-Capsule -Source $srcSplash -W 3840 -H 1240 -Out "$OutputDir\library_hero.png"
Build-Capsule -Source $srcIcon   -W 1280 -H 720  -Out "$OutputDir\library_logo.png"

Write-Host ""
Write-Host "=== Capsule build complete ===" -ForegroundColor Cyan
Write-Host "Output: $OutputDir"
