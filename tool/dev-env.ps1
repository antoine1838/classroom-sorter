# Prépare l'environnement de développement (Java, SDK Android, Flutter) pour
# run.ps1 et emulateur.ps1. À charger avec : . "$PSScriptRoot\tool\dev-env.ps1"
#
# Si les dossiers voisins du dépôt existent (..\jdk-17, ..\android-sdk,
# ..\flutter), ils ont la priorité : c'est la disposition historique du projet.
# Sinon on garde JAVA_HOME, ANDROID_HOME (ou ANDROID_SDK_ROOT) et le PATH du
# système.
$devRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Find-Sibling([string]$name) {
    $path = Join-Path $devRoot $name
    if (Test-Path $path) { $path }
}

$jdk = Find-Sibling 'jdk-17'
if ($jdk) { $env:JAVA_HOME = $jdk }

$sdk = Find-Sibling 'android-sdk'
if ($sdk) {
    $env:ANDROID_HOME = $sdk
} elseif (-not $env:ANDROID_HOME -and $env:ANDROID_SDK_ROOT) {
    $env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
}
if ($env:ANDROID_HOME) { $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME }

$extraPaths = @()
$flutter = Find-Sibling 'flutter'
if ($flutter) { $extraPaths += "$flutter\bin" }
if ($env:JAVA_HOME) { $extraPaths += "$env:JAVA_HOME\bin" }
if ($env:ANDROID_HOME) {
    $extraPaths += "$env:ANDROID_HOME\cmdline-tools\latest\bin"
    $extraPaths += "$env:ANDROID_HOME\emulator"
    $extraPaths += "$env:ANDROID_HOME\platform-tools"
}
$extraPaths = @($extraPaths | Where-Object { Test-Path $_ })
if ($extraPaths.Count -gt 0) {
    $env:Path = ($extraPaths -join ';') + ';' + $env:Path
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # `throw` plutôt que `exit` : un `exit` dans un script chargé par « . »
    # n'arrête pas le script appelant.
    throw "Flutter est introuvable : ajoute-le au PATH, ou installe-le dans $devRoot\flutter."
}
