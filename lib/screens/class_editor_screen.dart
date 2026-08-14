/// Éditeur d'une classe : 4 onglets — Salle, Élèves, Règles, Plan.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/seating_engine.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/rule.dart';
import '../models/student.dart';
import '../widgets/seat_grid.dart';

class ClassEditorScreen extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const ClassEditorScreen({super.key, required this.state, required this.cls});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: state,
            builder: (_, _) => Text(cls.name.isEmpty ? 'Classe' : cls.name),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Renommer',
              onPressed: () => _rename(context),
            ),
          ],
          bottom: const TabBar(
            // Non scrollable : les 4 onglets se répartissent sur toute la
            // largeur de l'écran (adaptatif), sans défilement ni espace vide.
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: 'Salle'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Élèves'),
              Tab(icon: Icon(Icons.rule), text: 'Règles'),
              Tab(icon: Icon(Icons.event_seat), text: 'Plan'),
            ],
          ),
        ),
        body: ListenableBuilder(
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
    // Retirer les couloirs devenus hors grille.
    cls.room.pruneColAisles();
    state.touch();
  }

  @override
  Widget build(BuildContext context) {
    final room = cls.room;
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
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Touchez une case pour retirer/remettre une place. '
            'Touchez l\'espace entre deux colonnes pour ajouter un couloir : '
            'les élèves de part et d\'autre ne seront plus voisins.',
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

class _StudentsTabCompactState extends State<_StudentsTabCompact> {
  final ScrollController _vBody = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncing = false;
  bool _sortByName = false;

  // Largeurs adaptatives de la matrice, recalculées à chaque build selon la
  // largeur disponible (voir _computeWidths). Une largeur par colonne (pas
  // une seule partagée) : voir la doc de _computeWidths.
  List<double> _colWidths = List.filled(_attrFields.length, _kCellW);
  double _nameW = _kNameW;

  AppState get state => widget.state;
  ClassGroup get cls => widget.cls;

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
  void _computeWidths(BuildContext context, double maxWidth) {
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
            viewToggle: IconButton.outlined(
              onPressed: () =>
                  state.setStudentsViewMode(StudentsViewMode.complete),
              icon: const Icon(Icons.table_rows_outlined),
              tooltip: 'Passer à la vue complète',
            ),
          ),
        ),
        Expanded(
          child: cls.students.isEmpty
              ? const Center(child: Text('Aucun élève. Ajoutez-en un !'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _computeWidths(context, constraints.maxWidth);
                    return _buildMatrix(cs);
                  },
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  Widget _buildMatrix(ColorScheme cs) {
    final students = _orderedStudents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            'Touchez une case pour faire défiler ses valeurs. Touchez le nom '
            'd\'un élève pour le renommer, ajouter une note ou le supprimer. '
            'Touchez l\'en-tête « Élève » pour trier par nom.',
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
          Container(
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
                        Text('Élève', style: headStyle),
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
          ),
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

  List<Student> _orderedStudents() {
    if (!_sortByName) return cls.students;
    final sorted = [...cls.students];
    sorted.sort((a, b) {
      final byLast =
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      return byLast != 0
          ? byLast
          : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });
    return sorted;
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

class _StudentsTabCompleteState extends State<_StudentsTabComplete> {
  final ScrollController _vBody = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncing = false;
  bool _sortByName = false;

  // Largeurs adaptatives de la matrice, recalculées à chaque build selon la
  // largeur disponible (voir _computeWidths).
  double _cellW = _kCompleteCellW;
  double _nameW = _kNameW;

  AppState get state => widget.state;
  ClassGroup get cls => widget.cls;

  /// Les cases-valeurs gardent leur largeur confortable ([_kCompleteCellW])
  /// tant que la place ne manque pas ; sinon elles se compriment jusqu'à
  /// [_kCompleteCellMinW] pour protéger la largeur minimale du nom
  /// ([_kNameMinW]). Dans tous les cas, la colonne des noms récupère tout
  /// l'espace restant (comme la vue Compacte) : elle ne reste jamais figée à
  /// une largeur fixe pendant qu'un vide s'affiche après la dernière colonne.
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
            viewToggle: IconButton.outlined(
              onPressed: () =>
                  state.setStudentsViewMode(StudentsViewMode.compact),
              icon: const Icon(Icons.view_week_outlined),
              tooltip: 'Passer à la vue compacte',
            ),
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

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  Widget _buildMatrix(ColorScheme cs) {
    final students = _orderedStudents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            'Touchez une case pour cocher/décocher. Touchez le nom d\'un élève '
            'pour le renommer, ajouter une note ou le supprimer. Touchez '
            'l\'en-tête « Élève » pour trier par nom.',
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
          Container(
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
                        Text('Élève', style: headStyle),
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
          ),
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

  List<Student> _orderedStudents() {
    if (!_sortByName) return cls.students;
    final sorted = [...cls.students];
    sorted.sort((a, b) {
      final byLast =
          a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      return byLast != 0
          ? byLast
          : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });
    return sorted;
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
      RuleType.frontZone =>
        '$a doit être dans les ${r.frontRows} premier(s) rang(s)',
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
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('Objectifs d\'équilibre'),
                subtitle: Text('Appliqués à toute la classe (préférences).'),
              ),
              SwitchListTile(
                title: const Text('Mixer filles / garçons'),
                subtitle: const Text('Éviter les voisins de même genre'),
                value: cls.balance.mixGender,
                onChanged: (v) {
                  cls.balance.mixGender = v;
                  state.touch();
                },
              ),
              SwitchListTile(
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
                title: const Text('Séparer les élèves agités'),
                subtitle: const Text('Éviter les voisins agités'),
                value: cls.balance.separateAgites,
                onChanged: (v) {
                  cls.balance.separateAgites = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                title: const Text('Rapprocher du tableau (mauvaise vue)'),
                subtitle:
                    const Text('Placer les élèves à mauvaise vue dans la moitié avant'),
                value: cls.balance.frontForPoorEyesight,
                onChanged: (v) {
                  cls.balance.frontForPoorEyesight = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                title: const Text('Éviter un grand juste devant un petit'),
                subtitle: const Text(
                    'Un élève grand ne doit pas bloquer la vue de celui placé juste derrière'),
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

  @override
  void initState() {
    super.initState();
    final students = widget.cls.students;
    _studentA = students.isNotEmpty ? students.first.id : null;
    _studentB = students.length > 1 ? students[1].id : null;
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.cls.students;
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
                label: 'Premiers rangs',
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
    final hasPlan = cls.assignment.isNotEmpty;
    final unplaced = _result?.unplacedStudentIds ?? const [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: cls.students.isEmpty ? null : _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(hasPlan ? 'Régénérer' : 'Générer le plan'),
                ),
              ),
              if (hasPlan) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _validate,
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Valider'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ReportCard(result: _result!),
          ),
        if (unplaced.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Non placés : ${unplaced.map((id) => cls.studentById(id)?.fullName ?? '?').join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: cls.students.isEmpty
              ? const Center(child: Text('Ajoutez des élèves, puis générez le plan.'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: hasPlan
                      ? PlanGrid(cls: cls, onSwap: _swap)
                      : const Center(
                          child: Text(
                              'Appuyez sur « Générer le plan ».\n'
                              'Astuce : ensuite, faites glisser un élève sur une '
                              'autre place pour ajuster à la main.',
                              textAlign: TextAlign.center),
                        ),
                ),
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
