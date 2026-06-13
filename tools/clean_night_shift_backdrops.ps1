Add-Type -AssemblyName System.Drawing

$root = Get-Location
$assetDir = Join-Path $root "assets\final\night_shift"

$names = @(
    "stadium_room_topdown",
    "stadium_room_day",
    "stadium_room_breached",
    "day_planning_table",
    "night_report_clipboard",
    "ending_stadium_dawn",
    "ending_breach_night"
)

foreach ($name in $names) {
    $source = Join-Path $assetDir "$name.png"
    $output = Join-Path $assetDir "$($name)_clean.png"
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing source image: $source"
    }
    $src = [System.Drawing.Bitmap]::FromFile($source)
    try {
        $clean = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $g = [System.Drawing.Graphics]::FromImage($clean)
            try {
                $g.Clear([System.Drawing.Color]::FromArgb(255, 0, 0, 0))
                $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
            } finally {
                $g.Dispose()
            }
            $clean.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output "wrote $output"
        } finally {
            $clean.Dispose()
        }
    } finally {
        $src.Dispose()
    }
}
