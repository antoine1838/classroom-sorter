/// Éditeur d'une classe : 4 onglets — Salle, Élèves, Règles, Plan.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/plan_issue.dart';
import '../engine/seating_engine.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/room_layouts.dart';
import '../models/rule.dart';
import '../models/student.dart';
import '../widgets/plan_viewport.dart';
import '../widgets/seat_grid.dart';

/// Le contrôle qui ouvre le rapport, quelle que soit la disposition.
const kReportButtonKey = Key('plan-report-button');

/// Le retour affiché à côté des onglets quand l'app bar est masquée.
const kClassBackKey = Key('class-back');

/// La barre fine qui porte le nom de la classe quand l'app bar est masquée.
const kClassNameBarKey = Key('class-name-bar');

/// Les quatre onglets de l'écran, dans l'ordre.
const kClassTabs = <({IconData icon, String label})>[
  (icon: Icons.grid_on, label: 'Salle'),
  (icon: Icons.people_alt_outlined, label: 'Élèves'),
  (icon: Icons.rule, label: 'Règles'),
  (icon: Icons.event_seat, label: 'Plan'),
];

/// Largeur du bouton retour, et respiration minimale autour d'un libellé
/// d'onglet.
const double _kBackButtonWidth = 48;

/// Padding interne d'un [Tab] de chaque côté de son contenu
/// (`kTabLabelPadding` dans le code source de Flutter = 16dp par côté, donc
/// 32 au total). Mesuré en trouvant le seuil réel de clip par test : une
/// première valeur à 16 (un seul côté) faisait basculer le palier trop tard,
/// les libellés larges (« Élèves », « Règles ») restant coupés net alors que
/// le calcul les croyait déjà casés.
const double _kTabLabelBreathing = 32;

/// Vrai si les libellés des onglets tiennent en entier dans [width].
///
/// Mesuré, comme les boutons du plan : tronqués à « Sa », « Élè », « Rè », ils ne
/// renseignent plus personne, et les quatre icônes sont distinctes. Autant
/// rendre cette largeur au nom de la classe.
bool _tabLabelsFit(BuildContext context, double width) {
  final style = Theme.of(context).textTheme.labelLarge;
  var widest = 0.0;
  for (final tab in kClassTabs) {
    final painter = TextPainter(
      text: TextSpan(text: tab.label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    widest = max(widest, painter.width);
  }
  return width >=
      _kBackButtonWidth + kClassTabs.length * (widest + _kTabLabelBreathing);
}

/// Nom de la classe sur une ligne fine, au-dessus des onglets.
///
/// Toute la barre est tappable pour renommer : un [IconButton] fait 48 dp, il ne
/// tiendrait pas dans cette hauteur. La cible devient donc large et basse plutôt
/// que carrée, et le crayon n'est qu'un indice visuel.
///
/// Le nom est centré sur toute la largeur de la barre, pas seulement dans
/// l'espace qui reste après le crayon : une réserve invisible de la même
/// largeur équilibre le crayon de l'autre côté, sans quoi le centrage ne serait
/// que visuel d'un côté et le nom paraîtrait décalé vers la gauche.
class _ClassNameBar extends StatelessWidget {
  const _ClassNameBar({
    required this.state,
    required this.cls,
    required this.onRename,
  });

  final AppState state;
  final ClassGroup cls;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: kClassNameBarKey,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onRename,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              // Réserve invisible de la même largeur que le crayon, pour que le
              // nom se centre sur toute la barre plutôt que sur l'espace qui
              // reste à sa gauche.
              const SizedBox(width: 14),
              Expanded(
                child: ListenableBuilder(
                  listenable: state,
                  builder: (_, _) => Text(
                    cls.name.isEmpty ? 'Classe' : cls.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Même police que les onglets : les onglets Material 3
                    // utilisent titleSmall (vérifié dans tabs.dart).
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quels libellés la barre de commandes du plan peut afficher.
///
/// Trois paliers plutôt que deux : le rapport est secondaire, donc il perd son
/// libellé avant les commandes principales. Sur un téléphone en portrait, cela
/// permet de garder « Régénérer » et « Valider » écrits en clair.
enum _PlanLabels { all, mainOnly, none }

/// Ce qu'un bouton à libellé consomme AUTOUR de son texte : marges internes,
/// icône et son espacement. Le texte, lui, est mesuré — pas estimé.
const double _kButtonOverhead = 66;

/// Largeur d'un bouton réduit à son icône.
const double _kIconMinW = 48;

const double _kPlanBarPadding = 24;
const double _kPlanBarGap = 8;

/// Couleur d'un plan irréprochable, et celle des points perfectibles : ni
/// l'erreur, ni le vert. Reprennent le vert et l'orange déjà employés par les
/// lignes du rapport.
final Color _kSoftColour = Colors.orange.shade700;
const Color _kCleanColour = Colors.green;

/// Largeur qu'occuperait un bouton portant ce libellé.
///
/// Mesurée avec un [TextPainter] plutôt qu'estimée : des minimums au doigt
/// mouillé faisaient basculer les paliers trop tôt, alors qu'il restait
/// visiblement de la place dans les boutons.
double _labelledWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: Theme.of(context).textTheme.labelLarge),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width + _kButtonOverhead;
}

/// Ce que coûte chaque élément de chrome vertical, au-dessus de la grille.
///
/// Il n'y a plus d'app bar : le nom de la classe vit sur sa propre barre fine,
/// permanente, et le retour à gauche des onglets. Une seule disposition à
/// toutes les tailles, et 56 dp rendus à la grille sur TOUS les formats.
const double _kNameBarHeight = 30;
const double _kTabsHeight = 72;
const double _kButtonRowHeight = 64;
const double _kPlanPadding = 24;

/// Hauteur en dessous de laquelle la grille cesse d'être lisible.
const double _kMinGridHeight = 320;

/// Rapport largeur/hauteur à partir duquel la largeur est franchement l'axe
/// abondant, et un rail latéral vaut la peine.
const double _kWideRatio = 1.2;

/// Vrai si les commandes du plan doivent passer dans un rail latéral.
///
/// C'est le seul arbitrage qui reste : le rail échange de la largeur, souvent
/// abondante, contre de la hauteur, souvent rare.
bool planUsesRail(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final insets = MediaQuery.paddingOf(context).vertical;
  final free = size.height -
      insets -
      _kNameBarHeight -
      _kTabsHeight -
      _kButtonRowHeight -
      _kPlanPadding;
  if (free >= _kMinGridHeight) return false;

  // Un rail n'a de sens que si la largeur est l'axe franchement ABONDANT. Dans
  // une fenêtre portrait, c'est elle qui est rare : un rail y volerait
  // précisément la ressource qui manque.
  //
  // La marge de [_kWideRatio] n'est pas décorative : sans elle, une fenêtre
  // presque carrée bascule d'une disposition à l'autre au pixel près, ce qui
  // donne une impression d'arbitraire au redimensionnement.
  return size.width >= size.height * _kWideRatio;
}

/// Vrai si la fenêtre ressemble à un téléphone tourné en paysage — pas juste
/// « plus large que haut », ce qu'une fenêtre de bureau est presque
/// toujours : il faut aussi une hauteur franchement réduite, celle où les
/// boutons virtuels Android (One UI notamment) peuvent réellement se
/// retrouver sur le côté plutôt qu'en bas (voir #11, et la même mise en garde
/// pour [planUsesRail]).
bool _looksLikeLandscapePhone(Size size) =>
    size.width > size.height && size.height < 500;

class ClassEditorScreen extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const ClassEditorScreen({super.key, required this.state, required this.cls});

  /// Les quatre onglets, avec ou sans libellés.
  ///
  /// Sans libellé, un [Tab] fait 46 dp de haut au lieu de 72 : les 26 dp gagnés
  /// paient presque entièrement la barre du nom de classe.
  static TabBar _tabsFor({required bool labels}) => TabBar(
        // Non scrollable : les 4 onglets se répartissent sur toute la largeur de
        // l'écran (adaptatif), sans défilement ni espace vide.
        isScrollable: false,
        tabs: [
          for (final t in kClassTabs)
            labels
                ? Tab(icon: Icon(t.icon), text: t.label)
                // Sans libellé visible, l'icône seule ne dit plus son nom :
                // un Tooltip porte le texte qui vient de disparaître.
                : Tab(icon: Tooltip(message: t.label, child: Icon(t.icon))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Plus d'app bar : une seule disposition à toutes les tailles. Le nom de
    // la classe vit sur sa barre fine, permanente, et le retour à gauche des
    // onglets — l'arrangement retenu après essai. 56 dp rendus à la grille
    // sur tous les formats, y compris le bureau.
    // Plancher = hauteur d'une barre de navigation Android standard. Sur
    // certains Samsung (One UI, boutons transparents), l'inset système remonté
    // par l'OS est nul ou sous-évalué : le SafeArea seul laisse alors le
    // dernier élève sous les boutons logiciels (issue #11). `minimum` ne mord
    // que si l'inset réel est plus petit que lui — un appareil qui remonte un
    // inset correct n'y perd donc rien.
    //
    // Ces boutons suivent la rotation physique de l'écran : en paysage ils se
    // retrouvent sur le bord gauche ou droit, pas en bas — réserver `bottom`
    // dans ce cas ne protège rien et vole en pure perte la hauteur, déjà rare
    // en paysage (constaté : régression du test du Plan en paysage téléphone).
    final navBarMinimum = _looksLikeLandscapePhone(MediaQuery.sizeOf(context))
        ? const EdgeInsets.only(left: 48, right: 48)
        : const EdgeInsets.only(bottom: 48);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          minimum: navBarMinimum,
          child: Column(
            children: [
              _ClassNameBar(
                state: state,
                cls: cls,
                onRename: () => _rename(context),
              ),
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      // BackButton tire son infobulle de
                      // MaterialLocalizations, qui répond en anglais faute de
                      // délégué de localisation configuré pour l'app (aucune
                      // trace de localizationsDelegates dans main.dart — une
                      // vraie localisation FR est un chantier à part, hors
                      // scope ici). On fixe juste ce bouton en français.
                      IconButton(
                        key: kClassBackKey,
                        icon: const BackButtonIcon(),
                        tooltip: 'Retour',
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: _tabsFor(
                          labels:
                              _tabLabelsFit(context, constraints.maxWidth),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => TabBarView(
                    children: [
                      _RoomTab(state: state, cls: cls),
                      _StudentsTab(state: state, cls: cls),
                      _RulesTab(state: state, cls: cls),
                      _PlanTab(state: state, cls: cls),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: cls.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer la classe'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      cls.name = name;
      state.touch();
    }
  }
}

// ---------------------------------------------------------------------------
// Onglet SALLE
// ---------------------------------------------------------------------------

class _RoomTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _RoomTab({required this.state, required this.cls});

  void _resize({int? rows, int? cols}) {
    if (rows != null) cls.room.rows = rows.clamp(1, 15);
    if (cols != null) cls.room.cols = cols.clamp(1, 15);
    // Nettoyer le plan des places devenues hors grille.
    cls.assignment.removeWhere((k, v) {
      final (r, c) = Room.parse(k);
      return !cls.room.isSeat(r, c);
    });
    // Retirer les couloirs et orientations devenus hors grille.
    cls.room.pruneColAisles();
    cls.room.pruneRowAisles();
    cls.room.pruneFacing();
    state.touch();
  }

  /// Ouvre le sélecteur de disposition, demande confirmation si la salle
  /// actuelle porte déjà un plan (la perte peut être totale, contrairement à
  /// un simple -1 rang/colonne), puis remplace la salle et nettoie le plan
  /// des places devenues hors grille — comme le fait déjà [_resize].
  Future<void> _pickLayout(BuildContext context) async {
    final layout = await showDialog<Room>(
      context: context,
      builder: (_) => _RoomLayoutDialog(
        initialRows: cls.room.rows,
        initialCols: cls.room.cols,
      ),
    );
    if (layout == null || !context.mounted) return;

    if (cls.assignment.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remplacer la disposition ?'),
          content: Text(
            '${cls.assignment.length} élève(s) sont placé(s) sur le plan '
            'actuel. Appliquer cette disposition les retirera du plan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    cls.room = layout;
    cls.assignment.removeWhere((k, v) {
      final (r, c) = Room.parse(k);
      return !cls.room.isSeat(r, c);
    });
    state.touch();
  }

  @override
  Widget build(BuildContext context) {
    final room = cls.room;
    final missing = cls.students.length - room.capacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Stepper(
                label: 'Rangs',
                value: room.rows,
                onMinus: () => _resize(rows: room.rows - 1),
                onPlus: () => _resize(rows: room.rows + 1),
              ),
              _Stepper(
                label: 'Colonnes',
                value: room.cols,
                onMinus: () => _resize(cols: room.cols - 1),
                onPlus: () => _resize(cols: room.cols + 1),
              ),
              Chip(
                avatar: const Icon(Icons.event_seat, size: 18),
                label: Text('${room.capacity} places'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickLayout(context),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: const Text('Disposition'),
              ),
            ],
          ),
        ),
        if (missing > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${room.capacity} place(s) pour ${cls.students.length} '
                      'élève(s) — $missing élève(s) ne seront pas placé(s).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Touchez une case vide pour y poser une place, une place pour la '
            'faire tourner. Appui long ou clic droit sur une place pour la '
            'retirer. Touchez l\'espace entre deux cases pour ajouter un '
            'couloir : les élèves de part et d\'autre ne seront plus voisins.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: RoomEditorGrid(room: room, onChanged: state.touch),
          ),
        ),
      ],
    );
  }
}

/// Sélecteur de modèle de disposition : Rangées, U, Îlots, ou une page
/// blanche. Renvoie la [Room] choisie via `Navigator.pop`, ou `null` si
/// annulé — ne modifie jamais la salle en cours, c'est à l'appelant de
/// l'appliquer (voir [_RoomTab._pickLayout]).
class _RoomLayoutDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;
  const _RoomLayoutDialog({required this.initialRows, required this.initialCols});

  @override
  State<_RoomLayoutDialog> createState() => _RoomLayoutDialogState();
}

class _RoomLayoutDialogState extends State<_RoomLayoutDialog> {
  RoomLayoutKind _kind = RoomLayoutKind.rangees;
  int _armDepth = 3;
  bool _doubleArm = false;
  int _islandSize = 4;
  int _islandCount = 3;
  int _islandRows = 1;

  Room _build() => switch (_kind) {
        RoomLayoutKind.rangees => buildRangeesLayout(
            rows: widget.initialRows, cols: widget.initialCols),
        RoomLayoutKind.blanche => buildBlancheLayout(
            rows: widget.initialRows, cols: widget.initialCols),
        RoomLayoutKind.u =>
          buildULayout(armDepth: _armDepth, doubleArm: _doubleArm),
        RoomLayoutKind.ilots => buildIlotsLayout(
            islandSize: _islandSize,
            islandCount: _islandCount,
            islandRows: _islandRows),
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disposition de la salle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<RoomLayoutKind>(
              segments: const [
                ButtonSegment(
                    value: RoomLayoutKind.rangees, label: Text('Rangées')),
                ButtonSegment(value: RoomLayoutKind.u, label: Text('U')),
                ButtonSegment(
                    value: RoomLayoutKind.ilots, label: Text('Îlots')),
                ButtonSegment(
                    value: RoomLayoutKind.blanche, label: Text('Vide')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            switch (_kind) {
              RoomLayoutKind.rangees ||
              RoomLayoutKind.blanche =>
                Text(
                  'Conserve la taille actuelle de la salle '
                  '(${widget.initialRows} × ${widget.initialCols}).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              RoomLayoutKind.u => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stepper(
                      label: 'Profondeur des bras',
                      value: _armDepth,
                      onMinus: () => setState(
                          () => _armDepth = (_armDepth - 1).clamp(1, 10)),
                      onPlus: () => setState(
                          () => _armDepth = (_armDepth + 1).clamp(1, 10)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bras doubles'),
                      value: _doubleArm,
                      onChanged: (v) => setState(() => _doubleArm = v),
                    ),
                  ],
                ),
              RoomLayoutKind.ilots => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 4, label: Text('Tables de 4')),
                        ButtonSegment(value: 6, label: Text('Tables de 6')),
                      ],
                      selected: {_islandSize},
                      onSelectionChanged: (s) =>
                          setState(() => _islandSize = s.first),
                    ),
                    const SizedBox(height: 8),
                    _Stepper(
                      label: 'Nombre d\'îlots par rang',
                      value: _islandCount,
                      onMinus: () => setState(
                          () => _islandCount = (_islandCount - 1).clamp(1, 8)),
                      onPlus: () => setState(
                          () => _islandCount = (_islandCount + 1).clamp(1, 8)),
                    ),
                    const SizedBox(height: 8),
                    _Stepper(
                      label: 'Nombre de rangs d\'îlots',
                      value: _islandRows,
                      onMinus: () => setState(
                          () => _islandRows = (_islandRows - 1).clamp(1, 4)),
                      onPlus: () => setState(
                          () => _islandRows = (_islandRows + 1).clamp(1, 4)),
                    ),
                  ],
                ),
            },
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _build()),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet ÉLÈVES
// ---------------------------------------------------------------------------

// Seuils de largeur de la barre Ajouter/Importer (voir _AddImportToolbar).
// Les métriques réelles de police ne se calculent pas fiablement à la main
// (ni via flutter_test, qui utilise une police de test non représentative) :
// ces valeurs viennent d'essais visuels dans l'app Windows en rétrécissant la
// fenêtre jusqu'au point de casse de « Importer une liste », puis de
// « Import », avec une marge de sécurité.
const double _kToolbarFullLabelMinW = 420; // sous ce seuil : libellés courts
const double _kToolbarShortLabelMinW = 290; // sous ce seuil : icônes seules

/// Barre Ajouter/Importer + bascule de vue, partagée par les deux vues
/// Élèves. Les deux boutons principaux réduisent leur libellé (« Ajouter » →
/// « Ajout », puis icône seule + tooltip) quand la largeur disponible ne
/// suffit plus, pour ne jamais casser le texte en plein mot.
class _AddImportToolbar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final Widget viewToggle;
  const _AddImportToolbar({
    required this.onAdd,
    required this.onImport,
    required this.viewToggle,
  });

  static const _addTooltip = 'Ajouter un élève';
  static const _importTooltip = "Importer une liste d'élèves";

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      if (w < _kToolbarShortLabelMinW) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt),
              tooltip: _addTooltip,
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onImport,
              icon: const Icon(Icons.playlist_add),
              tooltip: _importTooltip,
            ),
            const SizedBox(width: 8),
            viewToggle,
          ],
        );
      }
      final short = w < _kToolbarFullLabelMinW;
      Widget addBtn = FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.person_add_alt),
        label: Text(short ? 'Ajout' : 'Ajouter'),
      );
      Widget importBtn = FilledButton.tonalIcon(
        onPressed: onImport,
        icon: const Icon(Icons.playlist_add),
        label: Text(short ? 'Import' : 'Importer une liste'),
      );
      if (short) {
        addBtn = Tooltip(message: _addTooltip, child: addBtn);
        importBtn = Tooltip(message: _importTooltip, child: importBtn);
      }
      return Row(
        children: [
          Expanded(child: addBtn),
          const SizedBox(width: 8),
          Expanded(child: importBtn),
          const SizedBox(width: 8),
          viewToggle,
        ],
      );
    });
  }
}

const double _kRowH = 48;
const double _kCellW = 40; // largeur max d'une colonne-champ (une icône)
const double _kCellMinW = 24; // largeur min avant de rogner les noms
// Largeur de la barre de boutons sous laquelle les colonnes commencent à se
// comprimer (voir _computeWidths) — alignée sur le seuil « libellés courts »
// de _AddImportToolbar pour que tout se resserre au même moment.
const double _kColShrinkStartW = _kToolbarFullLabelMinW;
const double _kNameW = 172; // largeur de départ de la colonne des noms (avant 1er calcul)
const double _kNameMinW = 98; // largeur min (laisse la place à « Élève » + tri)
const double _kHeaderH = 34;

/// Une valeur possible d'un champ-colonne : rendu (icône ou barre, pour la
/// Taille) et libellé complet affiché dans l'info-bulle de la cellule.
class _AttrValue {
  final String label;
  final IconData? icon;
  /// Hauteur d'une barre dessinée à la place d'une icône (Taille) :
  /// prioritaire sur [icon] quand elle est renseignée.
  final double? barHeight;
  const _AttrValue(this.label, {this.icon, this.barHeight});
}

/// Un champ de la matrice : une seule colonne. Toucher une cellule fait
/// passer à la valeur suivante de [values] (boucle) ; [defaultIndex] est la
/// valeur de repli (affichée en gris, contrairement aux autres en couleur
/// d'accent) et sert d'état initial pour un nouvel élève.
class _AttrField {
  final String label;
  final List<_AttrValue> values;
  final int defaultIndex;
  final int Function(Student) indexOf;
  final void Function(Student, int) setIndex;
  const _AttrField(
      this.label, this.values, this.defaultIndex, this.indexOf, this.setIndex);
}

/// Définition des colonnes de la matrice — une par champ (voir [_AttrField]).
final List<_AttrField> _attrFields = [
  _AttrField(
    'Genre',
    const [
      _AttrValue('Garçon', icon: Icons.male),
      _AttrValue('Fille', icon: Icons.female),
      _AttrValue('Non précisé', icon: Icons.person_outline),
    ],
    2,
    (s) => switch (s.gender) {
      Gender.garcon => 0,
      Gender.fille => 1,
      Gender.autre => 2,
    },
    (s, i) => s.gender = const [Gender.garcon, Gender.fille, Gender.autre][i],
  ),
  _AttrField(
    'Niveau',
    const [
      _AttrValue('Faible', icon: Icons.arrow_downward),
      _AttrValue('Moyen', icon: Icons.remove),
      _AttrValue('Fort', icon: Icons.arrow_upward),
    ],
    1,
    (s) => switch (s.level) {
      Level.faible => 0,
      Level.moyen => 1,
      Level.fort => 2,
    },
    (s, i) => s.level = const [Level.faible, Level.moyen, Level.fort][i],
  ),
  _AttrField(
    'Énergie',
    const [
      _AttrValue('Calme', icon: Icons.self_improvement),
      _AttrValue('Modéré', icon: Icons.horizontal_rule),
      _AttrValue('Agité', icon: Icons.bolt),
    ],
    1,
    (s) => switch (s.energy) {
      Energy.calme => 0,
      Energy.modere => 1,
      Energy.agite => 2,
    },
    (s, i) => s.energy = const [Energy.calme, Energy.modere, Energy.agite][i],
  ),
  _AttrField(
    'Taille',
    const [
      _AttrValue('Petit', barHeight: 8),
      _AttrValue('Moyen', barHeight: 14),
      _AttrValue('Grand', barHeight: 20),
    ],
    1,
    (s) => switch (s.size) {
      StudentSize.petit => 0,
      StudentSize.moyen => 1,
      StudentSize.grand => 2,
    },
    (s, i) => s.size =
        const [StudentSize.petit, StudentSize.moyen, StudentSize.grand][i],
  ),
  _AttrField(
    'Vue',
    const [
      _AttrValue('Bonne vue', icon: Icons.visibility),
      _AttrValue('Mauvaise vue (objectif : rapprocher du tableau)',
          icon: Icons.visibility_off),
    ],
    0,
    (s) => s.poorEyesight ? 1 : 0,
    (s, i) => s.poorEyesight = i == 1,
  ),
];

/// Bascule entre les deux vues de l'onglet Élèves selon le réglage global
/// [AppState.studentsViewMode] (choisi via le bouton bascule de chaque vue,
/// ou depuis l'écran Réglages).
class _StudentsTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _StudentsTab({required this.state, required this.cls});

  @override
  Widget build(BuildContext context) {
    return switch (state.studentsViewMode) {
      StudentsViewMode.complete =>
        _StudentsTabComplete(state: state, cls: cls),
      StudentsViewMode.compact => _StudentsTabCompact(state: state, cls: cls),
    };
  }
}

/// Vue « Compacte » : une colonne par attribut, tap pour faire défiler ses
/// valeurs (boucle). Voir aussi [_StudentsTabComplete] pour la vue « Complète ».
class _StudentsTabCompact extends StatefulWidget {
  final AppState state;
  final ClassGroup cls;
  const _StudentsTabCompact({required this.state, required this.cls});

  @override
  State<_StudentsTabCompact> createState() => _StudentsTabCompactState();
}

/// Comportement commun aux deux vues de l'onglet Élèves (Compacte et
/// Complète) : défilement horizontal synchronisé, tri par nom, colonne des
/// noms, ajout/édition/suppression/import. Chaque vue ne fournit que ce qui
/// diffère réellement : le calcul des largeurs de colonnes et la
/// construction de l'en-tête / des cellules de valeur.
mixin _StudentsMatrixMixin<T extends StatefulWidget> on State<T> {
  final ScrollController _vBody = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncing = false;
  bool _sortByName = false;
  double _nameW = _kNameW;

  AppState get state;
  ClassGroup get cls;
  String get _instructions;
  Widget get _viewToggle;
  void _computeWidths(double maxWidth);
  Widget _buildHeader(ColorScheme cs);
  Widget _buildAttrRow(ColorScheme cs, Student s, int i);

  @override
  void initState() {
    super.initState();
    _hHeader.addListener(() => _sync(_hHeader, _hBody));
    _hBody.addListener(() => _sync(_hBody, _hHeader));
  }

  /// Garde l'en-tête et le corps alignés lors du défilement horizontal.
  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) return;
    if ((from.offset - to.offset).abs() < 0.5) return;
    _syncing = true;
    to.jumpTo(from.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _vBody.dispose();
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _AddImportToolbar(
            onAdd: () => _editStudent(context),
            onImport: () => _importList(context),
            viewToggle: _viewToggle,
          ),
        ),
        Expanded(
          child: cls.students.isEmpty
              ? const Center(child: Text('Aucun élève. Ajoutez-en un !'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _computeWidths(constraints.maxWidth);
                    return _buildMatrix(cs);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMatrix(ColorScheme cs) {
    final students = _orderedStudents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            _instructions,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _buildHeader(cs),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _vBody,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNameColumn(cs, students),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hBody,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < students.length; i++)
                          _buildAttrRow(cs, students[i], i),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Student> _orderedStudents() {
    if (!_sortByName) return cls.students;
    return [...cls.students]..sort(compareStudentsByName);
  }

  /// Cellule d'en-tête de la colonne des noms : nom de tri + icône. Partagée
  /// par les deux vues, qui l'insèrent chacune dans leur propre en-tête
  /// (largeur de ligne différente selon le nombre de rangées d'en-tête).
  Widget _buildNameHeaderCell(ColorScheme cs, TextStyle? style) {
    return Container(
      width: _nameW,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Tooltip(
        message: _sortByName
            ? 'Trié par nom (A→Z) — toucher pour revenir à l\'ordre d\'ajout'
            : 'Toucher pour trier par nom (A→Z)',
        child: InkWell(
          onTap: () => setState(() => _sortByName = !_sortByName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Élève', style: style),
                  const SizedBox(width: 4),
                  Icon(Icons.sort_by_alpha,
                      size: 16,
                      color: _sortByName ? cs.primary : cs.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameColumn(ColorScheme cs, List<Student> students) {
    return Container(
      width: _nameW,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < students.length; i++)
            _buildNameCell(cs, students[i], i),
        ],
      ),
    );
  }

  Widget _buildNameCell(ColorScheme cs, Student s, int i) {
    return Container(
      height: _kRowH,
      color: _rowColor(cs, i),
      child: InkWell(
        onTap: () => _editStudent(context, existing: s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(s.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              if (s.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: s.notes,
                    child: Icon(Icons.sticky_note_2_outlined,
                        size: 15, color: cs.outline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vSep(ColorScheme cs) => Container(width: 1, color: cs.outlineVariant);

  Color? _rowColor(ColorScheme cs, int i) =>
      i.isEven ? null : cs.surfaceContainerHighest.withValues(alpha: 0.4);

  // -------------------------------------------------------------------------
  // Ajout / édition / suppression / import
  // -------------------------------------------------------------------------

  Future<void> _editStudent(BuildContext context, {Student? existing}) async {
    final initial = existing ?? Student(id: newId());
    final result = await showDialog<Student>(
      context: context,
      builder: (_) => _StudentFormDialog(
        initial: initial,
        onDelete: existing == null ? null : () => _deleteStudent(existing),
      ),
    );
    if (result == null) return;
    if (existing == null) {
      cls.students.add(result);
    } else {
      existing
        ..firstName = result.firstName
        ..lastName = result.lastName
        ..gender = result.gender
        ..level = result.level
        ..energy = result.energy
        ..size = result.size
        ..poorEyesight = result.poorEyesight
        ..notes = result.notes;
    }
    state.touch();
  }

  void _deleteStudent(Student s) {
    cls.purgeStudent(s.id);
    cls.students.remove(s);
    state.touch();
  }

  Future<void> _importList(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importer des élèves'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Un élève par ligne, format « Prénom Nom ».'),
            Text(
              'Prénom composé ? Reliez-le par un tiret (ex. Paul-Henri Dupond).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 8,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Camille Durand\nSami Ben Ali\n…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Importer')),
        ],
      ),
    );
    if (text == null) return;
    var count = 0;
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final parts = t.split(RegExp(r'\s+'));
      final first = parts.first;
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      cls.students.add(Student(id: newId(), firstName: first, lastName: last));
      count++;
    }
    if (count > 0) state.touch();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count élève(s) importé(s).')),
      );
    }
  }
}

class _StudentsTabCompactState extends State<_StudentsTabCompact>
    with _StudentsMatrixMixin<_StudentsTabCompact> {
  // Largeurs adaptatives de la matrice, recalculées à chaque build selon la
  // largeur disponible (voir _computeWidths). Une largeur par colonne (pas
  // une seule partagée) : voir la doc de _computeWidths.
  List<double> _colWidths = List.filled(_attrFields.length, _kCellW);

  @override
  AppState get state => widget.state;
  @override
  ClassGroup get cls => widget.cls;

  @override
  String get _instructions =>
      'Touchez une case pour faire défiler ses valeurs. Touchez le nom '
      'd\'un élève pour le renommer, ajouter une note ou le supprimer. '
      'Touchez l\'en-tête « Élève » pour trier par nom.';

  @override
  Widget get _viewToggle => IconButton.outlined(
        onPressed: () =>
            state.setStudentsViewMode(StudentsViewMode.complete),
        icon: const Icon(Icons.table_rows_outlined),
        tooltip: 'Passer à la vue complète',
      );

  /// Largeur minimale d'une colonne : juste assez pour son libellé complet
  /// (+ la marge horizontale de _headerCells), sans jamais descendre sous
  /// [_kCellMinW] ni dépasser [_kCellW]. Mesurée via TextPainter (fiable ici
  /// car on est dans l'app réelle, pas dans flutter_test qui substitue une
  /// police de test non représentative).
  double _minColWidth(String label, TextStyle? style) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return (tp.width + 4).clamp(_kCellMinW, _kCellW);
  }

  /// Sous [_kColShrinkStartW] (aligné sur le seuil « libellés courts » de la
  /// barre Ajouter/Importer, pour que tout se resserre ensemble dès le
  /// palier moyen), les colonnes se compriment depuis leur largeur
  /// confortable ([_kCellW]) vers leur propre minimum ([_minColWidth]) — pas
  /// toutes du même facteur : une colonne à libellé court (« Vue ») a plus
  /// de marge qu'une à libellé long (« Niveau », « Énergie »), donc elle
  /// absorbe davantage la compression. Le nom récupère tout l'espace
  /// restant, comme avant.
  @override
  void _computeWidths(double maxWidth) {
    final cols = _attrFields.length;
    final seps = (cols - 1).toDouble(); // séparateurs de 1 px
    final headStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 8.5);
    final minWidths = [
      for (final f in _attrFields) _minColWidth(f.label, headStyle)
    ];
    if (maxWidth >= _kColShrinkStartW) {
      _colWidths = List.filled(cols, _kCellW);
    } else {
      final totalMin = minWidths.fold<double>(0, (a, b) => a + b);
      final totalSlack = cols * _kCellW - totalMin;
      final floorWidth = totalMin + _kNameMinW + seps;
      final s = totalSlack <= 0
          ? 0.0
          : ((maxWidth - floorWidth) / (_kColShrinkStartW - floorWidth))
              .clamp(0.0, 1.0);
      _colWidths = [for (final m in minWidths) m + (_kCellW - m) * s];
    }
    final colsTotal = _colWidths.fold<double>(0, (a, b) => a + b);
    _nameW =
        (maxWidth - (colsTotal + seps)).clamp(_kNameMinW, double.infinity);
  }

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  @override
  Widget _buildHeader(ColorScheme cs) {
    final headStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return SizedBox(
      height: _kHeaderH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNameHeaderCell(cs, headStyle),
          Expanded(
            child: SingleChildScrollView(
              controller: _hHeader,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _headerCells(cs, headStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _headerCells(ColorScheme cs, TextStyle? style) {
    final out = <Widget>[];
    // Taille fixe (pas FittedBox) : un rétrécissement au cas par cas alignait
    // mal « Énergie » (accent + jambage du « g ») par rapport aux libellés
    // sans accent/descendante — une taille uniforme, choisie pour le plus
    // long des libellés, garde tout le monde sur la même ligne de base.
    // Plus petite que la vue Complète : essayé à la même taille, mais
    // « Énergie » dépasse alors la largeur max d'une colonne ([_kCellW]) —
    // le clamp de _minColWidth la tronquait quand même (voir _computeWidths).
    final attrHeadStyle = style?.copyWith(fontSize: 8.5);
    for (var g = 0; g < _attrFields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      final field = _attrFields[g];
      out.add(SizedBox(
        width: _colWidths[g],
        child: Tooltip(
          message: field.values.map((v) => v.label).join(' → '),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                field.label,
                style: attrHeadStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ));
    }
    return out;
  }

  @override
  Widget _buildAttrRow(ColorScheme cs, Student s, int i) {
    final cells = <Widget>[];
    for (var g = 0; g < _attrFields.length; g++) {
      if (g > 0) cells.add(_vSep(cs));
      cells.add(_cycleCell(cs, _attrFields[g], s, _colWidths[g]));
    }
    return Container(
      height: _kRowH,
      color: _rowColor(cs, i),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
    );
  }

  /// Cellule d'un champ : affiche la valeur courante, tap = valeur suivante
  /// (boucle). Couleur d'accent sauf sur la valeur par défaut du champ, en
  /// gris pour rester lisible parmi les valeurs réellement choisies.
  Widget _cycleCell(ColorScheme cs, _AttrField field, Student s, double width) {
    final idx = field.indexOf(s);
    final value = field.values[idx];
    final color = idx == field.defaultIndex ? cs.outlineVariant : cs.primary;
    return SizedBox(
      key: ValueKey('attrCell_${field.label}_${s.id}'),
      width: width,
      child: Tooltip(
        message: value.label,
        child: InkWell(
          onTap: () {
            field.setIndex(s, (idx + 1) % field.values.length);
            state.touch();
          },
          child: Center(
            child: value.barHeight != null
                ? Container(
                    width: 8,
                    height: value.barHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : Icon(value.icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet ÉLÈVES — vue « Complète »
// ---------------------------------------------------------------------------

const double _kCompleteCellW = 32; // largeur max d'une case-valeur
const double _kCompleteCellMinW = 21; // largeur min avant de rogner les noms
const double _kGroupH = 26;
const double _kValueH = 30;

/// Vue « Complète » : une colonne par valeur possible (à cocher), regroupées
/// par attribut — sauf la valeur par défaut du champ
/// ([_AttrField.defaultIndex]), qui n'a pas de colonne dédiée : elle est
/// représentée par « rien n'est cochée ». Cocher une valeur décoche l'ancienne
/// (dans le même groupe) ; recocher la valeur active revient à la valeur par
/// défaut. Mêmes définitions de champs que la vue « Compacte » (voir
/// [_attrFields]), pour qu'un futur ajout d'attribut mette à jour les deux
/// vues d'un coup.
class _StudentsTabComplete extends StatefulWidget {
  final AppState state;
  final ClassGroup cls;
  const _StudentsTabComplete({required this.state, required this.cls});

  @override
  State<_StudentsTabComplete> createState() => _StudentsTabCompleteState();
}

class _StudentsTabCompleteState extends State<_StudentsTabComplete>
    with _StudentsMatrixMixin<_StudentsTabComplete> {
  // Largeur adaptative des cases-valeurs, recalculée à chaque build selon la
  // largeur disponible (voir _computeWidths).
  double _cellW = _kCompleteCellW;

  @override
  AppState get state => widget.state;
  @override
  ClassGroup get cls => widget.cls;

  @override
  String get _instructions =>
      'Touchez une case pour cocher/décocher. Touchez le nom d\'un élève '
      'pour le renommer, ajouter une note ou le supprimer. Touchez '
      'l\'en-tête « Élève » pour trier par nom.';

  @override
  Widget get _viewToggle => IconButton.outlined(
        onPressed: () => state.setStudentsViewMode(StudentsViewMode.compact),
        icon: const Icon(Icons.view_week_outlined),
        tooltip: 'Passer à la vue compacte',
      );

  /// Les cases-valeurs gardent leur largeur confortable ([_kCompleteCellW])
  /// tant que la place ne manque pas ; sinon elles se compriment jusqu'à
  /// [_kCompleteCellMinW] pour protéger la largeur minimale du nom
  /// ([_kNameMinW]). Dans tous les cas, la colonne des noms récupère tout
  /// l'espace restant (comme la vue Compacte) : elle ne reste jamais figée à
  /// une largeur fixe pendant qu'un vide s'affiche après la dernière colonne.
  @override
  void _computeWidths(double maxWidth) {
    // -1 par champ : la valeur par défaut (neutre) n'a pas de colonne dédiée,
    // elle est représentée par « rien n'est cochée » (voir _valueHeaderCells).
    final cols = _attrFields.fold<int>(0, (n, f) => n + f.values.length - 1);
    final seps = (_attrFields.length - 1).toDouble(); // séparateurs de 1 px
    var cellW = _kCompleteCellW;
    if (maxWidth - (cellW * cols + seps) < _kNameMinW) {
      cellW = ((maxWidth - _kNameMinW - seps) / cols)
          .clamp(_kCompleteCellMinW, _kCompleteCellW);
    }
    _cellW = cellW;
    _nameW = (maxWidth - (cellW * cols + seps)).clamp(_kNameMinW, double.infinity);
  }

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  @override
  Widget _buildHeader(ColorScheme cs) {
    final headStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return SizedBox(
      height: _kGroupH + _kValueH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNameHeaderCell(cs, headStyle),
          Expanded(
            child: SingleChildScrollView(
              controller: _hHeader,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _kGroupH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _groupHeaderCells(cs, headStyle),
                    ),
                  ),
                  SizedBox(
                    height: _kValueH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _valueHeaderCells(cs, headStyle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _groupHeaderCells(ColorScheme cs, TextStyle? style) {
    final out = <Widget>[];
    for (var g = 0; g < _attrFields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      // -1 : pas de colonne pour la valeur par défaut du champ.
      out.add(SizedBox(
        width: (_attrFields[g].values.length - 1) * _cellW,
        child: Center(
          child: Text(_attrFields[g].label,
              style: style, overflow: TextOverflow.ellipsis),
        ),
      ));
    }
    return out;
  }

  List<Widget> _valueHeaderCells(ColorScheme cs, TextStyle? style) {
    final out = <Widget>[];
    for (var g = 0; g < _attrFields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      final field = _attrFields[g];
      for (var k = 0; k < field.values.length; k++) {
        if (k == field.defaultIndex) continue;
        final v = field.values[k];
        out.add(SizedBox(
          width: _cellW,
          child: Center(
            child: Tooltip(
              message: v.label,
              child: v.barHeight != null
                  ? Container(
                      width: 8,
                      height: v.barHeight,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : Icon(v.icon, size: 18),
            ),
          ),
        ));
      }
    }
    return out;
  }

  @override
  Widget _buildAttrRow(ColorScheme cs, Student s, int i) {
    final cells = <Widget>[];
    for (var g = 0; g < _attrFields.length; g++) {
      if (g > 0) cells.add(_vSep(cs));
      final field = _attrFields[g];
      final active = field.indexOf(s);
      for (var k = 0; k < field.values.length; k++) {
        if (k == field.defaultIndex) continue;
        cells.add(_checkCell(
          cs,
          key: ValueKey('completeCell_${field.label}_${field.values[k].label}_${s.id}'),
          on: active == k,
          onTap: () {
            field.setIndex(s, active == k ? field.defaultIndex : k);
            state.touch();
          },
        ));
      }
    }
    return Container(
      height: _kRowH,
      color: _rowColor(cs, i),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
    );
  }

  Widget _checkCell(ColorScheme cs,
      {required Key key, required bool on, required VoidCallback onTap}) {
    return SizedBox(
      key: key,
      width: _cellW,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(
            on ? Icons.check_box : Icons.check_box_outline_blank,
            color: on ? cs.primary : cs.outlineVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _StudentFormDialog extends StatefulWidget {
  final Student initial;
  final VoidCallback? onDelete;
  const _StudentFormDialog({required this.initial, this.onDelete});

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  late final TextEditingController _first =
      TextEditingController(text: widget.initial.firstName);
  late final TextEditingController _last =
      TextEditingController(text: widget.initial.lastName);
  late final TextEditingController _notes =
      TextEditingController(text: widget.initial.notes);
  late Gender _gender = widget.initial.gender;
  late Level _level = widget.initial.level;
  late Energy _energy = widget.initial.energy;
  late StudentSize _size = widget.initial.size;
  late bool _poorEyesight = widget.initial.poorEyesight;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet élève ?'),
        content: Text(
            '« ${widget.initial.fullName} » sera retiré de la classe, ainsi '
            'que ses règles et sa place dans le plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context); // ferme le formulaire sans enregistrer
      widget.onDelete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.onDelete == null;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(isNew ? 'Nouvel élève' : "Modifier l'élève")),
          if (!isNew)
            IconButton(
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _first,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Gender>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Genre'),
              items: [
                for (final g in Gender.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Level>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Niveau'),
              items: [
                for (final l in Level.values)
                  DropdownMenuItem(value: l, child: Text(l.label)),
              ],
              onChanged: (v) => setState(() => _level = v ?? _level),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Energy>(
              initialValue: _energy,
              decoration: const InputDecoration(labelText: 'Énergie'),
              items: [
                for (final t in Energy.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _energy = v ?? _energy),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StudentSize>(
              initialValue: _size,
              decoration: const InputDecoration(labelText: 'Taille'),
              items: [
                for (final t in StudentSize.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _size = v ?? _size),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mauvaise vue'),
              subtitle:
                  const Text('À rapprocher du tableau (objectif d\'équilibre)'),
              value: _poorEyesight,
              onChanged: (v) => setState(() => _poorEyesight = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (facultatif)',
                hintText: 'Ex. lunettes, tutorat…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            Student(
              id: widget.initial.id,
              firstName: _first.text.trim(),
              lastName: _last.text.trim(),
              gender: _gender,
              level: _level,
              energy: _energy,
              size: _size,
              poorEyesight: _poorEyesight,
              notes: _notes.text.trim(),
            ),
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet RÈGLES
// ---------------------------------------------------------------------------

class _RulesTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _RulesTab({required this.state, required this.cls});

  String _describe(Rule r) {
    final a = cls.studentById(r.studentAId)?.fullName ?? '?';
    final b = cls.studentById(r.studentBId)?.fullName ?? '?';
    final base = switch (r.type) {
      RuleType.fixedSeat =>
        '$a → place ligne ${(r.seatRow ?? 0) + 1}, colonne ${(r.seatCol ?? 0) + 1}',
      RuleType.frontZone => '$a doit être à ${r.frontRows} rang(s) du tableau',
      RuleType.separate => 'Séparer $a et $b',
      RuleType.keepTogether => 'Rapprocher $a et $b',
    };
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text('Objectifs d\'équilibre',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text('Appliqués à toute la classe (préférences).',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.diversity_3),
                title: const Text('Mixer filles / garçons'),
                subtitle: const Text('Éviter les voisins de même genre'),
                value: cls.balance.mixGender,
                onChanged: (v) {
                  cls.balance.mixGender = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.swap_vert),
                title: const Text('Mélanger les niveaux'),
                subtitle:
                    const Text('Ne pas créer 2 voisins Faibles ni 2 voisins Forts'),
                value: cls.balance.mixLevel,
                onChanged: (v) {
                  cls.balance.mixLevel = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bolt),
                title: const Text('Séparer les élèves agités'),
                subtitle: const Text('Éviter les voisins agités'),
                value: cls.balance.separateAgites,
                onChanged: (v) {
                  cls.balance.separateAgites = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('Rapprocher du tableau'),
                subtitle:
                    const Text('Placer les élèves à mauvaise vue dans la moitié avant'),
                value: cls.balance.frontForPoorEyesight,
                onChanged: (v) {
                  cls.balance.frontForPoorEyesight = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.height),
                title: const Text('Éviter qu\'un grand gêne la vue d\'un petit'),
                subtitle: const Text(
                    'Un élève grand ne doit pas bloquer la vue de celui placé juste plus près du tableau — devant, ou à côté sur un bras de U'),
                value: cls.balance.avoidTallInFrontOfShort,
                onChanged: (v) {
                  cls.balance.avoidTallInFrontOfShort = v;
                  state.touch();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Règles', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: cls.students.isEmpty
                  ? null
                  : () => _addRule(context),
              icon: const Icon(Icons.add),
              label: const Text('Règle'),
            ),
          ],
        ),
        if (cls.students.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Ajoutez d\'abord des élèves pour créer des règles.'),
          ),
        if (cls.rules.isEmpty && cls.students.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucune règle. Le placement sera libre (aléatoire).'),
          ),
        for (final r in cls.rules)
          Card(
            child: ListTile(
              leading: Icon(
                r.hard ? Icons.lock : Icons.tune,
                color: r.hard ? Colors.red.shade400 : Colors.orange.shade600,
              ),
              title: Text(_describe(r)),
              subtitle: Text('${r.type.label} · '
                  '${r.hard ? 'Obligatoire' : 'Préférence'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  cls.rules.remove(r);
                  state.touch();
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addRule(BuildContext context) async {
    final rule = await showDialog<Rule>(
      context: context,
      builder: (_) => _RuleFormDialog(cls: cls),
    );
    if (rule == null) return;
    cls.rules.add(rule);
    state.touch();
  }
}

class _RuleFormDialog extends StatefulWidget {
  final ClassGroup cls;
  const _RuleFormDialog({required this.cls});

  @override
  State<_RuleFormDialog> createState() => _RuleFormDialogState();
}

class _RuleFormDialogState extends State<_RuleFormDialog> {
  RuleType _type = RuleType.separate;
  String? _studentA;
  String? _studentB;
  int _row = 0;
  int _col = 0;
  int _frontRows = 1;
  bool _hard = true;

  List<Student> _sortedStudents() =>
      [...widget.cls.students]..sort(compareStudentsByName);

  @override
  void initState() {
    super.initState();
    final students = _sortedStudents();
    _studentA = students.isNotEmpty ? students.first.id : null;
    _studentB = students.length > 1 ? students[1].id : null;
  }

  @override
  Widget build(BuildContext context) {
    final students = _sortedStudents();
    final room = widget.cls.room;

    List<DropdownMenuItem<String>> studentItems() => [
          for (final s in students)
            DropdownMenuItem(value: s.id, child: Text(s.fullName)),
        ];

    return AlertDialog(
      title: const Text('Nouvelle règle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RuleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type de règle'),
              items: [
                for (final t in RuleType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_type.description,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _studentA,
              decoration: const InputDecoration(labelText: 'Élève'),
              items: studentItems(),
              onChanged: (v) => setState(() => _studentA = v),
            ),
            if (_type.needsSecondStudent) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _studentB,
                decoration: const InputDecoration(labelText: 'Deuxième élève'),
                items: studentItems(),
                onChanged: (v) => setState(() => _studentB = v),
              ),
            ],
            if (_type == RuleType.fixedSeat) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _row.clamp(0, room.rows - 1),
                      decoration: const InputDecoration(labelText: 'Rang'),
                      items: [
                        for (var r = 0; r < room.rows; r++)
                          DropdownMenuItem(value: r, child: Text('Rang ${r + 1}')),
                      ],
                      onChanged: (v) => setState(() => _row = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _col.clamp(0, room.cols - 1),
                      decoration: const InputDecoration(labelText: 'Colonne'),
                      items: [
                        for (var c = 0; c < room.cols; c++)
                          DropdownMenuItem(
                              value: c, child: Text('Colonne ${c + 1}')),
                      ],
                      onChanged: (v) => setState(() => _col = v ?? 0),
                    ),
                  ),
                ],
              ),
            ],
            if (_type == RuleType.frontZone) ...[
              const SizedBox(height: 12),
              _Stepper(
                label: 'Rangs du tableau',
                value: _frontRows,
                onMinus: () =>
                    setState(() => _frontRows = (_frontRows - 1).clamp(1, room.rows)),
                onPlus: () =>
                    setState(() => _frontRows = (_frontRows + 1).clamp(1, room.rows)),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoire'),
              subtitle: Text(_hard
                  ? 'Doit absolument être respectée'
                  : 'Simple préférence à optimiser'),
              value: _hard,
              onChanged: (v) => setState(() => _hard = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_studentA == null) return;
    if (_type.needsSecondStudent) {
      if (_studentB == null || _studentB == _studentA) {
        _snack(context, 'Choisissez deux élèves différents.');
        return;
      }
    }
    if (_type == RuleType.fixedSeat && !widget.cls.room.isSeat(_row, _col)) {
      _snack(context, 'Cette place est désactivée (allée). Choisissez-en une autre.');
      return;
    }
    Navigator.pop(
      context,
      Rule(
        id: newId(),
        type: _type,
        studentAId: _studentA!,
        studentBId: _type.needsSecondStudent ? _studentB : null,
        seatRow: _type == RuleType.fixedSeat ? _row : null,
        seatCol: _type == RuleType.fixedSeat ? _col : null,
        frontRows: _frontRows,
        hard: _hard,
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------------------------------------------------------------
// Onglet PLAN
// ---------------------------------------------------------------------------

class _PlanTab extends StatefulWidget {
  final AppState state;
  final ClassGroup cls;
  const _PlanTab({required this.state, required this.cls});

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  PlanResult? _result;

  /// Partagé entre la fenêtre de zoom et les places : un pincement posé sur une
  /// place ne doit pas saisir d'élève (voir PlanViewport).
  final _tracker = PointerTracker();
  final _viewport = GlobalKey<PlanViewportState>();

  ClassGroup get cls => widget.cls;

  void _generate() {
    final result = SeatingEngine(cls).generate();
    cls.assignment = result.assignment;
    widget.state.touch();
    setState(() => _result = result);
  }

  void _validate() {
    final result = SeatingEngine(cls).evaluate();
    setState(() => _result = result);
  }

  void _swap(String seatA, String seatB) {
    final a = cls.assignment[seatA];
    final b = cls.assignment[seatB];
    setState(() {
      if (b == null) {
        cls.assignment.remove(seatA);
      } else {
        cls.assignment[seatA] = b;
      }
      // `a == null` est défensif : seule une place OCCUPÉE est déplaçable
      // (voir PlanGrid, qui n'enveloppe dans un Draggable que les places
      // ayant un élève), donc l'interface ne peut pas produire ce cas. Il
      // reste par symétrie avec `b`, et parce qu'un appelant futur (glisser
      // depuis la liste des non-placés, par exemple) pourrait le produire.
      if (a == null) {
        cls.assignment.remove(seatB);
      } else {
        cls.assignment[seatB] = a;
      }
      _result = null;
    });
    widget.state.touch();
  }

  @override
  Widget build(BuildContext context) {
    final rail = planUsesRail(context);
    final grid = Padding(
      padding: rail
          ? const EdgeInsets.fromLTRB(12, 8, 4, 8)
          : const EdgeInsets.all(12),
      child: _grid(),
    );

    // Les mêmes trois commandes dans les deux cas : seule leur disposition
    // change. En rail, elles ne coûtent plus de hauteur.
    if (rail) {
      return Row(children: [Expanded(child: grid), _controls(vertical: true)]);
    }
    return Column(
      children: [_controls(vertical: false), Expanded(child: grid)],
    );
  }

  Widget _controls({required bool vertical}) {
    if (vertical) return _controlBar(vertical: true, labels: _PlanLabels.none);
    // Même esprit que la barre d'outils de l'onglet Élèves : sous un certain
    // seuil, on ne garde que les icônes. Mais le seuil ne peut pas être une
    // constante — il dépend du NOMBRE de contrôles présents, et c'est le bouton
    // Rapport, arrivé en dernier, qui faisait déborder la rangée.
    return LayoutBuilder(
      builder: (context, constraints) => _controlBar(
        vertical: false,
        labels: _labelsFor(context, constraints.maxWidth),
      ),
    );
  }

  /// Combien de libellés la largeur disponible permet d'afficher.
  ///
  /// Chaque libellé est mesuré, ce qui fait tenir les paliers au plus juste.
  _PlanLabels _labelsFor(BuildContext context, double width) {
    final hasPlan = cls.assignment.isNotEmpty;
    final hasReport = _result != null;

    // Les deux commandes principales sont dans des Expanded : elles se
    // partagent la largeur À PARTS ÉGALES. Ce qu'il faut donc, c'est deux fois
    // le plus LARGE des deux libellés, pas la somme des deux — sinon « Valider »
    // (court) masque le besoin de « Régénérer » (long), qui se coupe alors en
    // plein mot avant que le palier ne bascule.
    var widest = _labelledWidth(context, _generateLabel);
    if (hasPlan) widest = max(widest, _labelledWidth(context, 'Valider'));
    var needMain = widest * (hasPlan ? 2 : 1);
    if (hasPlan) needMain += _kPlanBarGap;

    // needMain compte déjà l'espace entre les deux boutons principaux : il ne
    // reste à prévoir que celui qui précède le rapport.
    final chrome = _kPlanBarPadding + (hasReport ? _kPlanBarGap : 0);

    if (hasReport &&
        width >= needMain + _labelledWidth(context, _reportLabel) + chrome) {
      return _PlanLabels.all;
    }
    if (width >= needMain + (hasReport ? _kIconMinW : 0) + chrome) {
      return _PlanLabels.mainOnly;
    }
    return _PlanLabels.none;
  }

  String get _generateLabel =>
      cls.assignment.isNotEmpty ? 'Régénérer' : 'Générer le plan';

  /// Résumé porté par le bouton du rapport.
  String get _reportLabel {
    final result = _result;
    if (result == null || result.isClean) return 'Rapport';
    // Une contrainte dure prime ; sinon on annonce les points perfectibles,
    // objectifs d'équilibre compris.
    return result.hardCount > 0
        ? '${result.hardCount} problème(s)'
        : '${result.softCount} à améliorer';
  }

  Widget _controlBar({required bool vertical, required _PlanLabels labels}) {
    final mainLabelled = labels != _PlanLabels.none;
    final children = <Widget>[
      _generateControl(labelled: mainLabelled),
      if (cls.assignment.isNotEmpty) _validateControl(labelled: mainLabelled),
      if (_result != null) _reportControl(labelled: labels == _PlanLabels.all),
      if (_viewport.currentState?.isZoomed ?? false) _recenterControl(),
    ];
    return _spacedBar(children, vertical: vertical, labelled: mainLabelled);
  }

  Widget _generateControl({required bool labelled}) {
    final label = _generateLabel;
    final onPressed = cls.students.isEmpty ? null : _generate;
    const icon = Icon(Icons.auto_awesome);
    if (!labelled) {
      return IconButton.filled(
          tooltip: label, onPressed: onPressed, icon: icon);
    }
    return Expanded(
      child: FilledButton.icon(
          onPressed: onPressed, icon: icon, label: Text(label)),
    );
  }

  Widget _validateControl({required bool labelled}) {
    const icon = Icon(Icons.fact_check);
    if (!labelled) {
      return IconButton.filledTonal(
          tooltip: 'Valider', onPressed: _validate, icon: icon);
    }
    return Expanded(
      child: FilledButton.tonalIcon(
          onPressed: _validate, icon: icon, label: const Text('Valider')),
    );
  }

  Widget _recenterControl() => IconButton(
        tooltip: 'Recentrer',
        onPressed: () => setState(() => _viewport.currentState?.recenter()),
        icon: const Icon(Icons.center_focus_strong),
      );

  /// Dispose les contrôles en rangée ou en colonne, séparés d'un espace.
  Widget _spacedBar(List<Widget> controls,
      {required bool vertical, required bool labelled}) {
    final spaced = <Widget>[];
    for (final control in controls) {
      if (spaced.isNotEmpty) {
        spaced.add(
            vertical ? const SizedBox(height: 8) : const SizedBox(width: 8));
      }
      spaced.add(control);
    }

    if (vertical) {
      // Défilable : sur une fenêtre très plate, quatre contrôles de 48 dp
      // demandent plus de hauteur que le rail n'en a. Le `minHeight` conserve
      // le centrage tant que la place suffit.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: spaced),
            ),
          ),
        ),
      );
    }
    // Sans libellé, les contrôles ne s'étirent pas : on les centre plutôt que
    // de les laisser collés au bord.
    final alignment =
        labelled ? MainAxisAlignment.start : MainAxisAlignment.center;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(mainAxisAlignment: alignment, children: spaced),
    );
  }

  /// Le rapport : jamais une carte permanente, mais un contrôle à part entière.
  ///
  /// En rangée, un bouton comme les deux autres — une icône nue à côté de deux
  /// boutons pleins passait tout simplement inaperçue. En rail, l'icône seule
  /// s'impose, faute de largeur, et le compteur passe par un badge.
  Widget _reportControl({required bool labelled}) {
    final result = _result!;
    final cs = Theme.of(context).colorScheme;

    // Trois états, et non deux : un objectif d'équilibre non atteint n'est pas
    // une erreur, mais ce n'est pas « tout est bon » non plus.
    final (IconData icon, Color colour, String tooltip) = switch (result) {
      final r when r.hardCount > 0 => (
          Icons.error_outline,
          cs.error,
          '${r.hardCount} contrainte(s) non respectée(s)',
        ),
      final r when r.softCount > 0 => (
          Icons.warning_amber,
          _kSoftColour,
          '${r.softCount} point(s) perfectible(s)',
        ),
      _ => (
          Icons.check_circle_outline,
          // Explicitement vert : laisser la couleur par défaut donnait une
          // coche grise, indiscernable d'un état neutre.
          _kCleanColour,
          'Toutes les règles et tous les objectifs sont respectés',
        ),
    };

    if (!labelled) {
      return Badge(
        isLabelVisible: !result.isClean,
        backgroundColor: colour,
        label: Text('${result.hardCount + result.softCount}'),
        child: IconButton(
          key: kReportButtonKey,
          tooltip: tooltip,
          onPressed: () => _showReport(context),
          icon: Icon(icon, color: colour),
        ),
      );
    }
    return OutlinedButton.icon(
      key: kReportButtonKey,
      onPressed: () => _showReport(context),
      icon: Icon(icon, color: colour),
      label: Text(_reportLabel),
      style: OutlinedButton.styleFrom(foregroundColor: colour),
    );
  }

  Widget _grid() {
    if (cls.students.isEmpty) {
      return const Center(child: Text('Ajoutez des élèves, puis générez le plan.'));
    }
    if (cls.assignment.isEmpty) {
      return const Center(
        child: Text(
            'Appuyez sur « Générer le plan ».\n'
            'Astuce : ensuite, faites glisser un élève sur une autre place '
            'pour ajuster à la main.',
            textAlign: TextAlign.center),
      );
    }
    // Un doigt déplace un élève, deux doigts zooment et déplacent la vue.
    return PlanViewport(
      key: _viewport,
      tracker: _tracker,
      onScaleChanged: (_) => setState(() {}),
      child: PlanGrid(
        cls: cls,
        onSwap: _swap,
        tracker: _tracker,
        result: _result,
        onTapSeat: (student) => _showSeatDetail(context, student),
      ),
    );
  }

  /// Feuille de détail d'un élève, ouverte au tap sur sa place : nom complet,
  /// tous les attributs en clair (y compris ceux muets sur la case, sinon les
  /// glyphes redeviennent indevinables), les motifs de problème s'il y en a,
  /// et un accès direct au formulaire d'édition existant.
  void _showSeatDetail(BuildContext context, Student student) {
    final issues = _result?.issuesFor(student.id) ?? const <PlanIssue>[];
    showModalBottomSheet<void>(
      context: context,
      // Sans ça, la feuille est plafonnée à 9/16 de la hauteur d'écran : en
      // paysage sur téléphone, ça coupe le contenu avant le bouton du bas.
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.fullName,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _SeatDetailAttributes(student: student),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('À signaler',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final issue in issues)
                  _ReportLine(
                    icon: issue.isHard ? Icons.error : Icons.warning_amber,
                    color: issue.isHard ? Colors.red.shade600 : _kSoftColour,
                    text: issue.label,
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  _editStudentFromPlan(student);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Modifier l\'élève'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Édite un élève depuis le plan : même dialogue que l'onglet Élèves.
  ///
  /// `onDelete` doit être fourni même ici : c'est lui qui dit au dialogue
  /// qu'il édite un élève existant plutôt que d'en créer un (`isNew` s'appuie
  /// sur sa nullité) — l'omettre affichait à tort « Nouvel élève ».
  Future<void> _editStudentFromPlan(Student existing) async {
    final result = await showDialog<Student>(
      context: context,
      builder: (_) => _StudentFormDialog(
        initial: existing,
        onDelete: () => _deleteStudentFromPlan(existing),
      ),
    );
    if (result == null) return;
    setState(() {
      existing
        ..firstName = result.firstName
        ..lastName = result.lastName
        ..gender = result.gender
        ..level = result.level
        ..energy = result.energy
        ..size = result.size
        ..poorEyesight = result.poorEyesight
        ..notes = result.notes;
    });
    widget.state.touch();
  }

  void _deleteStudentFromPlan(Student s) {
    cls.purgeStudent(s.id);
    cls.students.remove(s);
    setState(() => _result = null);
    widget.state.touch();
  }

  /// Le rapport complet, en feuille.
  void _showReport(BuildContext context) {
    final result = _result;
    if (result == null) return;
    final unplaced = result.unplacedStudentIds;
    showModalBottomSheet<void>(
      context: context,
      // Même plafond à 9/16 qui peut couper le rapport en paysage.
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportCard(result: result),
              if (unplaced.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Non placés : ${unplaced.map((id) => cls.studentById(id)?.fullName ?? '?').join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tous les attributs d'un élève, en clair — y compris ceux muets sur la
/// case (Moyen / Modéré / Bonne vue n'affichent aucune icône), sinon les
/// glyphes de la place resteraient indevinables sans cette feuille.
class _SeatDetailAttributes extends StatelessWidget {
  final Student student;
  const _SeatDetailAttributes({required this.student});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      student.gender.label,
      'Niveau : ${student.level.label}',
      'Énergie : ${student.energy.label}',
      'Taille : ${student.size.label}',
      student.poorEyesight ? 'Mauvaise vue' : 'Bonne vue',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ),
        if (student.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(student.notes,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final PlanResult result;
  const _ReportCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.violations.isEmpty && result.warnings.isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ok)
              const _ReportLine(
                icon: Icons.check_circle,
                color: Colors.green,
                text: 'Toutes les règles sont respectées 🎉',
              ),
            for (final v in result.violations)
              _ReportLine(icon: Icons.error, color: Colors.red.shade600, text: v),
            for (final w in result.warnings)
              _ReportLine(
                  icon: Icons.warning_amber,
                  color: Colors.orange.shade700,
                  text: w),
            if (result.balance.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Équilibre', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              for (final n in result.balance)
                _ReportLine(
                  icon: n.ok ? Icons.check_circle_outline : Icons.info_outline,
                  color: n.ok ? Colors.green : Colors.orange.shade700,
                  text: n.label,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ReportLine(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Petit composant : incrément / décrément avec libellé.
// ---------------------------------------------------------------------------

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
                onPressed: onMinus, icon: const Icon(Icons.remove)),
            SizedBox(
              width: 34,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton.outlined(
                onPressed: onPlus, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}
