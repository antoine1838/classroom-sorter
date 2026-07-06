# Démarre le téléphone virtuel Android (Pixel_API36) puis lance l'app dessus.
# À utiliser APRÈS avoir redémarré Windows une première fois (activation WHPX).
$dev = (Split-Path -Parent $PSScriptRoot)
$env:JAVA_HOME = "$dev\jdk-17"
$env:ANDROID_HOME = "$dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools;$env:Path"
Set-Location "$dev\classroom_sort"

$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"

Write-Host "Démarrage de l'émulateur Pixel_API36..." -ForegroundColor Cyan
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList '-avd', 'Pixel_API36'

Write-Host "Attente de la connexion du téléphone virtuel..." -ForegroundColor Cyan
& $adb wait-for-device

Write-Host "Attente de la fin du démarrage d'Android..." -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 2
    $booted = (& $adb shell getprop sys.boot_completed 2>$null)
} until ($booted -match '1')

# Clavier : le clavier physique du PC est activé au niveau de l'AVD
# (hw.keyboard=yes dans config.ini) -> tape directement avec ton clavier une
# fois la fenêtre de l'émulateur au premier plan. Le clavier virtuel reste
# dispo en touchant un champ (ou via Alt+K).

Write-Host "Téléphone prêt ! Lancement de l'application..." -ForegroundColor Green
flutter run
