# Fixtures

Données de test statiques, au format `ClassGroup.toJson()`.

## `demo_class_varied_35.json`

Classe de 35 élèves avec une répartition volontairement variée de tous les
critères (genre, niveau, énergie, taille, mauvaise vue, tirés indépendamment
les uns des autres — pas de corrélation entre eux), des prénoms/noms composés
(« Jean-Philippe », « Van der Berg »…) et quelques notes. Sert à exercer
l'affichage de la grille Élèves (colonnes, noms longs, notes) et le moteur
d'affectation avec un jeu de données réaliste et non dégénéré.

## `demo_class_6emeb.json`

La classe de démo « 6ème B » (20 élèves) utilisée pour les 5 captures Play
Store dans `store/play/screenshots/` : mêmes critères tirés indépendamment
(genre en tiers égaux), plus 4 règles couvrant les 4 types (place imposée,
doit être devant, séparer, rapprocher) et un plan déjà généré qui les
respecte toutes. Sert de référence si les captures doivent être reprises.

## Recharger une fixture dans les prefs Windows en local

(voir aussi la recette dans la mémoire de session `windows-prefs-storage`) :

1. Arrêter l'application (`Get-Process plandeclasse | Stop-Process -Force`).
2. Lire `%APPDATA%\Antoine1838\Plan de classe\shared_preferences.json`,
   parser la clé `flutter.plandeclasse_classes_v1` (une chaîne JSON), y
   ajouter le contenu de ce fichier comme élément du tableau de classes
   (sans écraser les classes existantes), réécrire en UTF-8 sans BOM.
3. Relancer l'application.

Utiliser **pwsh 7** (`pwsh.exe`), pas Windows PowerShell 5.1 (`powershell.exe`)
pour ce genre de manipulation : la 5.1 lit les scripts en ANSI par défaut et
corrompt les caractères accentués lors d'un aller-retour
`ConvertFrom-Json`/`ConvertTo-Json`.
