part of '../class_editor_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < _kToolbarShortLabelMinW) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt),
                tooltip: l10n.addStudent,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onImport,
                icon: const Icon(Icons.playlist_add),
                tooltip: l10n.importStudentList,
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
          label: Text(short ? l10n.addShort : l10n.add),
        );
        Widget importBtn = FilledButton.tonalIcon(
          onPressed: onImport,
          icon: const Icon(Icons.playlist_add),
          label: Text(short ? l10n.importShort : l10n.importStudentList),
        );
        if (short) {
          addBtn = Tooltip(message: l10n.addStudent, child: addBtn);
          importBtn = Tooltip(
            message: l10n.importStudentList,
            child: importBtn,
          );
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
      },
    );
  }
}

const double _kRowH = 48;
const double _kCellW = 40; // largeur max d'une colonne-champ (une icône)
const double _kCellMinW = 24; // largeur min avant de rogner les noms
// Largeur de la barre de boutons sous laquelle les colonnes commencent à se
// comprimer (voir _computeWidths) — alignée sur le seuil « libellés courts »
// de _AddImportToolbar pour que tout se resserre au même moment.
const double _kColShrinkStartW = _kToolbarFullLabelMinW;
const double _kNameW =
    172; // largeur de départ de la colonne des noms (avant 1er calcul)
const double _kNameMinW = 98; // largeur min (laisse la place à « Élève » + tri)
const double _kHeaderH = 34;

/// Une valeur possible d'un champ-colonne : rendu (icône ou barre, pour la
/// Taille) et libellé complet affiché dans l'info-bulle de la cellule.
class _AttrValue {
  final String id;
  final String label;
  final IconData? icon;

  /// Hauteur d'une barre dessinée à la place d'une icône (Taille) :
  /// prioritaire sur [icon] quand elle est renseignée.
  final double? barHeight;
  const _AttrValue(this.id, this.label, {this.icon, this.barHeight});
}

/// Un champ de la matrice : une seule colonne. Toucher une cellule fait
/// passer à la valeur suivante de [values] (boucle) ; [defaultIndex] est la
/// valeur de repli (affichée en gris, contrairement aux autres en couleur
/// d'accent) et sert d'état initial pour un nouvel élève.
class _AttrField {
  final String id;
  final String label;
  final List<_AttrValue> values;
  final int defaultIndex;
  final int Function(Student) indexOf;
  final void Function(Student, int) setIndex;
  const _AttrField(
    this.id,
    this.label,
    this.values,
    this.defaultIndex,
    this.indexOf,
    this.setIndex,
  );
}

/// Définition des colonnes de la matrice — une par champ (voir [_AttrField]).
List<_AttrField> _attrFields(AppLocalizations l10n) => [
  _AttrField(
    'gender',
    l10n.gender,
    [
      _AttrValue('boy', l10n.boy, icon: Icons.male),
      _AttrValue('girl', l10n.girl, icon: Icons.female),
      _AttrValue('unspecified', l10n.unspecified, icon: Icons.person_outline),
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
    'level',
    l10n.level,
    [
      _AttrValue('low', l10n.low, icon: Icons.arrow_downward),
      _AttrValue('medium', l10n.medium, icon: Icons.remove),
      _AttrValue('high', l10n.high, icon: Icons.arrow_upward),
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
    'energy',
    l10n.energy,
    [
      _AttrValue('calm', l10n.calm, icon: Icons.self_improvement),
      _AttrValue('moderate', l10n.moderate, icon: Icons.horizontal_rule),
      _AttrValue('restless', l10n.restless, icon: Icons.bolt),
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
    'size',
    l10n.size,
    [
      _AttrValue('small', l10n.small, barHeight: 8),
      _AttrValue('medium', l10n.medium, barHeight: 14),
      _AttrValue('tall', l10n.tall, barHeight: 20),
    ],
    1,
    (s) => switch (s.size) {
      StudentSize.petit => 0,
      StudentSize.moyen => 1,
      StudentSize.grand => 2,
    },
    (s, i) => s.size = const [
      StudentSize.petit,
      StudentSize.moyen,
      StudentSize.grand,
    ][i],
  ),
  _AttrField(
    'eyesight',
    l10n.eyesight,
    [
      _AttrValue('good', l10n.goodEyesight, icon: Icons.visibility),
      _AttrValue(
        'poor',
        '${l10n.poorEyesight} (${l10n.moveNearBoard})',
        icon: Icons.visibility_off,
      ),
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
      StudentsViewMode.complete => _StudentsTabComplete(state: state, cls: cls),
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
  List<_AttrField> get _fields => _attrFields(_l10n(context));
  ClassGroupOps get _ops => ClassGroupOps(cls, commit: state.touch);
  String get _instructions;
  Widget get _viewToggle;
  void _computeWidths(double maxWidth);
  Widget _buildHeader(ColorScheme cs, {required bool compact});
  double _headerHeightFor(bool compact);
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
              ? Center(child: Text(_l10n(context).noStudents))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _computeWidths(constraints.maxWidth);
                    return _buildMatrix(cs, constraints);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMatrix(ColorScheme cs, BoxConstraints constraints) {
    final students = _orderedStudents();
    final instrStyle = Theme.of(context).textTheme.bodySmall;
    final instrH =
        _wrappedTextHeight(
          context,
          _instructions,
          instrStyle,
          constraints.maxWidth - 24,
        ) +
        8; // + Padding.fromLTRB bas
    const dividerH = 1.0;

    // Dégradation par paliers (#17) : sur fenêtre courte, on sacrifie
    // d'abord les instructions (le moins essentiel), puis, si ça ne suffit
    // toujours pas, le libellé de groupe de l'en-tête (vue Complète — la vue
    // Compacte n'a qu'une seule rangée d'en-tête, déjà minimale).
    var showInstructions = true;
    var fixed = instrH + _headerHeightFor(false) + dividerH;
    if (constraints.maxHeight - fixed < _kMinGridHeight) {
      showInstructions = false;
      fixed = _headerHeightFor(false) + dividerH;
    }
    final compactHeader = constraints.maxHeight - fixed < _kMinGridHeight;

    // Comme pour l'onglet Salle (#17) : le chrome (instructions, en-tête) va
    // dans un sliver ordinaire et le corps du tableau dans un
    // SliverFillRemaining — il occupe tout l'espace restant s'il y en a
    // (comme l'Expanded précédent), et devient un filet de sécurité plutôt
    // qu'un débordement si la fenêtre est trop courte même après les paliers
    // ci-dessus. `hasScrollBody: true` : le corps gère déjà son propre défilement
    // (vertical et horizontal, `_vBody`/`_hBody`).
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showInstructions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(_instructions, style: instrStyle),
                ),
              _buildHeader(cs, compact: compactHeader),
              const Divider(height: 1),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
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
    final l10n = _l10n(context);
    return Container(
      width: _nameW,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: cs.outlineVariant)),
      ),
      child: Tooltip(
        message: _sortByName ? l10n.sortedByName : l10n.sortByName,
        child: InkWell(
          onTap: () => setState(() => _sortByName = !_sortByName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.student, style: style),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sort_by_alpha,
                    size: 16,
                    color: _sortByName ? cs.primary : cs.outline,
                  ),
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
                child: Text(
                  s.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (s.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: s.notes,
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 15,
                      color: cs.outline,
                    ),
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
    _ops.upsertStudent(result, existing: existing);
  }

  void _deleteStudent(Student s) {
    _ops.removeStudent(s);
  }

  Future<void> _importList(BuildContext context) async {
    final l10n = _l10n(context);
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.importStudentsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importStudentsInstructions),
            Text(
              l10n.importStudentsHyphenHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 8,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: l10n.importStudentsExample,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(l10n.import),
          ),
        ],
      ),
    );
    if (text == null) return;
    final count = _ops.importStudentsFromLines(text, newId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n(context).studentsImported(count))),
      );
    }
  }
}

class _StudentsTabCompactState extends State<_StudentsTabCompact>
    with _StudentsMatrixMixin<_StudentsTabCompact> {
  // Largeurs adaptatives de la matrice, recalculées à chaque build selon la
  // largeur disponible (voir _computeWidths). Une largeur par colonne (pas
  // une seule partagée) : voir la doc de _computeWidths.
  List<double> _colWidths = List.filled(5, _kCellW);

  @override
  AppState get state => widget.state;
  @override
  ClassGroup get cls => widget.cls;

  @override
  String get _instructions => _l10n(context).compactInstructions;

  @override
  Widget get _viewToggle => IconButton.outlined(
    onPressed: () => state.setStudentsViewMode(StudentsViewMode.complete),
    icon: const Icon(Icons.table_rows_outlined),
    tooltip: _l10n(context).switchToComplete,
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
    final cols = _fields.length;
    final seps = (cols - 1).toDouble(); // séparateurs de 1 px
    final headStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 8.5,
    );
    final minWidths = [
      for (final f in _fields) _minColWidth(f.label, headStyle),
    ];
    if (maxWidth >= _kColShrinkStartW) {
      _colWidths = List.filled(cols, _kCellW);
    } else {
      final totalMin = minWidths.fold<double>(0, (a, b) => a + b);
      final totalSlack = cols * _kCellW - totalMin;
      final floorWidth = totalMin + _kNameMinW + seps;
      final s = totalSlack <= 0
          ? 0.0
          : ((maxWidth - floorWidth) / (_kColShrinkStartW - floorWidth)).clamp(
              0.0,
              1.0,
            );
      _colWidths = [for (final m in minWidths) m + (_kCellW - m) * s];
    }
    final colsTotal = _colWidths.fold<double>(0, (a, b) => a + b);
    _nameW = (maxWidth - (colsTotal + seps)).clamp(_kNameMinW, double.infinity);
  }

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  // Une seule rangée d'en-tête, déjà minimale (_kHeaderH = 34) : rien à
  // sacrifier de plus au palier 2, contrairement à la vue Complète.
  @override
  double _headerHeightFor(bool compact) => _kHeaderH;

  @override
  Widget _buildHeader(ColorScheme cs, {required bool compact}) {
    final headStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
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
    for (var g = 0; g < _fields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      final field = _fields[g];
      out.add(
        SizedBox(
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
        ),
      );
    }
    return out;
  }

  @override
  Widget _buildAttrRow(ColorScheme cs, Student s, int i) {
    final cells = <Widget>[];
    for (var g = 0; g < _fields.length; g++) {
      if (g > 0) cells.add(_vSep(cs));
      cells.add(_cycleCell(cs, _fields[g], s, _colWidths[g]));
    }
    return Container(
      height: _kRowH,
      color: _rowColor(cs, i),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
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
      key: ValueKey('attrCell_${field.id}_${s.id}'),
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
  String get _instructions => _l10n(context).completeInstructions;

  @override
  Widget get _viewToggle => IconButton.outlined(
    onPressed: () => state.setStudentsViewMode(StudentsViewMode.compact),
    icon: const Icon(Icons.view_week_outlined),
    tooltip: _l10n(context).switchToCompact,
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
    final cols = _fields.fold<int>(0, (n, f) => n + f.values.length - 1);
    final seps = (_fields.length - 1).toDouble(); // séparateurs de 1 px
    var cellW = _kCompleteCellW;
    if (maxWidth - (cellW * cols + seps) < _kNameMinW) {
      cellW = ((maxWidth - _kNameMinW - seps) / cols).clamp(
        _kCompleteCellMinW,
        _kCompleteCellW,
      );
    }
    _cellW = cellW;
    _nameW = (maxWidth - (cellW * cols + seps)).clamp(
      _kNameMinW,
      double.infinity,
    );
  }

  // -------------------------------------------------------------------------
  // Matrice élèves × attributs
  // -------------------------------------------------------------------------

  @override
  double _headerHeightFor(bool compact) =>
      compact ? _kValueH : _kGroupH + _kValueH;

  @override
  Widget _buildHeader(ColorScheme cs, {required bool compact}) {
    final headStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
    return SizedBox(
      height: _headerHeightFor(compact),
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
                  // Deuxième palier de dégradation (#17) : le libellé de
                  // groupe (« Vue », « Taille »…) cède le premier — la
                  // rangée de valeurs, elle, reste seule à porter
                  // l'information utile pour placer les élèves.
                  if (!compact)
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
    for (var g = 0; g < _fields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      // -1 : pas de colonne pour la valeur par défaut du champ.
      out.add(
        SizedBox(
          width: (_fields[g].values.length - 1) * _cellW,
          child: Center(
            child: Text(
              _fields[g].label,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _valueHeaderCells(ColorScheme cs, TextStyle? style) {
    final out = <Widget>[];
    for (var g = 0; g < _fields.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      final field = _fields[g];
      for (var k = 0; k < field.values.length; k++) {
        if (k == field.defaultIndex) continue;
        final v = field.values[k];
        out.add(
          SizedBox(
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
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget _buildAttrRow(ColorScheme cs, Student s, int i) {
    final cells = <Widget>[];
    for (var g = 0; g < _fields.length; g++) {
      if (g > 0) cells.add(_vSep(cs));
      final field = _fields[g];
      final active = field.indexOf(s);
      for (var k = 0; k < field.values.length; k++) {
        if (k == field.defaultIndex) continue;
        cells.add(
          _checkCell(
            cs,
            key: ValueKey(
              'completeCell_${field.id}_${field.values[k].id}_${s.id}',
            ),
            on: active == k,
            onTap: () {
              field.setIndex(s, active == k ? field.defaultIndex : k);
              state.touch();
            },
          ),
        );
      }
    }
    return Container(
      height: _kRowH,
      color: _rowColor(cs, i),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }

  Widget _checkCell(
    ColorScheme cs, {
    required Key key,
    required bool on,
    required VoidCallback onTap,
  }) {
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
  late final TextEditingController _first = TextEditingController(
    text: widget.initial.firstName,
  );
  late final TextEditingController _last = TextEditingController(
    text: widget.initial.lastName,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial.notes,
  );
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
    final l10n = _l10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteStudentTitle),
        content: Text(l10n.deleteStudentDescription(widget.initial.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
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
    final l10n = _l10n(context);
    final isNew = widget.onDelete == null;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(isNew ? l10n.newStudent : l10n.editStudent)),
          if (!isNew)
            IconButton(
              tooltip: l10n.delete,
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
              decoration: InputDecoration(labelText: l10n.firstName),
            ),
            TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.lastName),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Gender>(
              initialValue: _gender,
              decoration: InputDecoration(labelText: l10n.gender),
              items: [
                for (final g in Gender.values)
                  DropdownMenuItem(
                    value: g,
                    child: Text(_genderLabel(l10n, g)),
                  ),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Level>(
              initialValue: _level,
              decoration: InputDecoration(labelText: l10n.level),
              items: [
                for (final l in Level.values)
                  DropdownMenuItem(value: l, child: Text(_levelLabel(l10n, l))),
              ],
              onChanged: (v) => setState(() => _level = v ?? _level),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Energy>(
              initialValue: _energy,
              decoration: InputDecoration(labelText: l10n.energy),
              items: [
                for (final t in Energy.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(_energyLabel(l10n, t)),
                  ),
              ],
              onChanged: (v) => setState(() => _energy = v ?? _energy),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StudentSize>(
              initialValue: _size,
              decoration: InputDecoration(labelText: l10n.size),
              items: [
                for (final t in StudentSize.values)
                  DropdownMenuItem(value: t, child: Text(_sizeLabel(l10n, t))),
              ],
              onChanged: (v) => setState(() => _size = v ?? _size),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.poorEyesight),
              subtitle: Text(l10n.poorEyesightSubtitle),
              value: _poorEyesight,
              onChanged: (v) => setState(() => _poorEyesight = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                hintText: l10n.notesHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
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
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

String _genderLabel(AppLocalizations l10n, Gender value) => switch (value) {
  Gender.fille => l10n.girl,
  Gender.garcon => l10n.boy,
  Gender.autre => l10n.unspecified,
};

String _levelLabel(AppLocalizations l10n, Level value) => switch (value) {
  Level.faible => l10n.low,
  Level.moyen => l10n.medium,
  Level.fort => l10n.high,
};

String _energyLabel(AppLocalizations l10n, Energy value) => switch (value) {
  Energy.calme => l10n.calm,
  Energy.modere => l10n.moderate,
  Energy.agite => l10n.restless,
};

String _sizeLabel(AppLocalizations l10n, StudentSize value) => switch (value) {
  StudentSize.petit => l10n.small,
  StudentSize.moyen => l10n.medium,
  StudentSize.grand => l10n.tall,
};
