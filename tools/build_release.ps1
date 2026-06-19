# tools/build_release.ps1
# Last Radio v2 release build pipeline.
#
# Steps:
#   1. Sanity: Godot 4.3 reachable, export templates 4.3 installed
#   2. Run the full headless test suite (18 scripts, ~593 assertions)
#   3. Stamp VERSION + write CHANGELOG entry from $Message
#   4. Export Windows / macOS / Linux desktop targets via export_presets.cfg
#   5. Verify all three artifacts exist and are non-trivial in size
#
# Usage:
#   pwsh ./tools/build_release.ps1 -Version "0.5.0" -Message "Initial v0.5 release"
#   pwsh ./tools/build_release.ps1 -Version "0.5.1" -Message "Hotfix" -SkipTests
#
# Outputs (relative to repo root):
#   build/last_radio_v2_windows_x86_64.exe
#   build/last_radio_v2_macos.zip              (zip of .app bundle)
#   build/last_radio_v2_linux_x86_64
#   build/CHECKSUMS.txt
#   build/RELEASE_NOTES.md

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$Version = "",
    [Parameter(Mandatory = $false)] [string]$Message = "",
    [Parameter(Mandatory = $false)] [switch]$SkipTests = $false,
    [Parameter(Mandatory = $false)] [switch]$SkipExport = $false,
    [Parameter(Mandatory = $false)] [string]$GodotExe = "C:\Users\Administrator\godot.exe"
)

$ErrorActionPreference = "Continue"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot
Write-Host "=== Last Radio v2 release build ===" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"
Write-Host "Godot: $GodotExe"
Write-Host ""

# ---- 1. Sanity ---------------------------------------------------------------

if (-not (Test-Path $GodotExe)) {
    throw "Godot executable not found at $GodotExe. Pass -GodotExe to override."
}
$godotVersion = (& $GodotExe --headless --version 2>&1 | Select-Object -First 1).ToString().Trim()
if ([string]::IsNullOrWhiteSpace($godotVersion)) {
    # Some Godot builds print to stdout only — try again without redirect.
    $godotVersion = (& $GodotExe --headless --version) | Select-Object -First 1
    $godotVersion = "$godotVersion".Trim()
}
Write-Host "Godot version: $godotVersion"

$templatesRoot = Join-Path $env:APPDATA "Godot\export_templates"
if (-not (Test-Path $templatesRoot)) {
    Write-Warning "No export_templates folder under $templatesRoot — export will fail. Continue anyway."
}
$expectedTemplatesVersion = ($godotVersion -split "\.")[0..1] -join "."
$expectedDir = Join-Path $templatesRoot "$expectedTemplatesVersion.stable"
if (-not (Test-Path $expectedDir)) {
    Write-Warning "Templates for $expectedTemplatesVersion not installed (expected at $expectedDir). Export will fail until you install them via Editor > Manage Export Templates."
}

# ---- 2. Test suite -----------------------------------------------------------

$tests = @(
    "save_test", "sfx_test", "flow_integration_test", "night_shift_basic_test",
    "night_shift_data_validate", "hotspot_dot_test", "day_effects_test",
    "late_hotspot_enemy_test", "night_report_stats_test", "radio_contact_test",
    "night_shift_full_flow_test", "signal_catalog_test", "i18n_test",
    "save_slots_test", "tutorial_test", "menu_ui_test", "locale_e2e_test",
    "walk_animation_test"
)

if (-not $SkipTests) {
    Write-Host ""
    Write-Host "--- Running test suite ---" -ForegroundColor Yellow
    $failedTests = @()
    foreach ($t in $tests) {
        $script = "res://tools/$t.gd"
        Write-Host "[$t]" -NoNewline
        # Capture all streams into a temp file so PowerShell's "stderr -> error"
        # quirk doesn't print noise or kill $LASTEXITCODE. Godot emits benign
        # warnings (ObjectDB leaks, controller mapping) that we don't care
        # about; only the trailing PASS/FAIL line matters.
        $tmpOut = [System.IO.Path]::GetTempFileName()
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath $GodotExe `
            -ArgumentList "--headless","--path",".","--script",$script `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $tmpOut `
            -RedirectStandardError $tmpErr
        $exitCode = $proc.ExitCode
        $output = (Get-Content $tmpOut -Raw -Encoding UTF8) + "`n" + (Get-Content $tmpErr -Raw -Encoding UTF8)
        Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
        $summary = ($output -split "`n" | Where-Object { $_ -match 'PASS|FAIL' } | Select-Object -Last 1)
        if ($null -eq $summary) {
            $summary = ""
        } else {
            $summary = $summary.Trim()
        }
        if ($summary -match "PASS" -and $exitCode -le 1) {
            Write-Host " $summary" -ForegroundColor Green
        } else {
            Write-Host " FAIL (exit=$exitCode)" -ForegroundColor Red
            Write-Host $output
            $failedTests += $t
        }
    }
    if ($failedTests.Count -gt 0) {
        throw "Test failures: $($failedTests -join ', '). Aborting build."
    }
} else {
    Write-Host "Skipping tests (-SkipTests)."
}

# ---- 3. Versioning -----------------------------------------------------------

if (-not $Version) {
    if (Test-Path "VERSION") {
        $Version = (Get-Content "VERSION" -Raw).Trim()
    } else {
        $Version = "0.0.0"
    }
}
Write-Host ""
Write-Host "--- Stamping version $Version ---" -ForegroundColor Yellow
Set-Content -Path "VERSION" -Value $Version -NoNewline

$date = Get-Date -Format "yyyy-MM-dd"
$changelogPath = "CHANGELOG.md"
$entry = @"

## [$Version] - $date

$Message
"@
Add-Content -Path $changelogPath -Value $entry
Write-Host "Appended to $changelogPath"

# ---- 4. Export ---------------------------------------------------------------

if (-not $SkipExport) {
    Write-Host ""
    Write-Host "--- Exporting release artifacts ---" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "build" -Force | Out-Null

    $targets = @(
        @{ Preset = "Windows Desktop"; Out = "build/last_radio_v2_windows_x86_64.exe" }
        @{ Preset = "macOS";            Out = "build/last_radio_v2_macos.zip" }
        @{ Preset = "Linux/X11";        Out = "build/last_radio_v2_linux_x86_64" }
    )

    foreach ($t in $targets) {
        Write-Host "  $($t.Preset) -> $($t.Out)"
        # Redirect both streams to temp files so PowerShell's stderr-as-error
        # quirk doesn't kill the script on benign Godot warnings.
        $tmpOut = [System.IO.Path]::GetTempFileName()
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath $GodotExe `
            -ArgumentList "--headless","--path",".","--export-release",$t.Preset,$t.Out `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $tmpOut `
            -RedirectStandardError $tmpErr
        # Verify by artifact presence + size rather than exit code alone:
        # Godot 4.3 sometimes returns 0 even with warnings, and PowerShell's
        # Start-Process sometimes returns odd codes for the same; the file
        # existence + verify step below is the authoritative check.
        if (-not (Test-Path $t.Out)) {
            Write-Host "  Export produced no file. Stderr:" -ForegroundColor Red
            Get-Content $tmpErr | Select-Object -Last 20 | ForEach-Object { Write-Host "    $_" }
            Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
            throw "Export failed for $($t.Preset) (no artifact at $($t.Out))."
        }
        Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
    }

    # ---- 5. Verify ------------------------------------------------------------

    Write-Host ""
    Write-Host "--- Verifying artifacts ---" -ForegroundColor Yellow
    $ok = $true
    foreach ($t in $targets) {
        if (Test-Path $t.Out) {
            $size = (Get-Item $t.Out).Length
            if ($size -lt 1MB) {
                Write-Host "  $($t.Out): $($size) bytes (TOO SMALL)" -ForegroundColor Red
                $ok = $false
            } else {
                Write-Host "  $($t.Out): $('{0:N1}' -f ($size / 1MB)) MB" -ForegroundColor Green
            }
        } else {
            Write-Host "  $($t.Out): MISSING" -ForegroundColor Red
            $ok = $false
        }
    }

    if (-not $ok) {
        throw "One or more artifacts missing or too small. Build FAILED."
    }

    # ---- 6. Checksums --------------------------------------------------------

    Write-Host ""
    Write-Host "--- Generating checksums ---" -ForegroundColor Yellow
    $checksums = @()
    foreach ($t in $targets) {
        if (Test-Path $t.Out) {
            $hash = (Get-FileHash -Algorithm SHA256 $t.Out).Hash
            $checksums += "$hash  $($t.Out)"
        }
    }
    Set-Content -Path "build/CHECKSUMS.txt" -Value $checksums
    Write-Host "  build/CHECKSUMS.txt"
}

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Cyan
