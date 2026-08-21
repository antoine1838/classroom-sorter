# Dispositions de salle : U, îlots, combinaisons — note de chantier

Issue de référence : [#5 « Davantage de styles de classes »](https://github.com/antoine1838/classroom-sorter/issues/5).

Hors périmètre : [#13](https://github.com/antoine1838/classroom-sorter/issues/13) (export du plan),
[#17](https://github.com/antoine1838/classroom-sorter/issues/17) (débordement vertical préexistant des
onglets Salle et Élèves — ce chantier ajoute des contrôles à l'onglet Salle, il vérifie donc de ne pas
aggraver, sans corriger #17).

Écarté volontairement : le placement libre des tables en x/y avec rotation continue (îlot en biais),
et un tableau plus étroit que le mur ou sur un mur latéral. Voir « Ce qui ferait tomber le raisonnement ».

## Problème

L'issue demande trois choses en trois lignes : salle en U, salle en îlots, combinaisons. Or il n'existe
aujourd'hui **aucune notion de disposition** : `Room` (`lib/models/room.dart`) est une grille
rectangulaire `rows × cols` (max 15×15), plus `disabled` (cases retirées) et `colAisles` (couloirs
verticaux). C'est tout.

Le piège est qu'on peut *dessiner* un U dans ce modèle sans rien changer — et livrer des voisinages
faux. Deux élèves du bras gauche d'un U (colonne 0, rangs 2 et 3) sont côte à côte dans la vraie salle,
mais le moteur les lit « devant/derrière », parce que le voisinage est purement géométrique
(4-orthogonal, `SeatingEngine`, `lib/engine/seating_engine.dart`) et qu'un couloir de colonne ne coupe
que le lien horizontal. Un U décoratif dégraderait donc silencieusement la qualité des plans générés.

## Modèle retenu

Une grille, comme aujourd'hui — elle garantit l'alignement des tables et préserve l'identité `(r, c)`
des places. Deux ajouts :

1. **Une orientation par place** : Nord, Est, Sud, Ouest. `Nord` = vers le tableau, valeur par défaut.
2. **Des couloirs en Y** (`rowAisles`), miroir exact des couloirs en X existants.

Une salle en U s'exprime alors sans structure supplémentaire : bras gauche en colonne 0 orienté Est,
bras droit en dernière colonne orienté Ouest, rangée de devant orientée Nord, centre en cases vides.
Un îlot de 4 est un carré 2×2 dont la colonne gauche est orientée Est et la droite Ouest : les deux
places d'une même colonne partagent l'orientation, et chacune fait face à son vis-à-vis de l'autre
colonne. Autrement dit la disposition en rangées tournée de 90° dans son ensemble — les élèves sont
assis **de côté** par rapport au tableau, ce qui distingue visuellement un îlot d'une rangée. (Le
premier essai orientait les deux places du haut Sud et celles du bas Nord : des vis-à-vis corrects,
mais chaque place tournée sur elle-même plutôt que l'îlot tourné en bloc — corrigé sur retour
d'usage.) Les combinaisons naissent de l'éditeur, il n'y a pas de « disposition composée » à livrer.

### Une piste abandonnée : les blocs

Le premier modèle envisagé faisait de chaque meuble un objet persistant (« ces 12 places forment un
U »), porteur du voisinage et de l'orientation. L'orientation par place **dérive** les mêmes relations
sans introduire d'objets : deux places de même orientation adjacentes le long du regard sont
devant/derrière, adjacentes perpendiculairement au regard elles sont côte à côte, et deux orientations
opposées qui se font face sont en vis-à-vis. Les blocs n'apportaient plus que le déplacement d'un îlot
d'un seul geste — ils ne payaient pas leur prix.

## Trois constats de vérification

Ces constats ont divisé le chantier par deux. Ils sont notés ici parce qu'ils ne se relisent pas dans
le code.

**1. Le rang *est* la distance au tableau.** Sur une grille, avec un tableau qui occupe tout le mur
avant, le point du tableau le plus proche de la place `(r, c)` est `(-1, c)` : la distance vaut `r + 1`
pour toute place, et la direction du regard vers le tableau est « vers les rangs décroissants »
partout. Or `_frontZoneCost` teste déjà `r >= rule.frontRows` et `_poorEyesightBackCount` teste
`r >= _frontHalfRows` (`lib/engine/seating_engine.dart`). Il n'y a **rien à changer** : le champ
`frontRows` de `Rule` garde son sens, sa valeur par défaut et sa clé JSON. Seul son libellé change.

**2. L'interposition latérale est déjà implémentée.** Ce qui gêne la vue, ce n'est pas « être au rang
du dessus », c'est « être entre quelqu'un et le tableau ». Sur le bras d'un U, où les élèves sont
perpendiculaires au tableau, c'est le voisin latéral côté tableau. Or `_tallInFrontOfShortCount`
regarde `(r+1, c)` derrière `(r, c)` — et sur le bras gauche d'un U, la place « un rang plus près du
tableau » **est** ce voisin latéral. Le code le compte déjà. Ce qui était faux, c'était le libellé.

**3. Conséquence : l'orientation ne change aucun plan généré.** Puisque le voisinage naît de
l'adjacence seule (l'orientation ne fait que le *qualifier*) et que la ligne de vue est géométrique,
l'orientation est **purement visuelle**. Elle reste utile — c'est la signature d'un U ou d'îlots, et
c'est ce qui rend l'éditeur lisible — mais l'issue est à ~90 % un chantier d'éditeur et de rendu. Le
seul vrai changement moteur est que les couloirs en Y coupent le voisinage.

## Décisions

| Sujet | Décision |
| --- | --- |
| Catalogue | 3 modèles paramétrés — Rangées, U, Îlots — plus une page blanche |
| « Combinaisons » | Propriété de l'éditeur, rien à livrer sous ce nom |
| Géométrie | Grille avec snap, identité `(r, c)` conservée |
| Persistance | Pas de blocs ; ce qui persiste est l'orientation de chaque place |
| Voisinage | Deux places adjacentes sans couloir sont voisines, quelles que soient leurs orientations |
| Dos à dos, coin de U | Voisines : les élèves sont à moins d'un mètre |
| Vis-à-vis d'îlot | Voisin — c'est le cas d'usage central des îlots |
| Bras opposés d'un U | Non voisins, exprimé par les cases vides du centre |
| Entre meubles séparés | Aucun voisinage : couloirs et cases vides sont le vocabulaire pour le dire |
| Rangées | **Un seul** ensemble de places, pas une disposition par rang, pour préserver le devant/derrière |
| Tableau | Segment occupant tout le mur avant |
| Gêneur | La place adjacente la plus proche du tableau, pas tout le cône de vision |
| Poids | Interposition latérale et frontale au même poids (`balancePenalty = 12.0`) |
| Couloir en Y | Coupe le voisinage, **pas** la ligne de vue : une allée d'un mètre n'empêche pas un grand de masquer le tableau |
| Distance au tableau | Le rang, réinterprété comme rang de distance (voir constat 1) |
| Capacité | Bandeau informatif (« 24 place(s) pour 30 élève(s) »), jamais bloquant |
| Application d'un modèle | À tout moment depuis l'onglet Salle, élagage de `assignment` et des places imposées, avec confirmation si la salle n'est pas vide |
| Libellés | Réécrits en intention pédagogique, pas en géométrie |

## Gestes de l'onglet Salle

Le tap retire aujourd'hui une place. Il change de rôle :

| Cible | Tap | Appui long / clic droit |
| --- | --- | --- |
| Case vide | Poser une place | — |
| Place existante | Tourner (N → E → S → O) | Retirer la place |

La fréquence d'usage décide du geste court, pas l'ancienneté du comportement : tourner est ce qu'on
répète après avoir posé un modèle, retirer est rare et peut vider une affectation. Une rotation par
erreur se voit immédiatement et s'annule en trois taps ; une suppression par erreur fait disparaître un
élève du plan. Le clic droit couvre Windows, où l'appui long à la souris est inconfortable.

Conséquence : le texte d'aide de l'onglet Salle et le test qui tapait l'icône de siège pour retirer une
place (`test/class_editor_screen_test.dart`) changent tous les deux.

## Rendu de l'orientation

`Icons.event_seat_outlined` a son dossier en haut, et le tableau est affiché en bas (vue prof,
`_FittedGrid`). Donc « orientée vers le tableau » = **icône non pivotée**, et les salles existantes ne
demandent aucune rotation : la cohérence est gratuite.

Mais l'icône n'existe que sur les cases de l'onglet Salle et sur les places **libres** de l'onglet Plan
(`_emptySeat`) : une place occupée affiche la carte de l'élève. Sur un plan terminé, la rotation ne se
verrait donc nulle part. D'où un **bord de dossier** — le côté opposé au regard, dessiné plus épais —
sur les cartes d'élève. Le nom ne pivote jamais : c'est l'information qu'on lit en boucle, et le faire
tourner à 90° sur les bras d'un U rendrait le plan pénible à utiliser en classe. Les coins des places
sont déjà pris par les attributs, une flèche y entrerait en concurrence.

Répartition finale des deux repères : l'**icône pivotée** sur les cases de l'onglet Salle et sur les
places libres du Plan ; le **bord de dossier** sur les cartes d'élève du Plan *et* sur les cases de
l'onglet Salle, en plus de l'icône — pour que le même repère existe dans les deux onglets. Les places
libres, elles, n'ont que l'icône : elle porte déjà l'information, sans nom à préserver.

Trois points tranchés à l'essai, tous invisibles dans le diff :

- **Le signe de la rotation.** `Transform.rotate` tourne dans le sens horaire pour un angle positif,
  ce qui affichait les deux bras d'un U dos à dos alors que le modèle les voulait face à face.
  `_facingRotationAngle` négative l'angle ; `buildULayout` n'a pas eu à changer, sa sémantique était
  déjà juste.
- **Le bord de dossier est peint APRÈS le liseré de genre.** Les deux occupent le bord gauche quand
  une place est orientée est. L'ordre inverse (liseré au-dessus) rendait l'orientation invisible sur
  toute carte d'élève genré — précisément là où on veut la lire dans un U ou des îlots. Un décalage
  du dossier vers l'intérieur a été essayé puis abandonné : il mordait sur le prénom.
- **Les couloirs se rendent de la même façon sur les deux axes.** Couloir actif : une grande barre
  continue d'un bord à l'autre des places (`_seatingAreaHeight` pour la verticale,
  `_seatingAreaWidth` — sans la marge de la grille — pour l'horizontale). Pas de couloir, en mode
  éditeur : un repère par place traversée (un par rang pour un couloir de colonne, un par colonne
  pour un couloir de rang). La première version traitait la ligne entière comme un seul bloc d'un
  côté et place par place de l'autre.

## Découpage

**Modèle**

1. `Room` : orientation par place + couloirs de rang. `enum Facing { nord, est, sud, ouest }` (`nord` par
   défaut), stockée en **map creuse** `"r,c" → Facing` pour que le JSON existant se relise sans
   migration et ne grossisse pas. `Set<int> rowAisles` en miroir de `colAisles`
   (`hasRowAisleAfter`, `toggleRowAisle`, `rowAisleBetween`, `pruneRowAisles`). `_resize` élague en plus
   les orientations hors grille et les couloirs de rang. Tests : aller-retour JSON, relecture d'une
   salle d'avant (tout en `nord`, aucun couloir Y).

**Moteur** — le seul commit qui touche la génération

2. Un couloir de rang coupe le voisinage : `!cls.room.rowAisleBetween(r, nr)` à côté du test existant
   sur les colonnes, dans le constructeur de `SeatingEngine`. Plus le test qui fige la divergence
   assumée : couloir en Y ⇒ non voisins, **mais** grand-devant-petit toujours compté.

**Éditeur — onglet Salle**

3. Couloirs de rang tappables. `_FittedGrid` gère déjà les espaces inter-colonnes et un `kRowGap`
   inerte : on lui ajoute un `_rowGap` tappable et un second callback. Les deux grilles affichent les
   couloirs en Y, l'éditeur seul les modifie.
4. Gestes : tap sur case vide = poser, tap sur place = tourner, appui long ou clic droit = retirer.
   Icône pivotée. Une place nouvellement posée naît en `nord`. Texte d'aide réécrit.
5. Les trois modèles et la page blanche : `Rangées(rangs, colonnes, tables de 2)`,
   `U(profondeur des bras, simple/double)`, `Îlots(taille 4 ou 6, nombre)`, `Page blanche` (grille de
   places toutes retirées). Confirmation si la salle n'est pas vide, puis élagage comme `_resize`.
6. Bandeau de capacité, informatif et non bloquant.

**Rendu — onglet Plan**

7. Bord de dossier sur les cartes d'élèves et sur les places libres, icône pivotée là où elle existe.

**Finitions**

8. Libellés : « Éviter qu'un grand gêne la vue d'un petit », « Rapprocher du tableau »,
   « à N rangs du tableau ». Répercuté dans le rapport de plan.
9. Documentation : README (dispositions, gestes de l'onglet Salle) et cette note.

## Vérification

`flutter analyze` et `flutter test` à chaque commit, widget tests à taille téléphone pour les deux
onglets touchés. Pas de reformatage au passage : `dart format` reste un commit dédié. État à la
livraison : 315 tests, `flutter analyze` sans avertissement.

Le rendu ne se vérifie pas en test : il a été relu dans l'app Windows par l'utilisateur, et c'est
cette relecture qui a produit la plupart des correctifs listés ci-dessous — sens de rotation des
bras du U, orientation des îlots, superposition dossier / liseré de genre, symétrie des couloirs.
Les widget tests ont ensuite figé chacun de ces points ; aucun n'aurait été détecté par la suite de
tests telle qu'elle existait avant.

## Écarts entre ce qui était prévu et ce qui a été livré

Les 9 commits ont tous été livrés tels que découpés ci-dessus (5 et 6 regroupés en un seul, la
zone de l'onglet Salle qu'ils touchent étant imbriquée), plus deux commits hors plan : le zoom à la
molette de souris (demandé en cours de route pour faciliter les tests) et la mise à jour de la doc
projet et Play Store.

L'historique ne montre pas les correctifs issus des tests manuels : ils ont été **fondus dans le
commit de la fonctionnalité qu'ils corrigeaient** — convention du projet tant qu'une version n'est
pas publiée, pour garder un commit par intention plutôt qu'une traîne de « corrige X ». C'est
pourquoi les commits « sélecteur de disposition » et « rendu de l'orientation » sont plus gros que
leur description du découpage ne le laisse attendre.

Les écarts sont notés ici parce qu'ils ne se relisent pas dans le diff :

- **Le libellé « Rapprocher du tableau » était déjà pris.** La règle `frontZone` (par élève) devait
  initialement se renommer « Doit être devant » → « Rapprocher du tableau ». En relisant le code, ce
  libellé exact désigne déjà l'objectif d'équilibre `frontForPoorEyesight` (préférence de classe,
  différente d'une règle par élève). Les deux mécanismes sous le même texte auraient été une
  régression de lisibilité, pas une amélioration : `frontZone` a gardé son libellé « Doit être
  devant », seule sa description et les textes qui citaient « rangs » ont été reformulés en distance
  au tableau.
- **« Tables de 2 » pour le modèle Rangées : abandonné.** Le point 5 du découpage prévoyait
  `Rangées(rangs, colonnes, tables de 2)`, c'est-à-dire un couloir toutes les deux colonnes pour
  représenter les pupitres doubles. Non implémenté, et volontairement retiré du périmètre :
  `buildRangeesLayout` produit une grille uniforme sans couloir. Ce n'est pas un oubli cosmétique —
  ces couloirs changeraient le graphe de voisinage, donc les plans générés (sans eux, les places
  d'un rang forment une chaîne de voisins de bout en bout, alors qu'en salle seul le voisin de
  pupitre en est un). Le geste manuel existe déjà pour l'obtenir (toucher l'espace entre deux
  colonnes) : le paramètre n'aurait été qu'un raccourci sur le modèle prérempli, au prix d'un
  contrôle de plus dans le sélecteur. À reprendre si l'usage montre que le geste manuel est trop
  fastidieux.
- **Les générateurs de disposition (`lib/models/room_layouts.dart`) fixent des paramètres non
  discutés en grilling**, par nécessité d'implémentation : le U a un creux central de 3 colonnes
  (`centerGap`, purement esthétique) et des bras de profondeur/largeur réglables ; les Îlots ont une
  taille de table (4 ou 6), un nombre d'îlots par rang et un nombre de rangs d'îlots (`islandRows`,
  ajouté après coup sur retour d'usage — chaque bande de deux rangs séparée de la suivante par un
  couloir de rang). Si l'usage réel demande plus (U asymétrique, îlots de tailles mélangées), ce
  sera une extension de ces fonctions, pas une réécriture.

## Ce qui ferait tomber le raisonnement

Le constat 1 (le rang est la distance au tableau) tient parce que le tableau occupe **tout** le mur
avant. Un tableau plus étroit que le mur, ou sur un mur latéral, rendrait la distance au tableau
réellement euclidienne et demanderait la primitive « distance et direction par place » qui a été
écartée ici. De même, le placement libre en x/y avec rotation continue obligerait à remplacer
l'identité `(r, c)` des places par des identifiants stables : `assignment`, les places imposées, le
JSON sauvegardé, `PlanGrid`, le drag & drop, soit 128 occurrences de coordonnées réparties sur 4
fichiers de `lib/` et 8 fichiers de test. Les deux sont des évolutions possibles, pas des dettes.
