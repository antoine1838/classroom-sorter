# Lance l'application "Plan de classe".
#   .\run.ps1            -> sur Windows (bureau)
#   .\run.ps1 edge       -> dans le navigateur Edge
#   .\run.ps1 <deviceId> -> sur un appareil précis (voir : flutter devices)
. "$PSScriptRoot\tool\dev-env.ps1"
Set-Location $PSScriptRoot
if (-not $env:CHROME_EXECUTABLE) {
    $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $edge) { $env:CHROME_EXECUTABLE = $edge }
}
$device = if ($args.Count -ge 1) { $args[0] } else { 'windows' }
Write-Host "Lancement sur : $device" -ForegroundColor Cyan
flutter run -d $device
