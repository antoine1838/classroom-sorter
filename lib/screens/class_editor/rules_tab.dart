part of '../class_editor_screen.dart';

// ---------------------------------------------------------------------------
// Onglet RÈGLES
// ---------------------------------------------------------------------------

class _RulesTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _RulesTab({required this.state, required this.cls});

  ClassGroupOps get _ops => ClassGroupOps(cls, commit: state.touch);

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
        Text(
          'Objectifs d\'équilibre',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          'Appliqués à toute la classe (préférences).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
                  _ops.updateBalance((balance) => balance.mixGender = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.swap_vert),
                title: const Text('Mélanger les niveaux'),
                subtitle: const Text(
                  'Ne pas créer 2 voisins Faibles ni 2 voisins Forts',
                ),
                value: cls.balance.mixLevel,
                onChanged: (v) {
                  _ops.updateBalance((balance) => balance.mixLevel = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bolt),
                title: const Text('Séparer les élèves agités'),
                subtitle: const Text(
                  'Éviter que deux élèves agités soient voisins',
                ),
                value: cls.balance.separateAgites,
                onChanged: (v) {
                  _ops.updateBalance((balance) => balance.separateAgites = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('Rapprocher du tableau'),
                subtitle: const Text(
                  'Placer les élèves à mauvaise vue dans la moitié avant',
                ),
                value: cls.balance.frontForPoorEyesight,
                onChanged: (v) {
                  _ops.updateBalance(
                    (balance) => balance.frontForPoorEyesight = v,
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.height),
                title: const Text(
                  'Éviter qu\'un grand gêne la vue d\'un petit',
                ),
                subtitle: const Text(
                  'Un élève grand ne doit pas être assis juste devant un petit — il lui bloquerait la vue du tableau (devant, ou sur un bras de U)',
                ),
                value: cls.balance.avoidTallInFrontOfShort,
                onChanged: (v) {
                  _ops.updateBalance(
                    (balance) => balance.avoidTallInFrontOfShort = v,
                  );
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
              onPressed: cls.students.isEmpty ? null : () => _addRule(context),
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
              subtitle: Text(
                '${r.type.label} · '
                '${r.hard ? 'Obligatoire' : 'Préférence'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _ops.removeRule(r);
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
    _ops.addRule(rule);
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
                child: Text(
                  _type.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
                          DropdownMenuItem(
                            value: r,
                            child: Text('Rang ${r + 1}'),
                          ),
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
                            value: c,
                            child: Text('Colonne ${c + 1}'),
                          ),
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
                onMinus: () => setState(
                  () => _frontRows = (_frontRows - 1).clamp(1, room.rows),
                ),
                onPlus: () => setState(
                  () => _frontRows = (_frontRows + 1).clamp(1, room.rows),
                ),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoire'),
              subtitle: Text(
                _hard
                    ? 'Doit absolument être respectée'
                    : 'Simple préférence à optimiser',
              ),
              value: _hard,
              onChanged: (v) => setState(() => _hard = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
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
      _snack(
        context,
        'Cette place est désactivée (allée). Choisissez-en une autre.',
      );
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
