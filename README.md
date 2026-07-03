# Plan de classe

Application mobile (Android / iPhone) et de bureau pour **affecter des élèves à
des places** dans une salle de classe selon différents critères.

Construite avec **Flutter** (un seul code pour Android, iOS, Web, Windows).
Données **stockées localement** sur l'appareil (hors-ligne, aucune donnée envoyée
sur Internet — adapté aux données élèves).

## Fonctionnalités

- **Salle** : grille de places modifiable ; on peut retirer des cases pour
  dessiner les allées. Le rang 0 est « devant » (tableau).
- **Élèves** : ajout un par un ou import d'une liste ; genre, niveau, notes.
- **Règles** :
  - *Place imposée* — un élève sur une place précise ;
  - *Doit être devant* — dans les N premiers rangs (vue, audition, PMR…) ;
  - *Séparer* — deux élèves jamais côte à côte ;
  - *Rapprocher* — deux élèves côte à côte ;
  - Objectifs souples : mixer filles/garçons, mélanger les niveaux.
  - Chaque règle est *obligatoire* (dure) ou *préférence* (souple).
- **Plan** : génération automatique, rapport des contraintes respectées /
  violées, et **glisser-déposer** pour ajuster à la main. Bouton *Régénérer*
  pour une autre proposition.

## Comment ça marche (le moteur)

L'affectation est un problème d'optimisation sous contraintes. Le moteur
(`lib/engine/seating_engine.dart`) utilise un **recuit simulé** avec
redémarrages : il minimise un coût où les contraintes dures coûtent très cher
et les préférences peu, puis renvoie le meilleur plan trouvé.

## Lancer l'application

Depuis un terminal PowerShell, à la racine du projet :

```powershell
# Sur le PC (le plus simple, aucune config)
.\run.ps1               # équivaut à : flutter run -d windows

# Dans le navigateur Edge
.\run.ps1 edge

# Sur un téléphone Android branché en USB (mode développeur activé)
.\run.ps1 <id-du-téléphone>   # voir « flutter devices »
```

Générer un APK installable sur Android :

```powershell
flutter build apk            # APK de production -> build\app\outputs\flutter-apk\
```

> Émulateur Android : indisponible pour l'instant (la virtualisation *Windows
> Hypervisor Platform* n'est pas activée sur cette machine — nécessite l'IT /
> les droits admin). En attendant : Windows, Edge, ou un téléphone en USB.

## Structure du code

```
lib/
├── models/        Student, Room/Seat, Rule, ClassGroup   (+ (dé)sérialisation JSON)
├── engine/        seating_engine.dart — moteur d'affectation
├── data/          repository.dart — stockage local (shared_preferences)
├── screens/       home_screen, class_editor_screen (4 onglets)
├── widgets/       seat_grid.dart — grilles (édition + drag & drop)
├── app_state.dart État global (ChangeNotifier) + persistance
└── main.dart

test/              engine_test.dart, widget_test.dart
```

## Idées d'améliorations

- Glisser un élève « non placé » directement sur une place libre.
- Plusieurs salles / plans par classe (matin, après-midi…).
- Export / impression du plan (PDF) et partage.
- Réglage de l'intensité des préférences (pondération).
- Sauvegarde/restauration (export d'un fichier de classe).
