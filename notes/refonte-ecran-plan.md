# Refonte de l'écran Plan — note de chantier

Issue de référence : [#8 « Élèves peu identifiables sur le plan »](https://github.com/antoine1838/classroom-sorter/issues/8).
Absorbe [#12 « Pas d'affichage du plan en mode paysage »](https://github.com/antoine1838/classroom-sorter/issues/12).

Hors périmètre : [#13](https://github.com/antoine1838/classroom-sorter/issues/13) (export / grand écran / partage)
et [#11](https://github.com/antoine1838/classroom-sorter/issues/11) (onglet Élèves).
La recherche d'un élève et une vue liste « élève → place » sont écartées : le zoom en portrait et les
prénoms en paysage doivent couvrir le besoin. Si ça ne suffit pas à l'usage, ça méritera sa propre issue.

## Problème

Le symptôme n'est pas que le plan est trop petit à lire, c'est que `MD` ne désigne personne, et que
deux élèves peuvent porter les mêmes initiales sans être distingués (`Student.initials`,
`lib/models/student.dart`).

## Géométrie de référence

Mesures calculées depuis `kCell = 62`, `kGap = 6`, `kRowGap = 14` (`lib/widgets/seat_grid.dart`),
pour une salle 8×5 sur un Galaxy A56 (411 × 891 dp en logique).

| Situation | Hauteur/largeur utile | Échelle `FittedBox` | Place rendue | Texte |
| --- | --- | --- | --- | --- |
| Portrait actuel | 387 dp de large pour 546 | 0,709 | 44 dp | 11 px |
| Paysage actuel (#12) | ~187 dp de haut pour 409 | 0,457 | 28 dp | 7 px |
| Paysage actuel + carte de rapport | ~87 dp de haut | 0,21 | 13 dp | — |
| Paysage, chrome déplacé | ~363 dp de haut | 0,89 | 80 × 55 dp | 13 px |

Deux conclusions qui pilotent tout le reste :

- **En portrait la largeur est la ressource rare ; en paysage c'est la hauteur.** Donc les cases
  rectangulaires larges sont le bon choix en paysage et le mauvais en portrait.
- **#12 n'est pas un plantage** : le chrome vertical (app bar 56 + onglets 48 + rangée de boutons 72)
  ne laisse pas assez de hauteur, et le `FittedBox` réduit jusqu'à l'invisible.

## Décisions arrêtées

**Vue et échelle**

- Portrait : vue d'ensemble complète par défaut, **zoom** ajouté. Le zoom repart de la vue d'ensemble
  à chaque ouverture de l'onglet (pas de niveau persistant), avec un bouton « recentrer » quand on est zoomé.
  Bornes : minimum = vue d'ensemble, maximum 3×.
- Paysage : vue complète également, avec des cases rectangulaires portant le prénom.
- **Seuil géométrique unique** : dès qu'une case *rendue* dépasse ~54 dp, elle affiche le prénom ;
  en dessous, les initiales désambiguïsées. Une seule règle couvre les quatre cas — portrait 8 colonnes
  (44 dp → initiales), portrait zoomé 1,25× (55 dp → prénom), paysage (80 dp → prénom), et petite salle
  de 5 colonnes en portrait (62 dp → prénom sans rien demander).

**Chrome en paysage**

- La rangée Générer / Valider passe en **rail vertical à droite** ; app bar et onglets masqués en paysage.
- Le rail contient : Générer, Valider, badge « n problèmes », et « recentrer » seulement quand on est zoomé.
  Il doit rester mince : c'est la largeur qui paie les prénoms.

**Gestes**

- **1 doigt = déplacer un élève** (le glisser-déposer existant), **2 doigts = zoom et déplacement de la vue**.
- L'échange reste **exclusivement** au glisser-déposer ; la sélection par tap-tap est écartée.
- **Tap sur une place = une feuille unique** : nom complet, *tous* les attributs en clair (y compris ceux
  muets sur la case, sinon les glyphes redeviennent indevinables), les motifs de problème s'il y en a,
  et un bouton « Modifier l'élève » qui ouvre le formulaire existant.
- Le `Tooltip` de nom complet est **supprimé** : plus rien de caché à expliquer, ce qui résout la piste
  « expliquer l'appui long » de #8 au lieu de la documenter.
- Aucune légende dédiée : c'est la feuille du tap qui rend le vocabulaire déchiffrable.

**Marquage des élèves fautifs**

- Le moteur doit **arrêter de jeter les identifiants**. Aujourd'hui `violations` et `warnings` sont des
  `List<String>` avec le nom interpolé dans le texte (`_report`, `lib/engine/seating_engine.dart`), et
  les notes d'équilibre ne gardent qu'un compteur (`bothAgite`, `eyesightBack`, `tallFrontOfShort`).
- Rendu **par sévérité** : violation dure et objectif d'équilibre non atteint ont deux rendus distincts.
  Détail des motifs **au tap**.
- Le marquage prend le **fond** de la case (canal le plus lisible quand les cases sont petites) ; le genre
  se replie sur un **liseré vertical de 4 px** au bord gauche, qui survit à l'échelle 0,709 du portrait.

**Rapport de validation**

- `_ReportCard` devient un **badge compteur** (« 2 problèmes ») ouvrant une feuille, en portrait comme
  dans le rail paysage. Les non-placés vivent dans cette même feuille.
- Motif : en portrait la carte consomme ~100 dp au-dessus de la grille et aggrave le rétrécissement ;
  en paysage c'est elle qui fait tomber l'échelle à 0,21.

**Désambiguïsation des initiales**

- Allonger le nom de famille lettre à lettre jusqu'à lever l'ambiguïté : `M.Du` / `M.Da`, puis
  `M.Dup` / `M.Dur` s'il faut.
- Arrêt net en cas d'homonymie totale : deux « Marie Dupont » sont réellement indiscernables sur une
  case, et c'est le tap qui tranche.

## Ordre de travail

1. ~~**Moteur** : faire remonter les identifiants fautifs.~~ **Fait** — voir ci-dessous.
2. ~~**Prototype de gestes** sur une branche `experiment/`.~~ **Fait et validé sur appareil**
   le 19/08/2026 (Galaxy A56, One UI 8.5, Android 16). Voir ci-dessous.
3. **Paysage** (#12) : rail, chrome masqué, cases rectangulaires. **Fait**, voir ci-dessous ;
   reste la vérification typographique sur appareil.
4. **Marquage et feuille de détail** : le moteur remonte déjà les élèves fautifs (étape 1), il reste à
   les peindre et à ouvrir la feuille au tap. ← prochaine étape

### Étape 1 — ce qui a été construit

`lib/engine/plan_issue.dart` : `IssueSeverity` (`hard` / `soft`), `PlanIssue` (gravité, libellé,
élèves concernés) et `BalanceNote` (objectif atteint ou non, libellé, élèves concernés).

`PlanResult` expose désormais `issues` et offre à l'UI exactement ce que le marquage demande :

- `severityFor(studentId)` → la gravité à peindre sur la place, le dur primant sur le souple ;
- `reasonsFor(studentId)` → les motifs à lister au tap, les plus graves d'abord ;
- `flaggedStudentIds` → l'ensemble des élèves concernés.

`violations` et `warnings` sont devenus des **getters dérivés** de `issues`, donc `_ReportCard` et les
tests existants n'ont pas bougé d'une ligne — l'UI reste intacte, comme prévu pour cette étape.

Un objectif d'équilibre non atteint marque ses élèves au même titre qu'une contrainte souple. Les
élèves **non placés** ne marquent personne : ils n'occupent aucune place, c'est un problème de salle.

Détail d'implémentation à ne pas défaire : `_poorEyesightBackCount` et `_tallInFrontOfShortCount` sont
partagés avec `_cost`, appelé des dizaines de milliers de fois par génération. Ils reçoivent les
identifiants via un paramètre de sortie **optionnel**, laissé nul dans le recuit — donc aucune
allocation dans le chemin chaud. Mesuré sur la fixture 35 élèves, tous objectifs actifs :
471,8 ms par plan avant, 472,6 ms après (5 générations, écart dans le bruit).

Couverture : `test/plan_issues_test.dart`, 15 tests. Ils passent par `evaluate()` avec une affectation
fabriquée à la main plutôt que par `generate()`, parce que le recuit cherche justement à éviter les
violations et qu'il faudrait sinon dépendre d'une graine.

### Étape 2 — l'arbitrage des gestes

`lib/widgets/plan_viewport.dart`. Trois pièces, et **les trois sont nécessaires** :

1. Le filtrage sur `ScaleUpdateDetails.pointerCount` dans les callbacks de zoom : en dessous de deux
   doigts, on ne touche pas à la transformation.
2. `PointerTracker` — un simple compteur de doigts, alimenté par un `Listener` placé **au-dessus** du
   reconnaisseur pour qu'il voie tous les pointeurs quel que soit le verdict de l'arène.
3. `SeatDraggable` — un `Draggable` dont le reconnaisseur refuse de saisir un élève dès qu'il y a deux
   doigts.

**On ne peut pas arbitrer par l'arène de gestes.** Première tentative : un `ScaleGestureRecognizer`
qui renonce à l'arène dès qu'un doigt unique franchit `kTouchSlop`. Ça ne marche pas — quand le
reconnaisseur est seul candidat, l'arène lui accorde la victoire dès sa fermeture, donc un
`resolve(rejected)` ultérieur arrive trop tard. Le symptôme était discret : à l'échelle 1 la
translation est bornée à zéro, donc rien ne bougeait ; mais **une fois zoomé, un doigt sur une zone
vide déplaçait la vue**. Le filtrage dans les callbacks remplace ce mécanisme et supprime une
cinquantaine de lignes subtiles. Le reconnaisseur rappelle `onStart` à chaque changement du nombre de
doigts, ce qui suffit à rattraper l'arrivée du second.

**Il faut arbitrer des deux côtés.** Avec le `Draggable` standard, un pincement posé sur une place
déclenche **deux** glissers — un par doigt — et le zoom n'a jamais lieu, parce que `Draggable`
s'appuie sur un reconnaisseur *multi*-drag qui gagne l'arène pointeur par pointeur. Comme la
quasi-totalité de la surface du plan est faite de places, ce cas serait arrivé constamment. D'où
`SeatDraggable`. **Contrainte pour l'étape 3 : les places du plan ne peuvent pas utiliser `Draggable`
tel quel.**

Couverture : `test/plan_viewport_gestures_test.dart`, 11 tests multi-pointeurs. Ils vérifient qu'un
doigt atteint le `Draggable`, que deux doigts zooment, qu'un pincement **démarré sur une place** ne
déplace aucun élève, qu'un second doigt arrivant en retard zoome quand même, que le zoom reste borné
entre la vue d'ensemble et ×3, que « recentrer » revient à la vue d'ensemble, que le glisser-déposer
survit à un zoom, qu'un doigt annulé libère bien le compteur (sinon les places deviendraient
insaisissables), et — le garde-fou du défaut ci-dessus — qu'**une fois zoomé**, un doigt sur une zone
vide ne déplace toujours pas la vue.

**Ce que ces tests ne prouvent pas** : la jitter des doigts, le décalage réel entre la pose des deux
doigts, le rejet de paume, et le seuil de déplacement du système. D'où le banc d'essai
`lib/prototypes/plan_gestures_prototype.dart`, qui compte à l'écran les élèves déplacés et les zooms
sur une grille 8×5 réduite comme dans l'app.

**Validé sur appareil le 19/08/2026** (Galaxy A56, One UI 8.5, Android 16) : un doigt ne zoome jamais,
deux doigts ne déplacent jamais un élève — y compris pincement démarré pile sur une place — et une fois
zoomé, un doigt sur une zone vide ne déplace pas la vue. **Le mécanisme est donc bon pour l'étape 3.**

Pour relancer le banc (le `-t` est indispensable : sans lui c'est l'app normale qui se compile, le banc
ayant son propre `main()`) :

```
flutter build apk --release --target-platform android-arm64 -t lib/prototypes/plan_gestures_prototype.dart
```

`--release` et pas debug pour deux raisons : la fluidité ne se juge pas sur un build debug, et la clé
de signature diffère entre les deux (`android/app/build.gradle.kts`), donc un debug ne s'installe pas
par-dessus l'app release déjà présente. Attention, le banc partage l'`applicationId` de l'app : il la
remplace sur le téléphone, données conservées.

## Tests à faire

### Automatisables (`flutter test`, `flutter analyze`)

- **Moteur — identifiants fautifs.** Un test par type de règle (`separate`, `keepTogether`, `frontZone`,
  `fixedSeat`) et par objectif d'équilibre (agités voisins, mauvaise vue hors moitié avant, grand devant
  petit), vérifiant que les bons identifiants remontent — et qu'aucun ne remonte quand le plan est correct.
  Les fixtures existent déjà : `test/fixtures/demo_class_varied_35.json`.
- **Désambiguïsation des initiales.** Aucune collision ; une collision simple (`Dupont` / `Durand`) ;
  une collision en cascade (`Dupont` / `Durand` / `Dubois`) ; homonymie totale (doit s'arrêter sans
  inventer de code).
- **Seuil des 54 dp.** Tester la fonction pure « taille de case rendue → initiales ou prénom » sur les
  quatre cas du tableau ci-dessus. À isoler du rendu pour ne pas dépendre des polices.
- **Mise en page téléphone**, dans l'esprit de `test/layout_responsive_test.dart` (qui a déjà le helper
  `_globalEdges` tenant compte de la transformation du `FittedBox` via `localToGlobal`) :
  - portrait 411 × 891 : la grille tient sans débordement, le rapport est un badge ;
  - paysage 891 × 411 : le rail est présent, app bar et onglets absents, la grille tient — c'est le test
    de non-régression de #12 ;
  - une salle 5 colonnes en portrait affiche les prénoms sans zoom.
- **Rendu du marquage.** Une place en violation dure porte le fond de sévérité correspondant, une place
  en objectif souple l'autre, et le genre est bien replié sur le liseré de 4 px.
- **Régressions.** Toute la suite existante doit rester verte, en particulier `engine_test.dart`,
  `balance_objectives_test.dart`, `seating_neighbors_test.dart` et `room_orientation_test.dart`.
- **Compatibilité des données.** Le marquage est dérivé, pas stocké : vérifier qu'aucun format persisté
  ne change (aller-retour `toJson` / `fromJson`).

### À vérifier dans l'app réelle (`flutter run -d windows`)

Ces points dépendent du rendu de texte réel, que les polices factices de `flutter_test` ne reproduisent pas.

- **Le seuil de 54 dp est une estimation arithmétique** (8 lettres × ~0,55 × 11 px). Confirmer avec la
  vraie police qu'un prénom long tient effectivement, et ajuster le seuil sinon.
- Lisibilité réelle des deux fonds de sévérité et du liseré de genre à l'échelle 0,709.
- Contenu et ergonomie de la feuille de détail, et l'enchaînement « Modifier l'élève » → formulaire existant.

### À vérifier sur le téléphone — moi seul peux le faire, ne pas conclure sans

Ni les tests widget ni l'app Windows ne reproduisent le multitouch réel ; ces points ne sont pas
vérifiables autrement que sur l'appareil.

- **Arène de gestes (le risque du chantier).** Critère d'acceptation du prototype : sur une vingtaine
  d'essais, un glissement à un doigt ne déclenche jamais le zoom, et un pincement à deux doigts ne
  déplace jamais un élève. `InteractiveViewer` capte les gestes à un pointeur par défaut et entre en
  concurrence avec `Draggable` ; le contournement connu est un `ScaleGestureRecognizer` custom
  n'acceptant qu'à partir de deux pointeurs — à confirmer en vrai, pas sur le papier.
- **#12 réellement corrigé** sur le matériel de l'issue : Galaxy A56, One UI 8.5, Android 16.
- **Confort tactile.** En portrait non zoomé une case fait 44 dp, sous la cible tactile recommandée de
  48 dp : attraper le bon élève au doigt restera ingrat tant qu'on n'a pas zoomé. Acceptable si le zoom
  est fluide, mais c'est le point à surveiller.
- **Zones sûres en paysage** avec la navigation par gestes et l'encoche, une fois app bar et onglets masqués.

### Étape 3 — paysage, dimensionnement, étiquettes

**Deux règles pures**, dans `lib/models/student.dart` et `lib/widgets/seat_grid.dart` :

- `disambiguatedInitials` allonge le nom de famille lettre à lettre pour les seuls groupes en conflit,
  et s'arrête net sur une homonymie complète. (Au passage : l'exemple `M.Du` / `M.Da` donné en
  conception était faux, « Durand » commence par `Du` — les deux noms sont indiscernables à deux
  lettres, l'algorithme va donc jusqu'à `M.Dup` / `M.Dur`.)
- `showsFirstName(room, viewport, landscape, zoom)` : une case affiche le prénom dès que sa largeur
  **rendue** atteint `kFirstNameMinWidth` (54dp). Une seule règle, quatre comportements corrects,
  vérifiés par test.

**Écart assumé avec la décision Q8.** Il était prévu de masquer app bar **et** onglets en paysage.
Refait le calcul : masquer les deux donne des cases à ~80dp, garder les deux donne **52,7dp, juste
sous le seuil de 54**. Or masquer les onglets supprime le seul moyen de quitter l'onglet Plan.
Masquer l'app bar seule et garder les onglets donne **~65dp**, ce qui passe le seuil tout en
préservant la navigation. C'est la variante retenue.

**Ce n'est pas l'orientation qui décide, mais la hauteur.** `isLandscapePhone` exige
`largeur > hauteur ET hauteur < 500`. Se fier à l'orientation seule casserait le bureau : une fenêtre
y est large mais haute, et masquer son app bar supprimerait le seul retour possible, faute de geste
système. Un test couvre explicitement ce cas.

**Police proportionnelle à la case**, et non fixe : tout le contenu est ensuite réduit par le
`FittedBox`, donc une taille en dur redeviendrait minuscule dès que la salle est large.

Le rapport devient un **badge compteur** dans le rail, ouvrant une feuille — c'était lui qui, en
paysage, faisait tomber l'échelle à 0,21.

Couverture : `test/seat_label_rules_test.dart` (16 tests, logique pure) et
`test/plan_landscape_test.dart` (10 tests d'écran, dont la non-régression de #12 : la grille doit
recevoir plus de 250dp de hauteur, contre ~187 avant).

**Piège de test rencontré** : `binding.setSurfaceSize` change les contraintes de mise en page mais
**pas** ce que rapporte `MediaQuery` (mesuré : il reste à 800×600). Un test qui dépend de
l'orientation vue par MediaQuery doit régler `tester.view.physicalSize` et
`tester.view.devicePixelRatio`. Les deux usages coexistent dans la suite, chacun commenté.

**Reste à vérifier sur appareil** — et moi seul ne peux pas le faire, les polices de `flutter_test` ne
mesurant pas le texte comme le moteur : à ~65dp de largeur rendue en paysage, un prénom long tient-il
vraiment sans être coupé ? Si non, c'est `kFirstNameMinWidth` ou le coefficient de police
(`width * 0.16`) qu'il faut ajuster.

#### Correctif : police rendue constante, largeur de case mesurée

Signalé après essai sur émulateur : « en paysage on augmente la police, donc on ne gagne pas de
lettres — une seule ». Diagnostic confirmé, c'était un défaut de conception, pas un réglage.

**Cause.** La police était proportionnelle à la largeur de la case (`width * 0.16`), pour survivre à
la réduction du `FittedBox`. Mais cela rend le nombre de caractères *invariant* : la case grandit de
45 %, la police aussi, on gagne une lettre. Mesuré sur une salle 8×5 :

| | case | échelle | police rendue | lettres |
| --- | --- | --- | --- | --- |
| Portrait, avant | 62 dp | 0,719 | 7,1 px | 10,3 |
| Paysage, avant | 90 dp | 0,817 | 11,8 px | 10,6 |
| Paysage, après | 133 dp | 0,726 | 11,0 px | 15,3 |

**Deux corrections.**

1. C'est la taille de police **rendue** qui décide du nombre de caractères, donc c'est elle qu'on fixe
   (`kSeatNameRenderedSize = 11`) et la taille non mise à l'échelle qu'on en déduit
   (`nameFontSize = 11 / échelle`). Les initiales, elles, restent proportionnelles à la case : deux à
   cinq caractères, autant qu'ils la remplissent.
2. `kCellWide = 90` était codé en dur et laissait de la largeur inutilisée quand c'était la hauteur
   qui contraignait l'échelle. La largeur est désormais **mesurée** : on prend la plus grande valeur
   qui n'empire pas l'échelle, bornée par `kCellWideMax = 140`. Sur une salle 8×5 en paysage, cela
   donne 133 dp au lieu de 90.

Les fonctions éparpillées (`fitScale`, `renderedCellWidth`, `showsFirstName`, `cellWidth`) sont
remplacées par un objet unique `SeatMetrics`, mesuré d'un bloc par `seatMetrics(room, viewport, …)`.
La hauteur de grille compte maintenant le bandeau « DEVANT » et les marges : sans eux, l'échelle
prédite était plus optimiste que celle réellement appliquée par le `FittedBox`.

**À regarder sur appareil** : une case de 133 × 62 dp est un rectangle assez plat (2,15:1 ; rendu
~97 × 45). Si ça ne ressemble plus à une place, c'est `kCellWideMax` qu'il faut baisser — au prix de
quelques lettres.

#### Quatre tours de correction après essai réel

Tout ce qui suit vient d'essais sur l'app Windows et l'émulateur. Aucun n'avait été attrapé par les
tests, et chacun a donné lieu à un garde-fou.

**La place perdue sur grand écran.** `BoxFit.scaleDown` ne fait que rétrécir : dès que la fenêtre
dépassait la salle, la grille restait à sa taille naturelle collée en haut, avec des prénoms tronqués
alors que l'espace était là. Passé en `BoxFit.contain`, échelle autorisée au-delà de 1.

**Les places vides restaient carrées** au milieu de rectangles : `_emptySeat` codait `width: kCell` en
dur au lieu de la largeur mesurée.

**L'orientation ne devait pas décider de la largeur des cases.** Deux décisions étaient confondues :
masquer l'app bar exige que la hauteur soit rare, mais élargir les cases ne dépend que de la place
disponible. `seatMetrics` n'a donc plus aucune notion d'orientation.

**Le chrome se sacrifie par étapes**, et non sur un seuil unique — avec un seuil, une fenêtre de
570 dp gardait tout son chrome et la grille tombait à l'état de vignette. Ladder : rien tant que la
grille garde `_kMinGridHeight`, puis les commandes passent en rail, puis l'app bar en dernier. Le
coupable principal était toutefois la **carte de rapport** (jusqu'à 170 dp) : la décision de la
remplacer par un badge n'avait été appliquée qu'au paysage.

**Le retour ne doit jamais disparaître.** Le garde-fou « fenêtre plus large que haute » était mal
pensé : sur un bureau aucun geste système ne remplace le retour, quelle que soit la forme. Il vit
maintenant à côté des onglets, donc sans coût en hauteur, et vaut pour les quatre onglets.

**Les libellés cèdent la place aux icônes** quand la barre se resserre — mécanique qui existait dans
l'onglet Élèves et que le Plan avait perdue. Le seuil ne peut pas être constant : il dépend du nombre
de contrôles. Trois paliers, le rapport perdant son libellé avant les commandes principales.

**Les étiquettes débordaient de leur place**, sur toutes les cases à la fois. Viser une taille rendue
constante demandait, à petite échelle, une police non mise à l'échelle trop grosse pour la hauteur
fixe d'une case. La police est plafonnée par la hauteur utile — bordure comprise, 1 px de chaque côté
au repos et 2,4 au survol, ce que le premier calcul oubliait — et le prénom n'est affiché que si la
police qui tient dans cette hauteur reste lisible. Un `FittedBox` sert de filet : ce calcul dépend de
métriques de police qu'on ne peut pas connaître exactement (mon facteur de ligne était faux, 1,25 au
lieu de ~1,5).

**La leçon de test.** Ces défauts se cachaient dans les formats *intermédiaires*, pas dans les cas
choisis. D'où le balayage de treize formats de `test/plan_landscape_test.dart`, qui vérifie qu'aucun
ne produit de débordement — il a immédiatement attrapé un cas de plus (500 × 300) que je n'avais pas
prévu. À noter : un débordement de mise en page ne fait pas échouer un test par lui-même, il faut
inspecter `tester.takeException()`.

## Reste à faire

**Décisions qui te reviennent**

- ~~`kCellWideMax` (140) : les cases élargies ressemblent-elles encore à des places ?~~ **Validé** :
  « ce n'est pas choquant, ça ressemble à des places. »
- ~~Initiales plutôt qu'un prénom minuscule dans les formats serrés.~~ **Validé** : « c'est OK, c'est
  plus lisible. »
- **En attente d'essai** : quand l'app bar est masquée, le **nom de la classe** et le bouton
  **Renommer** deviennent inaccessibles. Le retour suffit à ne plus être piégé, mais faut-il leur
  trouver une place ?

**Étape 4, non commencée** : marquage des élèves fautifs et feuille de détail au tap. Les décisions
sont prises (rendu par sévérité, fond réquisitionné, genre replié sur un liseré, feuille au tap avec
tous les attributs en clair) et le moteur fournit déjà les identifiants depuis l'étape 1.

**Vérification que je ne peux pas faire** : `kFirstNameMinWidth` (54 dp) reste une estimation
arithmétique côté largeur. Le plafond de hauteur est désormais mesuré, mais pas la largeur réelle
d'un prénom long dans la police du moteur.
