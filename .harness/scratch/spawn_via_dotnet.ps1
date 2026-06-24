$ErrorActionPreference = "Stop"
$content = [System.IO.File]::ReadAllText($args[0], [System.Text.Encoding]::UTF8)

function Quote-Arg([string]$s) {
  return '"' + $s.Replace('"', '\"') + '"'
}

$argString = "communication send " +
  "--from " + (Quote-Arg "mvs_df89daf040574ffab753792bfa164050") + " " +
  "--to "   + (Quote-Arg "mvs_df89daf040574ffab753792bfa164050") + " " +
  "--command " + (Quote-Arg "spawn") + " " +
  "--content " + (Quote-Arg $content)

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\Users\Administrator\.mavis\bin\mavis.cmd"
$psi.Arguments = $argString
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi)
$out = $p.StandardOutput.ReadToEnd()
$err = $p.StandardError.ReadToEnd()
$p.WaitForExit()
Write-Host "=== STDOUT ==="
Write-Host $out
Write-Host "=== STDERR ==="
Write-Host $err
Write-Host "=== STATUS ==="
Write-Host $p.ExitCode