# Plan de classe

Application mobile (Android / iPhone) et de bureau pour **affecter des élèves à
des places** dans une salle de classe selon différents critères.

Construite avec **Flutter** (un seul code pour Android, iOS, Web, Windows).
Données **stockées localement** sur l'appareil (hors-ligne, aucune donnée envoyée
sur Internet — adapté aux données élèves).

## Fonctionnalités

- **Salle** : grille de places modifiable ; on peut retirer des cases pour
  dessiner les allées. Le rang 0 est le « devant » (côté tableau), **affiché en
  bas** de la grille (vue du professeur).
- **Élèves** : ajout un par un ou import d'une liste ; genre, niveau
  (faible/moyen/fort), énergie (calme/agité), mauvaise vue, notes libres.
- **Règles** (par élève ou par binôme) — chacune *obligatoire* (dure) ou
  *préférence* (souple) :
  - *Place imposée* — un élève sur une place précise ;
  - *Doit être devant* — dans les N premiers rangs (vue, audition, PMR…) ;
  - *Séparer* — deux élèves jamais côte à côte ;
  - *Rapprocher* — deux élèves côte à côte.
- **Objectifs d'équilibre** (souples, appliqués à toute la classe) :
  - *Mélanger les genres* — éviter les voisins de même genre ;
  - *Mélanger les niveaux* — éviter les voisins de même niveau ;
  - *Séparer les élèves agités* — éviter deux agités côte à côte ;
  - *Mauvaise vue* — rapprocher du tableau (moitié avant) les élèves concernés.
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

## Icônes & ressources de store

Les icônes sont générées depuis `assets/icon/icon.png` (+ `icon_foreground.png`
pour le calque adaptatif Android) via **flutter_launcher_icons** :

```powershell
dart run flutter_launcher_icons   # régénère Android + iOS
```

La configuration (`pubspec.yaml`) ne cible qu'Android et iOS. Les icônes **Web**
(`web/icons/`, `web/favicon.png`) et **Windows**
(`windows/runner/resources/app_icon.ico`) sont régénérées séparément.

L'icône représente la salle vue du professeur : les pupitres (élèves face au
tableau) au-dessus de la barre « tableau », en bas — cohérent avec l'écran Salle.

Les ressources de la fiche **Google Play** (icône 512×512, bandeau 1024×500,
captures d'écran, descriptions fr-FR, politique de confidentialité) sont
regroupées dans **`store/play/`** — voir [store/play/README.md](store/play/README.md).

Sur un tag `vX.Y.Z`, le CI ([.github/workflows/build-apk.yml](.github/workflows/build-apk.yml))
construit l'**APK** (installable directement) et l'**AAB signé** (tous les ABI, à
téléverser sur Google Play), et les joint à la Release GitHub.

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

test/              engine_test, seating_neighbors_test, room_orientation_test,
                   layout_responsive_test, widget_test
```

## Idées d'améliorations

- Glisser un élève « non placé » directement sur une place libre.
- Plusieurs salles / plans par classe (matin, après-midi…).
- Export / impression du plan (PDF) et partage.
- Réglage de l'intensité des préférences (pondération).
- Sauvegarde/restauration (export d'un fichier de classe).
