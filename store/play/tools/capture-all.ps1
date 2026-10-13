param([string]$Locale, [string]$OutDir)
$cap = Join-Path $PSScriptRoot 'capture.ps1'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
& $cap -ShotTab home -Locale $Locale -OutFile "$OutDir\01-accueil.png"
& $cap -ShotTab 0 -ShotLayout ilots -Locale $Locale -OutFile "$OutDir\02-salle.png"
& $cap -ShotTab 1 -ShotView compact -Locale $Locale -OutFile "$OutDir\03-eleves-compacte.png"
& $cap -ShotTab 1 -ShotView complete -Locale $Locale -OutFile "$OutDir\04-eleves-complete.png"
& $cap -ShotTab 2 -Locale $Locale -OutFile "$OutDir\05-regles.png"
& $cap -ShotTab 3 -ForceViolation -Locale $Locale -OutFile "$OutDir\06-plan.png"
& $cap -ShotTab 3 -ForceViolation -OpenSeat s01 -Locale $Locale -OutFile "$OutDir\07-plan-detail.png"
& $cap -ShotTab 3 -ForceViolation -Width 1920 -Height 1080 -Locale $Locale -OutFile "$OutDir\08-plan-paysage.png"
