# Plan de classe

Application mobile (Android / iPhone) et de bureau pour **affecter des élèves à
des places** dans une salle de classe selon différents critères.

Construite avec **Flutter** (un seul code pour Android, iOS, Web, Windows).
Interface en **français et en anglais** (langue du système, ou choix dans les
réglages). Données **stockées localement** sur l'appareil (hors-ligne, aucune donnée envoyée
sur Internet — adapté aux données élèves). Les écritures sont sérialisées et
une copie locale de la dernière sauvegarde valide permet une restauration
automatique si les données principales deviennent illisibles ; l'application
prévient alors explicitement l'utilisateur. Sur Android, ce stockage — copie de
secours comprise — est exclu des sauvegardes cloud et des transferts
automatiques vers un autre appareil.

## Fonctionnalités

- **Salle** : grille de places modifiable. Le rang 0 est le « devant » (côté
  tableau), **affiché en bas** de la grille (vue du professeur). Sur une case
  vide, toucher pose une place ; sur une place, toucher la fait **tourner**
  (nord/est/sud/ouest — l'orientation est purement visuelle, elle n'influence
  pas les plans générés) et l'**appui long** (ou le clic droit) la retire.
  Toucher l'espace entre deux cases ajoute un **couloir**, horizontal ou
  vertical : les élèves de part et d'autre ne sont plus voisins. Un bouton
  **Disposition** propose trois modèles prêts à composer — *Rangées*, *U*
  (profondeur et largeur des bras réglables) et *Îlots* (tables de 4 ou 6,
  sur un ou plusieurs rangs) — ou une page blanche, à retoucher ensuite case
  par case. Un bandeau prévient (sans bloquer) quand la salle manque de
  places pour l'effectif de la classe. Le bouton **Enregistrer la salle**
  garde la disposition actuelle sous un nom (« B204 »…) pour la réutiliser
  dans d'autres classes via **Mes salles**, dans ce même sélecteur ; une
  classe issue d'une salle enregistrée peut la mettre à jour en un geste. Ce
  sélecteur s'ouvre aussi juste après avoir nommé une nouvelle classe, pour
  choisir sa disposition dès la création plutôt que de la découvrir plus
  tard dans l'onglet Salle.
- **Élèves** : ajout un par un ou import d'une liste ; genre, niveau
  (faible/moyen/fort), énergie (calme/modéré/agité), taille
  (petit/moyen/grand), mauvaise vue, notes libres. Deux vues au choix (bouton
  bascule dans l'onglet, ou écran **Réglages** depuis l'accueil) :
  **Compacte** (une colonne par attribut, toucher une case fait défiler ses
  valeurs) ou **Complète** (une colonne par valeur possible, à cocher). Les
  deux s'adaptent aux petits écrans (colonnes et boutons qui se compressent).
- **Règles** (par élève ou par binôme) — chacune *obligatoire* (dure) ou
  *préférence* (souple) :
  - *Place imposée* — un élève sur une place précise ;
  - *Doit être devant* — à N rangs du tableau (vue, audition, PMR…) ;
  - *Séparer* — deux élèves jamais voisins ;
  - *Rapprocher* — deux élèves voisins.
- **Objectifs d'équilibre** (souples, appliqués à toute la classe) :
  - *Mélanger les genres* — éviter les voisins de même genre ;
  - *Mélanger les niveaux* — ne pas créer 2 voisins Faibles ni 2 voisins Forts ;
  - *Séparer les élèves agités* — éviter les voisins agités ;
  - *Mauvaise vue* — rapprocher du tableau (moitié avant) les élèves concernés ;
  - *Éviter qu'un grand gêne la vue d'un petit* — devant, ou à côté sur un
    bras de U.
- **Plan** : génération automatique, rapport des contraintes respectées /
  violées (dur en rouge, perfectible en orange), et **glisser-déposer** pour
  ajuster à la main. Bouton *Régénérer* pour une autre proposition, bouton
  *Valider* pour recontrôler règles et équilibre après un ajustement manuel.
  Lisible à toute taille d'écran : la salle s'affiche en entier en **portrait**
  (avec **zoom** à deux doigts, à la molette de souris sur bureau/web, ou avec
  les **boutons de zoom** de la barre de commandes) comme en **paysage** (cases plus larges, chrome qui se replie en rail au besoin),
  avec le **prénom** en clair dès que la place
  le permet, sinon des **initiales désambiguïsées** (deux élèves aux mêmes
  initiales sont distingués). Les élèves concernés par un problème sont
  **marqués directement sur leur place** (fond rouge pâle pour une contrainte
  dure, orange pâle pour un objectif souple non atteint) ; un **tap** sur
  n'importe quelle place ouvre une feuille de détail (nom complet, tous les
  attributs en clair, motifs du problème s'il y en a) avec un accès direct au
  formulaire d'édition. Le genre est indiqué par un liseré coloré sur le bord
  gauche de la carte (muet pour « non précisé ») ; sa palette (5 au choix) se
  règle dans l'écran **Réglages**.
- **Archives et export** : le menu ⋮ de l'onglet Plan permet d'**archiver** le
  plan sous un nom (« Trimestre 1 »…) — instantané de la salle, des élèves, des
  règles et du plan — d'ouvrir l'**historique** des plans archivés (consulter,
  **restaurer comme nouvelle classe** sans toucher à la classe actuelle,
  supprimer) et d'**exporter le plan en PDF** (A4 paysage, partage ou
  impression). Depuis l'accueil, chaque classe a son historique et un bouton
  d'**export** vers un fichier `.planclasse` (JSON) ; le bouton d'**import**, en
  haut, recrée une classe depuis un tel fichier. Ces fichiers contiennent les
  noms des élèves : l'appli le rappelle avant de les partager.
- **Réglages** : langue (système, français, anglais), thème (clair, sombre,
  automatique), vue de l'onglet Élèves et palette de couleurs du genre.
- **Aide** : un **tutoriel guidé** (icône « école » de l'accueil) sur une classe
  de démonstration temporaire, une aide propre à chaque écran (menu « ? » de
  l'accueil, bouton d'aide de chaque onglet d'une classe) et une **FAQ hors
  ligne**.
- **Classe de démo** : bouton (accueil, écran vide ou icône dans l'AppBar)
  pour ajouter en un clic une classe fictive « 6ème B » déjà remplie (20
  élèves, salle, règles, plan) — pratique pour découvrir l'appli sans tout
  ressaisir, ou pour reproduire les captures d'écran du Play Store.

## Comment ça marche (le moteur)

L'affectation est un problème d'optimisation sous contraintes. Le moteur
(`lib/engine/seating_engine.dart`) utilise un **recuit simulé** avec
redémarrages : il minimise un coût où les contraintes dures coûtent très cher
et les préférences peu, puis renvoie le meilleur plan trouvé.

Sur desktop (Windows/macOS/Linux), la taille et la position de la fenêtre
sont mémorisées entre deux lancements (`window_manager`, voir `main.dart`).

## Lancer l'application

Depuis un terminal PowerShell, à la racine du projet :

```powershell
# Sur le PC (le plus simple, aucune config)
.\run.ps1               # équivaut à : flutter run -d windows

# Dans le navigateur Edge
.\run.ps1 edge

# Sur un téléphone Android branché en USB (mode développeur activé)
.\run.ps1 <id-du-téléphone>   # voir « flutter devices »

# Sur l'émulateur Android (Pixel_API36)
.\emulateur.ps1
```

Générer un APK installable sur Android :

```powershell
flutter build apk            # APK de production -> build\app\outputs\flutter-apk\
```

> `.\emulateur.ps1` démarre l'émulateur Pixel_API36, attend la fin du
> démarrage d'Android, puis lance l'app dessus. Nécessite d'avoir activé la
> virtualisation *Windows Hypervisor Platform* et redémarré Windows une
> première fois.

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

Les ressources de la fiche **Google Play** (icône 512×512 ; par langue — fr-FR
et en-US — textes, bandeau 1024×500, captures d'écran et notes de version ;
politique de confidentialité) sont regroupées dans **`store/play/`** — voir
[store/play/README.md](store/play/README.md).

Sur un tag `vX.Y.Z`, le workflow [.github/workflows/release.yml](.github/workflows/release.yml)
construit l'**APK** (installable directement) et l'**AAB signé** (tous les ABI, à
téléverser sur Google Play), et les joint à la Release GitHub. La ligne
`version: X.Y.Z+N` du `pubspec.yaml` est l'unique source de vérité : le tag doit
être `vX.Y.Z`, et le changelog Play Store `changelogs/N.txt` doit exister dans
chaque langue (`fr-FR` et `en-US`). Une
release taguée ou manuelle échoue immédiatement si un secret de signature
manque, au lieu de produire silencieusement un AAB signé avec la clé de debug.

## Qualité

Sur chaque push sur `main` et chaque pull request, le CI
([.github/workflows/ci.yml](.github/workflows/ci.yml)) vérifie le format Dart,
lance `flutter analyze` et `flutter test`, puis — seulement si ces trois
contrôles passent — compile **toutes** les cibles (Web, Windows, Android, iOS
non signé) et compare les performances du moteur de placement à `main` (PR
uniquement). Une PR mise à jour annule sa validation en cours ; chaque job a un
délai maximal. Aucun de ces jobs n'a accès à la clé de signature, réservée à
`release.yml`. Le workflow
([.github/workflows/sonarcloud.yml](.github/workflows/sonarcloud.yml)) lance
les tests avec couverture puis envoie une analyse statique à
[SonarCloud](https://sonarcloud.io/project/overview?id=antoine1838_classroom-sorter)
(bugs, code smells, duplication, couverture). Config dans
[sonar-project.properties](sonar-project.properties). Le CodeQL par défaut de
GitHub ne couvre que les fichiers Actions/C++ (Dart non supporté) — SonarCloud
comble ce trou côté Dart.

Les contrôles de pull request utilisent Flutter 3.47.6, épinglé pour garantir
des résultats reproductibles. Chaque lundi, le workflow
[`flutter-stable.yml`](.github/workflows/flutter-stable.yml) vérifie analyse,
tests et builds Web/Windows avec le dernier Flutter stable : il signale qu'une
mise à niveau du SDK doit être évaluée sans rendre les validations courantes
instables.

Les pull requests mesurent aussi le moteur de placement avec la fixture de
35 élèves. Dans le même runner Ubuntu, le CI compare le P95 de `generate()` à
celui de `main` et échoue au-delà de 20 % de régression. Le rapport JSON et le
résumé de comparaison sont disponibles dans les artefacts du job ; il ne s'agit
pas d'un seuil absolu, volontairement fragile entre machines.

## Structure du code

```
lib/
├── models/        Student, Room/Seat, Rule, ClassGroup, SavedRoom   (+ JSON)
│               room_layouts.dart — dispositions (Rangées, U, Îlots, page blanche)
│               plan_snapshot.dart — instantané d'un plan archivé
├── engine/        seating_engine.dart — moteur d'affectation (recuit simulé)
│               plan_generation.dart — génération du plan (hors thread UI)
│               plan_issue.dart — problèmes rapportés + élèves concernés
├── actions/       class_group_ops.dart — opérations métier sur une classe
├── data/          repository.dart — stockage local (shared_preferences)
├── services/      plan_file_service.dart — export/import `.planclasse`
│               plan_pdf_service.dart — export PDF du plan
├── screens/       home_screen, class_editor_screen (4 onglets : Salle, Élèves,
│                  Règles, Plan, dans class_editor/), plan_history_screen,
│                  settings_screen, faq_screen
├── tutorial/      tutorial_guide.dart — tutoriel guidé et aides par écran
├── widgets/       seat_grid.dart — grilles (édition + drag & drop)
│               plan_viewport.dart — zoom / pan du plan, sans conflit avec le
│                                    glisser-déposer d'un élève
│               room_thumbnail.dart — aperçu d'une salle
├── l10n/          app_fr.arb (gabarit) et app_en.arb ; le code généré
│                  (generated/) n'est pas versionné
├── app_state.dart État global (ChangeNotifier) + persistance
└── main.dart      Point d'entrée, thème, langue et fenêtre desktop

assets/demo/       demo_class_6emeb.json — classe de démo embarquée (voir
                   test/fixtures/README.md pour la fixture de référence)
assets/fonts/      Noto Sans — police embarquée pour l'export PDF
store/play/        fiche Google Play, par langue (voir store/play/README.md)
tool/              benchmark du moteur de placement (utilisé par la CI)
notes/             notes de chantier (décisions de conception, historiques)
docs/              politique de confidentialité, publiée via GitHub Pages
```

Les tests sont dans `test/`, un fichier par sujet : moteur (`engine_test`,
`seating_neighbors_test`, `balance_objectives_test`, `plan_issues_test`…),
modèles et stockage (`models_test`, `repository_test`, `app_state_test`…),
écrans (`home_screen_test`, `class_editor_screen_test`, `settings_screen_test`,
`faq_screen_test`, `tutorial_guide_test`, `plan_history_screen_test`…), plan
(`plan_landscape_test`, `plan_viewport_gestures_test`, `seat_marking_test`…),
services (`plan_file_service_test`, `plan_pdf_service_test`) et garde-fous de
release (`release_workflow_test`, `android_privacy_config_test`). Lancer
`flutter test` ; `flutter analyze` et `dart format lib test tool` doivent aussi
passer, la CI les exige.

## Licence

Le code est publié sous licence [MIT](LICENSE). Deux exceptions :

- les polices Noto Sans embarquées dans `assets/fonts/` (export PDF) restent
  sous [SIL Open Font License 1.1](assets/fonts/OFL.txt) ;
- l'**icône de l'application** (`assets/icon/` et ses déclinaisons Android,
  iOS, Web et Windows) et les **visuels de la fiche Google Play**
  (`store/` : icônes, bandeaux, captures d'écran) sont © Antoine1838, tous
  droits réservés : ils ne sont pas couverts par la licence MIT.

## Idées d'améliorations

Pistes, sans engagement :

- Glisser un élève « non placé » directement sur une place libre (aujourd'hui,
  le rapport se contente de les signaler).
- Mode **présentation** : afficher le plan en plein écran, lisible de loin
  (vidéoprojecteur, tableau numérique).
- Comparer deux plans archivés côte à côte.
- Réglage de l'intensité des préférences (pondération).
- Importer des élèves depuis un fichier (CSV) en plus de la saisie d'une liste.
