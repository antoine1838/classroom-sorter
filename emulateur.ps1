# Démarre le téléphone virtuel Android (Pixel_API36) puis lance l'app dessus.
# À utiliser APRÈS avoir redémarré Windows une première fois (activation WHPX).
$dev = "C:\Users\antoine.barge\dev"
$env:JAVA_HOME = "$dev\jdk-17"
$env:ANDROID_HOME = "$dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools;$env:Path"
Set-Location "$dev\classroom_sort"

$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"

# Fenêtre de l'émulateur : forcer une échelle/position visibles.
# Sur l'écran principal (1536x960, mise à l'échelle Windows 125 %), l'échelle
# « auto » (window.scale = -1), que l'émulateur ré-enregistre à chaque
# fermeture, ouvre une fenêtre minuscule coincée dans un coin, impossible à
# déplacer. On corrige avant le lancement — uniquement si l'échelle est
# invalide, pour respecter un zoom manuel positif que tu aurais réglé toi-même.
$avdIni = "$env:USERPROFILE\.android\avd\Pixel_API36.avd\emulator-user.ini"
if (Test-Path $avdIni) {
    $ini = @(Get-Content $avdIni)
    $scaleLine = $ini | Where-Object { $_ -match '^\s*window\.scale\s*=' } | Select-Object -First 1
    if ((-not $scaleLine) -or ($scaleLine -match '=\s*-')) {
        Write-Host "Correction de la fenetre de l'emulateur (echelle auto invalide)..." -ForegroundColor Yellow
        $set = [ordered]@{ 'window.x' = '60'; 'window.y' = '40'; 'window.scale' = '0.320000' }
        foreach ($k in $set.Keys) {
            $esc = [regex]::Escape($k)
            if ($ini -match "^\s*$esc\s*=") {
                $ini = $ini -replace "^\s*$esc\s*=.*", "$k = $($set[$k])"
            } else {
                $ini += "$k = $($set[$k])"
            }
        }
        [IO.File]::WriteAllLines($avdIni, $ini, [Text.UTF8Encoding]::new($false))
    }
}

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
