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
2. **Prototype de gestes** sur une branche `experiment/` : mécanisme trouvé et couvert par des tests
   multi-pointeurs ; reste la validation sur appareil. Voir ci-dessous.
3. **Paysage** (#12) : rail, chrome masqué, cases rectangulaires.

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

**Ce que ces tests ne prouvent pas**, et qui reste à valider sur l'appareil : la jitter des doigts, le
décalage réel entre la pose des deux doigts, le rejet de paume, et le seuil de déplacement du système.
Le banc d'essai `lib/prototypes/plan_gestures_prototype.dart` est fait pour ça — il compte à l'écran
les élèves déplacés et les zooms, sur une grille 8×5 réduite comme dans l'app :

```
flutter run -t lib/prototypes/plan_gestures_prototype.dart
```

Critère d'acceptation : sur une vingtaine d'essais, un glissement à un doigt ne zoome jamais et un
pincement à deux doigts ne déplace jamais un élève — en insistant sur le pincement démarré pile sur
une place.

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
