# Assets Google Play

Ressources de la fiche Play Store (appli Android). À copier dans la
**Play Console** au moment de la publication.

## Visuels

| Fichier | Champ Play | Spec |
|---|---|---|
| `icon-512.png` | Icône de l'appli | 512×512, PNG 32 bits, opaque |
| `metadata/<langue>/feature-graphic-1024x500.png` | Image mise en avant (texte localisé : une par langue) | 1024×500, PNG/JPEG 24 bits |
| `metadata/<langue>/screenshots/*.png` | Captures téléphone **et tablettes** | 8 (7 × 1080×1920 portrait + 1 × 1920×1080 paysage) |

Icône et bandeau régénérés depuis l'icône de l'app via le skill
`flutter-store-graphics` (`gen_feature_graphic.py [en]`, sortie dans `metadata/<langue>/`, `regen_platforms.py`). Le bandeau contient du texte : une version par langue.

Captures (`metadata/<langue>/screenshots/`), prises sur le build Windows, une classe de démo
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

**Refaites pour la 1.12.0** : les 8, en thème **clair** (forcé par le hook),
pour montrer les boutons de zoom du Plan (issue #24) et fournir un jeu
**anglais** dans `metadata/en-US/screenshots/` (classes « Grade 6B / 7A / 9C », mêmes
élèves fictifs). Le jeu français reste dans `metadata/fr-FR/screenshots/`. Procédure et
scripts : [`tools/README.md`](tools/README.md).

**Refaites pour la 1.13.0** : les 8, dans les deux langues, pour montrer les
nouveautés de l'accueil (import, historique, export, tutoriel, aide) et de
l'onglet Plan (menu ⋮, aide). Le hook de capture marque en plus le tutoriel
comme déjà vu, sans quoi l'invite de bienvenue s'affiche sur l'accueil. Le
patch `tools/screenshot-hooks.patch` est regénéré pour ce code.

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

Un champ = un fichier (convention *fastlane*). Langue par défaut : `fr-FR` ;
`en-US` est la traduction anglaise (l'appli est bilingue depuis la 1.12.0).
Le workflow et `test/release_workflow_test.dart` exigent le changelog du build
courant dans **chaque** langue, et vérifient les limites de caractères.

**Play Console, une fois** : Fiche Play Store → Gérer les traductions → ajouter
l'anglais, puis coller `title.txt`, `short_description.txt` et
`full_description.txt` d'`en-US/`, et téléverser `metadata/en-US/screenshots/` comme captures
anglaises (icône et bandeau se reprennent de la langue par défaut). À chaque release, les
notes de version se saisissent par langue (`<fr-FR>…</fr-FR>` / `<en-US>…</en-US>`).

**Côté Android** : le nom de l'appli est la ressource `app_name`
(`res/values*/strings.xml`), `locales_config.xml` déclare fr/en (langue par
appli, Android 13+) et `localeFilters` dans `build.gradle.kts` limite le bundle
à ces deux langues, que Play lit pour annoncer les langues supportées. Côté iOS,
`CFBundleLocalizations` déclare fr/en ; le nom affiché reste « Plan de classe »
(un nom anglais demanderait un `InfoPlist.strings` référencé dans le projet
Xcode, non testable ici).

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
dans le champ « Notes de version » de la Play Console à chaque publication. Le
workflow refuse désormais de construire l'AAB si ce fichier manque ou si le
tag `vX.Y.Z` ne correspond pas au `pubspec`.

À partir de la version `1.12.0+119`, le build number du `pubspec` est également
celui réellement injecté dans Android et iOS. Le saut de `13` à `119` évite de
redescendre sous le `versionCode` 118 produit par l'ancien workflow pour
`v1.11.0`.

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
collectée / transmise / partagée par l'application, stockage local et exclusion
explicite des sauvegardes cloud et transferts automatiques Android.

## Publication automatique (brouillon en production)

Après la Release GitHub, le job `publish-play` de
[`release.yml`](../../.github/workflows/release.yml) dépose l'AAB et les notes
`changelogs/<buildNumber>.txt` (fr-FR et en-US) dans la Play Console, en
**brouillon sur la piste production**. Rien n'atteint les utilisateurs avant
votre clic **« Envoyer en examen »** dans la Console.

Aucune clé n'est stockée : le job présente son jeton OIDC GitHub à Google
(*Workload Identity Federation*) et reçoit un accès éphémère. Le job est inerte
tant que la variable de dépôt `GCP_WORKLOAD_IDENTITY_PROVIDER` n'est pas posée,
et il attend l'approbation de l'environnement `play-production`.

### Mise en place, une fois (dans vos comptes)

Les commandes `gcloud` sont à adapter (`PROJECT_ID`, `PROJECT_NUMBER`) ; le
compte de service ne reçoit **aucun** rôle Google Cloud.

1. **Google Cloud** : activer l'API *Google Play Android Developer*, créer le
   compte de service, la fédération et l'autorisation d'usage.

   ```bash
   gcloud services enable androidpublisher.googleapis.com --project=PROJECT_ID
   gcloud iam service-accounts create play-publisher --project=PROJECT_ID
   gcloud iam workload-identity-pools create github --project=PROJECT_ID --location=global
   ```

   Le fournisseur n'accepte que l'environnement `play-production` de ce dépôt
   (c'est la valeur `sub` du jeton quand un job déclare un `environment`) :

   ```bash
   gcloud iam workload-identity-pools providers create-oidc classroom-sorter --project=PROJECT_ID --location=global --workload-identity-pool=github --issuer-uri="https://token.actions.githubusercontent.com" --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" --attribute-condition="assertion.sub=='repo:antoine1838/classroom-sorter:environment:play-production'"
   ```

   ```bash
   gcloud iam service-accounts add-iam-policy-binding play-publisher@PROJECT_ID.iam.gserviceaccount.com --project=PROJECT_ID --role=roles/iam.workloadIdentityUser --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/antoine1838/classroom-sorter"
   ```

2. **Play Console** → Utilisateurs et autorisations → inviter l'adresse
   `play-publisher@PROJECT_ID.iam.gserviceaccount.com` avec, sur cette appli
   seulement, le droit de publier en production (libellé à confirmer dans la
   Console, l'écran évolue).
3. **GitHub** → Settings → *Environments* → créer **`play-production`** :
   *Required reviewers* = vous, et *Deployment branches and tags* limité aux
   tags `v*`. Sans cet environnement configuré, GitHub le crée sans protection.
4. **GitHub** → Settings → *Secrets and variables* → *Actions* → onglet
   *Variables* (ce ne sont pas des secrets) :
   - `GCP_WORKLOAD_IDENTITY_PROVIDER` =
     `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/classroom-sorter`
   - `GCP_SERVICE_ACCOUNT` = `play-publisher@PROJECT_ID.iam.gserviceaccount.com`

### À chaque release

Le tag `vX.Y.Z` lance le build et la Release GitHub, puis `publish-play`
attend votre approbation dans l'onglet *Actions*. Une fois approuvé, le
brouillon apparaît dans la Console (Production → Versions) avec l'AAB et les
notes des deux langues : relisez-le, puis **Envoyer en examen**.

⚠️ Non éprouvé de bout en bout : le job n'a pas encore tourné contre la vraie
Console. Le premier essai se fait à la prochaine release, sans risque puisque
le statut est `draft`. Les captures et la fiche texte restent gérées à la main
(l'API les écraserait).
