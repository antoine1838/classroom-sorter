# Lance l'application "Plan de classe".
#   .\run.ps1            -> sur Windows (bureau)
#   .\run.ps1 edge       -> dans le navigateur Edge
#   .\run.ps1 <deviceId> -> sur un appareil précis (voir : flutter devices)
$dev = "C:\Users\antoine.barge\dev"
$env:JAVA_HOME = "$dev\jdk-17"
$env:ANDROID_HOME = "$dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:CHROME_EXECUTABLE = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$env:Path = "$dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
Set-Location "$dev\classroom_sort"
$device = if ($args.Count -ge 1) { $args[0] } else { 'windows' }
Write-Host "Lancement sur : $device" -ForegroundColor Cyan
flutter run -d $device
