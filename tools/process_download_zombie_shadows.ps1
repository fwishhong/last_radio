Add-Type -AssemblyName System.Drawing

$downloads = Join-Path $env:USERPROFILE "Downloads"
$outDir = Join-Path (Get-Location) "assets\final\night_shift"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sources = Get-ChildItem -LiteralPath $downloads -File |
    Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 4 |
    Sort-Object LastWriteTime

if ($sources.Count -lt 4) {
    throw "Need four recent image files in Downloads."
}

function Convert-Asset {
    param(
        [string]$Source,
        [string]$Output,
        [int]$Pad = 28
    )

    $src = [System.Drawing.Bitmap]::FromFile($Source)
    try {
        $width = $src.Width
        $height = $src.Height
        $minX = $width
        $minY = $height
        $maxX = -1
        $maxY = -1
        $mask = New-Object 'bool[,]' $width, $height

        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $c = $src.GetPixel($x, $y)
                $brightNeutral = $c.R -gt 214 -and $c.G -gt 214 -and $c.B -gt 214 -and [Math]::Abs($c.R - $c.G) -lt 18 -and [Math]::Abs($c.G - $c.B) -lt 18
                $visible = $c.A -gt 8 -and -not $brightNeutral
                if ($visible) {
                    $mask[$x, $y] = $true
                    if ($x -lt $minX) { $minX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }

        if ($maxX -lt $minX -or $maxY -lt $minY) {
            throw "No visible subject found in $Source"
        }

        $cropW = $maxX - $minX + 1
        $cropH = $maxY - $minY + 1
        $crop = New-Object System.Drawing.Bitmap $cropW, $cropH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for ($y = 0; $y -lt $cropH; $y++) {
                for ($x = 0; $x -lt $cropW; $x++) {
                    $sx = $minX + $x
                    $sy = $minY + $y
                    if ($mask[$sx, $sy]) {
                        $c = $src.GetPixel($sx, $sy)
                        $crop.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
                    } else {
                        $crop.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                    }
                }
            }

            $canvasSize = 512
            $target = $canvasSize - $Pad * 2
            $scale = [Math]::Min($target / $cropW, $target / $cropH)
            $drawW = [Math]::Max(1, [int][Math]::Round($cropW * $scale))
            $drawH = [Math]::Max(1, [int][Math]::Round($cropH * $scale))
            $destX = [int](($canvasSize - $drawW) / 2)
            $destY = [int](($canvasSize - $drawH) / 2)
            $out = New-Object System.Drawing.Bitmap $canvasSize, $canvasSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $g = [System.Drawing.Graphics]::FromImage($out)
                try {
                    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.DrawImage($crop, $destX, $destY, $drawW, $drawH)
                } finally {
                    $g.Dispose()
                }
                $out.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $out.Dispose()
            }
        } finally {
            $crop.Dispose()
        }
    } finally {
        $src.Dispose()
    }
}

$names = @(
    "zombie_shadow_single.png",
    "zombie_shadow_pair.png",
    "zombie_shadow_crowd.png",
    "zombie_hands_reach.png"
)
$pads = @(28, 28, 8, 6)

for ($i = 0; $i -lt 4; $i++) {
    $output = Join-Path $outDir $names[$i]
    Convert-Asset -Source $sources[$i].FullName -Output $output -Pad $pads[$i]
    Write-Output "wrote $output"
}

Write-Output "sources:"
foreach ($source in $sources) {
    Write-Output "- $($source.FullName)"
}
