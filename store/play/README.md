# Assets Google Play

Ressources de la fiche Play Store (appli Android). À copier dans la
**Play Console** au moment de la publication.

## Visuels

| Fichier | Champ Play | Spec |
|---|---|---|
| `icon-512.png` | Icône de l'appli | 512×512, PNG 32 bits, opaque |
| `feature-graphic-1024x500.png` | Image mise en avant | 1024×500, PNG/JPEG 24 bits |
| `screenshots/*.png` | Captures téléphone | 5 × 1080×1920 (9:16) |

Icône et bandeau régénérés depuis l'icône de l'app via le skill
`flutter-store-graphics` (`gen_feature_graphic.py`, `regen_platforms.py`).

Captures (`screenshots/`, ≥ 4 en 1080×1920 pour pouvoir promouvoir l'appli) :
`01-accueil`, `02-salle`, `03-eleves`, `04-regles`, `05-plan` — prises sur le
build Windows (écran portrait), une classe de démo (noms fictifs).

## Textes — `metadata/<locale>/`

Un champ = un fichier (convention *fastlane*). Langue par défaut : `fr-FR`.

| Fichier | Champ Play | Limite |
|---|---|---|
| `title.txt` | Nom de l'appli | 30 caractères |
| `short_description.txt` | Description courte | 80 caractères |
| `full_description.txt` | Description complète | 4000 caractères |

Le contenu des descriptions reflète les fonctionnalités réelles (attributs
élèves, règles par binôme, objectifs d'équilibre) — voir aussi le README racine.

## Politique de confidentialité

URL (champ obligatoire de la Play Console) :
**https://antoine1838.github.io/classroom-sorter/**

Source : [`docs/index.html`](../../docs/index.html) à la racine du dépôt, publiée
via **GitHub Pages** (`main` / `docs`). Contenu : app hors ligne, aucune donnée
collectée / transmise / partagée, stockage local uniquement.
