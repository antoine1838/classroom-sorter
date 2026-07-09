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
            isScrollable: true,
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

const double _kRowH = 48;
const double _kCellW = 48;
const double _kNameW = 172;
const double _kGroupH = 26;
const double _kValueH = 30;

/// Une colonne-valeur de la matrice : libellé court affiché en tête, libellé
/// complet en info-bulle, lecture et bascule de l'état pour un élève donné.
class _AttrCol {
  final String short;
  final IconData? icon;
  final String tooltip;
  final bool Function(Student) isOn;
  final void Function(Student) toggle;
  const _AttrCol(this.short, this.tooltip, this.isOn, this.toggle, {this.icon});
}

/// Un groupe de colonnes : soit des valeurs exclusives (genre, niveau,
/// énergie), soit une seule colonne booléenne (vue).
class _AttrGroup {
  final String label;
  final List<_AttrCol> cols;
  const _AttrGroup(this.label, this.cols);
}

/// Définition des colonnes de la matrice. Dans un groupe exclusif, cocher une
/// valeur remplace la précédente ; re-cocher la valeur active revient à
/// « non défini ».
final List<_AttrGroup> _attrGroups = [
  _AttrGroup('Genre', [
    _AttrCol('Gar', 'Garçon', (s) => s.gender == Gender.garcon,
        (s) => s.gender =
            s.gender == Gender.garcon ? Gender.autre : Gender.garcon,
        icon: Icons.male),
    _AttrCol('Fil', 'Fille', (s) => s.gender == Gender.fille,
        (s) => s.gender =
            s.gender == Gender.fille ? Gender.autre : Gender.fille,
        icon: Icons.female),
  ]),
  _AttrGroup('Niveau', [
    _AttrCol('Fai', 'Faible', (s) => s.level == Level.faible,
        (s) => s.level =
            s.level == Level.faible ? Level.nonDefini : Level.faible,
        icon: Icons.arrow_downward),
    _AttrCol('Moy', 'Moyen', (s) => s.level == Level.moyen,
        (s) => s.level =
            s.level == Level.moyen ? Level.nonDefini : Level.moyen,
        icon: Icons.remove),
    _AttrCol('For', 'Fort', (s) => s.level == Level.fort,
        (s) => s.level = s.level == Level.fort ? Level.nonDefini : Level.fort,
        icon: Icons.arrow_upward),
  ]),
  _AttrGroup('Énergie', [
    _AttrCol('Cal', 'Calme', (s) => s.energy == Energy.calme,
        (s) => s.energy = s.energy == Energy.calme
            ? Energy.nonDefini
            : Energy.calme,
        icon: Icons.self_improvement),
    _AttrCol('Agi', 'Agité', (s) => s.energy == Energy.agite,
        (s) => s.energy = s.energy == Energy.agite
            ? Energy.nonDefini
            : Energy.agite,
        icon: Icons.bolt),
  ]),
  _AttrGroup('Vue', [
    _AttrCol('Vue', 'Mauvaise vue (à placer devant)', (s) => s.poorEyesight,
        (s) => s.poorEyesight = !s.poorEyesight,
        icon: Icons.visibility_off),
  ]),
];

class _StudentsTab extends StatefulWidget {
  final AppState state;
  final ClassGroup cls;
  const _StudentsTab({required this.state, required this.cls});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final ScrollController _vBody = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncing = false;
  bool _sortByName = false;

  AppState get state => widget.state;
  ClassGroup get cls => widget.cls;

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
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _editStudent(context),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Ajouter'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _importList(context),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Importer une liste'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: cls.students.isEmpty
              ? const Center(child: Text('Aucun élève. Ajoutez-en un !'))
              : _buildMatrix(cs),
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
            width: _kNameW,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
    for (var g = 0; g < _attrGroups.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      out.add(SizedBox(
        width: _attrGroups[g].cols.length * _kCellW,
        child: Center(
          child: Text(_attrGroups[g].label,
              style: style, overflow: TextOverflow.ellipsis),
        ),
      ));
    }
    return out;
  }

  List<Widget> _valueHeaderCells(ColorScheme cs, TextStyle? style) {
    final out = <Widget>[];
    for (var g = 0; g < _attrGroups.length; g++) {
      if (g > 0) out.add(_vSep(cs));
      for (final c in _attrGroups[g].cols) {
        out.add(SizedBox(
          width: _kCellW,
          child: Center(
            child: Tooltip(
              message: c.tooltip,
              child: c.icon != null
                  ? Icon(c.icon, size: 18)
                  : Text(c.short,
                      style: (style ?? const TextStyle()).copyWith(fontSize: 16)),
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
      width: _kNameW,
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
              CircleAvatar(
                radius: 13,
                backgroundColor: studentColor(s, cs),
                child: Text(s.initials,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
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
    for (var g = 0; g < _attrGroups.length; g++) {
      if (g > 0) cells.add(_vSep(cs));
      for (final c in _attrGroups[g].cols) {
        cells.add(_checkCell(
          cs,
          on: c.isOn(s),
          onTap: () {
            c.toggle(s);
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
      {required bool on, required VoidCallback onTap}) {
    return SizedBox(
      width: _kCellW,
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
    final initial = existing ??
        Student(id: newId(), gender: Gender.autre, level: Level.nonDefini);
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
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            TextField(
              controller: _last,
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
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mauvaise vue'),
              subtitle: const Text('À placer près du tableau (moitié avant)'),
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
                subtitle: const Text('Éviter les voisins de même niveau'),
                value: cls.balance.mixLevel,
                onChanged: (v) {
                  cls.balance.mixLevel = v;
                  state.touch();
                },
              ),
              SwitchListTile(
                title: const Text('Séparer les élèves agités'),
                subtitle: const Text('Éviter deux élèves agités côte à côte'),
                value: cls.balance.separateAgites,
                onChanged: (v) {
                  cls.balance.separateAgites = v;
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

  void _clear() {
    cls.assignment.clear();
    widget.state.touch();
    setState(() => _result = null);
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
                IconButton.filledTonal(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Vider le plan',
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
