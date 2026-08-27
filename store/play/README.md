# Assets Google Play

Ressources de la fiche Play Store (appli Android). À copier dans la
**Play Console** au moment de la publication.

## Visuels

| Fichier | Champ Play | Spec |
|---|---|---|
| `icon-512.png` | Icône de l'appli | 512×512, PNG 32 bits, opaque |
| `feature-graphic-1024x500.png` | Image mise en avant | 1024×500, PNG/JPEG 24 bits |
| `screenshots/*.png` | Captures téléphone **et tablettes** | 8 (7 × 1080×1920 portrait + 1 × 1920×1080 paysage) |

Icône et bandeau régénérés depuis l'icône de l'app via le skill
`flutter-store-graphics` (`gen_feature_graphic.py`, `regen_platforms.py`).

Captures (`screenshots/`), prises sur le build Windows, une classe de démo
(noms fictifs), refaites en totalité pour la 1.10.0 :
`01-accueil` (trois classes, pour ne pas montrer une liste presque vide),
`02-salle` (**disposition en îlots** : 6×6, deux types de couloirs, élèves
assis de côté — la capture qui montre le plus de nouveautés à la fois),
`03-eleves-compacte`, `04-eleves-complete`, `05-regles`, `06-plan`,
`07-plan-detail` (feuille de détail ouverte sur l'élève en violation),
tous en portrait 1080×1920 ; `08-plan-paysage` en **1920×1080**.

`06-plan` et `07-plan-detail` forcent une violation (place imposée non
honorée) pour que le marquage par sévérité et la feuille de détail aient
quelque chose à montrer — la classe de démo, telle que livrée, respecte
toutes ses règles. L'onglet Élèves a deux captures, une par vue : Compacte
(colonne par attribut, tap pour cycler) et Complète (colonne par valeur,
cases à cocher).

**Refaites partiellement pour la 1.11.0** (4 des 8, les autres inchangées) :
`05-regles` (texte corrigé des objectifs grand/petit et agité, issue #30) et
`06-plan`/`07-plan-detail`/`08-plan-paysage` (liseré de genre : nouveau défaut
vert canard/corail au lieu du bleu/rose d'origine, issue #27 — palette
réglable en Réglages, voir le sélecteur ajouté à cette version).

### Contraintes de dimensions (⚠️ vérifié le 2026-08-25)

Les captures servent **deux** slots de la Play Console, téléphone et
tablettes, dont les exigences diffèrent :

| Slot | Dimensions | Ratio | Nombre |
|---|---|---|---|
| Téléphone | 320–3840 px ; paysage ≥ 1920×1080 | 16:9 ou 9:16 | 2 min, 4+ recommandé |
| Tablettes 7"/10" | **1080–7680 px** | 16:9 ou 9:16 | **4 min** |

Les 7 portraits à 1080×1920 sont conformes aux deux slots. `08-plan-paysage`
faisait auparavant ~950×500 : **sous le minimum des deux slots**, et d'un
ratio (1,9:1) qui n'est ni 16:9 ni 9:16 — d'où le rejet côté tablettes.
Refaite en 1920×1080.

**Conséquence à connaître** : à 1920×1080 sur un moniteur à 150 %, la fenêtre
fait 1280×720 **dp**, donc `planUsesRail` ne se déclenche pas (il lui faut
moins de ~510 dp de haut) et le **rail latéral n'apparaît pas** sur la
capture. C'est correct — un rail est une adaptation téléphone-en-paysage,
qu'une tablette ne voit pas. Reproduire le rail à une taille conforme
exigerait une mise à l'échelle Windows ≥ 225 %.

Android XR n'est pas couvert : il demande un ratio 8:5 (≥ 1920×1200), soit un
troisième jeu de captures.

Depuis l'ajout du bouton **« Classe de démo »** sur l'accueil (icône baguette
magique dans l'AppBar), plus besoin d'injecter la classe à la main dans les
prefs Windows pour préparer ces captures : un clic dans l'appli suffit à
obtenir la même « 6ème B » à 20 élèves (voir `test/fixtures/README.md`).

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

Les fichiers déjà publiés ne se modifient pas : ce sont les archives de ce qui
a réellement été envoyé, erreurs comprises. Une phrase fautive se corrige en ne
la reprenant pas dans le fichier suivant — elle disparaît de la fiche Play dès
que le nouveau texte y est collé.

> **Ne jamais reprendre** la dernière puce de `11.txt` (1.9.0), qui annonce des
> « prénoms et noms mis en majuscule automatiquement ». C'est faux —
> l'application se contente d'indiquer au clavier virtuel de proposer une
> majuscule, et un clavier dont l'option correspondante est désactivée l'ignore.
> Voir l'issue #25 pour le diagnostic complet. Corrigé par omission dans
> `12.txt` (1.10.0), qui est donc le texte à recopier si l'on cherche un modèle.

## Politique de confidentialité

URL (champ obligatoire de la Play Console) :
**https://antoine1838.github.io/classroom-sorter/**

Source : [`docs/index.html`](../../docs/index.html) à la racine du dépôt, publiée
via **GitHub Pages** (`main` / `docs`). Contenu : app hors ligne, aucune donnée
collectée / transmise / partagée, stockage local uniquement.
