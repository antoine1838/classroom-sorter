# Assets Google Play

Ressources de la fiche Play Store (appli Android). À copier dans la
**Play Console** au moment de la publication.

## Visuels

| Fichier | Champ Play | Spec |
|---|---|---|
| `icon-512.png` | Icône de l'appli | 512×512, PNG 32 bits, opaque |
| `feature-graphic-1024x500.png` | Image mise en avant | 1024×500, PNG/JPEG 24 bits |
| `screenshots/*.png` | Captures téléphone | 8 (6 × 1080×1920 portrait + 2 paysage) |

Icône et bandeau régénérés depuis l'icône de l'app via le skill
`flutter-store-graphics` (`gen_feature_graphic.py`, `regen_platforms.py`).

Captures (`screenshots/`), prises sur le build Windows, une classe de démo
(noms fictifs) :
`01-accueil`, `02-salle`, `03-eleves-compacte`, `04-eleves-complete`,
`05-regles`, `06-plan` (portrait, 1080×1920) ; `07-plan-detail` (portrait,
la feuille de détail ouverte au tap sur une place) ; `08-plan-paysage`
(paysage, ~950×500, cases rectangulaires + rail de commandes). L'onglet
Élèves a deux captures, une par vue : Compacte (colonne par attribut, tap
pour cycler) et Complète (colonne par valeur, cases à cocher). `06-plan` et
`07-plan-detail` forcent une violation (place imposée non honorée) pour que
le marquage par sévérité et la feuille de détail aient quelque chose à
montrer — la classe de démo, telle que livrée, respecte toutes ses règles.

Depuis l'ajout du bouton **« Classe de démo »** sur l'accueil (icône baguette
magique dans l'AppBar), plus besoin d'injecter la classe à la main dans les
prefs Windows pour préparer ces captures : un clic dans l'appli suffit à
obtenir la même « 6ème B » à 20 élèves (voir `test/fixtures/README.md`).

> **À refaire** : `02-salle` a été prise avant l'ajout du bouton
> **Disposition** (modèles Rangées/U/Îlots) et de la rotation des places —
> elle ne montre plus l'état réel de l'onglet Salle. Une capture avec une
> disposition en U ou en îlots appliquée illustrerait aussi mieux la
> fonctionnalité que la grille rectangulaire d'origine.

## Textes — `metadata/<locale>/`

Un champ = un fichier (convention *fastlane*). Langue par défaut : `fr-FR`.

| Fichier | Champ Play | Limite |
|---|---|---|
| `title.txt` | Nom de l'appli | 30 caractères |
| `short_description.txt` | Description courte | 80 caractères |
| `full_description.txt` | Description complète | 4000 caractères |
| `changelogs/<versionCode>.txt` | Notes de version (« Nouveautés ») | 500 caractères |

Le contenu des descriptions reflète les fonctionnalités réelles (attributs
élèves, règles par binôme, objectifs d'équilibre) — voir aussi le README racine.

`changelogs/<versionCode>.txt` : un fichier par version, nommé d'après le
*build number* (`versionCode` Android, partie après le `+` dans
`pubspec.yaml`), pas le numéro de version lisible — ex. `10.txt` pour
`1.8.0+10`. Texte orienté utilisateur (pas un changelog technique), à copier
dans le champ « Notes de version » de la Play Console à chaque publication.

## Politique de confidentialité

URL (champ obligatoire de la Play Console) :
**https://antoine1838.github.io/classroom-sorter/**

Source : [`docs/index.html`](../../docs/index.html) à la racine du dépôt, publiée
via **GitHub Pages** (`main` / `docs`). Contenu : app hors ligne, aucune donnée
collectée / transmise / partagée, stockage local uniquement.
