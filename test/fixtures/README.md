# Fixtures

Données de test statiques, au format `ClassGroup.toJson()`.

## `demo_class_varied_35.json`

Classe de 35 élèves avec une répartition volontairement variée de tous les
critères (genre, niveau, énergie, taille, mauvaise vue, tirés indépendamment
les uns des autres — pas de corrélation entre eux), des prénoms/noms composés
(« Jean-Philippe », « Van der Berg »…) et quelques notes. Sert à exercer
l'affichage de la grille Élèves (colonnes, noms longs, notes) et le moteur
d'affectation avec un jeu de données réaliste et non dégénéré.

Pour la recharger dans les prefs Windows en local (voir aussi la recette dans
la mémoire de session `windows-prefs-storage`) :

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
