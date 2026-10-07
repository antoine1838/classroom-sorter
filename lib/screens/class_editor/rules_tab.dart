part of '../class_editor_screen.dart';

// ---------------------------------------------------------------------------
// Onglet RÈGLES
// ---------------------------------------------------------------------------

class _RulesTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _RulesTab({required this.state, required this.cls});

  ClassGroupOps get _ops => ClassGroupOps(cls, commit: state.touch);

  String _describe(Rule r, AppLocalizations l10n) {
    final a = cls.studentById(r.studentAId)?.fullName ?? '?';
    final b = cls.studentById(r.studentBId)?.fullName ?? '?';
    final base = switch (r.type) {
      RuleType.fixedSeat =>
        '$a → ${l10n.rowNumber((r.seatRow ?? 0) + 1)}, ${l10n.columnNumber((r.seatCol ?? 0) + 1)}',
      RuleType.frontZone => '$a ${l10n.ruleFrontZone} (${r.frontRows})',
      RuleType.separate => '${l10n.ruleSeparate} $a / $b',
      RuleType.keepTogether => '${l10n.ruleKeepTogether} $a / $b',
    };
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text(
          l10n.balanceObjectives,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.balanceObjectivesDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.diversity_3),
                title: Text(l10n.mixGender),
                subtitle: Text(l10n.mixGenderDescription),
                value: cls.balance.mixGender,
                onChanged: (v) {
                  _ops.updateBalance((balance) => balance.mixGender = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.swap_vert),
                title: Text(l10n.mixLevels),
                subtitle: Text(l10n.mixLevelsDescription),
                value: cls.balance.mixLevel,
                onChanged: (v) {
                  _ops.updateBalance((balance) => balance.mixLevel = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bolt),
                title: Text(l10n.separateRestless),
                subtitle: Text(l10n.separateRestlessDescription),
                value: cls.balance.separateAgites,
                onChanged: (v) {
                  _ops.updateBalance((balance) => balance.separateAgites = v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: Text(l10n.moveNearBoard),
                subtitle: Text(l10n.moveNearBoardDescription),
                value: cls.balance.frontForPoorEyesight,
                onChanged: (v) {
                  _ops.updateBalance(
                    (balance) => balance.frontForPoorEyesight = v,
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.height),
                title: Text(l10n.avoidTallInFront),
                subtitle: Text(l10n.avoidTallInFrontDescription),
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
            Text(l10n.rulesTab, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: cls.students.isEmpty ? null : () => _addRule(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.rule),
            ),
          ],
        ),
        if (cls.students.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.addStudentsFirst),
          ),
        if (cls.rules.isEmpty && cls.students.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.noRules),
          ),
        for (final r in cls.rules)
          Card(
            child: ListTile(
              leading: Icon(
                r.hard ? Icons.lock : Icons.tune,
                color: r.hard ? Colors.red.shade400 : Colors.orange.shade600,
              ),
              title: Text(_describe(r, l10n)),
              subtitle: Text(
                '${_ruleLabel(r.type, l10n)} · '
                '${r.hard ? l10n.required : l10n.preference}',
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
    final l10n = _l10n(context);
    final rule = await showDialog<Rule>(
      context: context,
      builder: (_) => _RuleFormDialog(cls: cls, l10n: l10n),
    );
    if (rule == null) return;
    _ops.addRule(rule);
  }
}

class _RuleFormDialog extends StatefulWidget {
  final ClassGroup cls;
  final AppLocalizations l10n;
  const _RuleFormDialog({required this.cls, required this.l10n});

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
      title: Text(widget.l10n.newRule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RuleType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: widget.l10n.ruleType),
              items: [
                for (final t in RuleType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(_ruleLabel(t, widget.l10n)),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ruleDescription(_type, widget.l10n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _studentA,
              decoration: InputDecoration(labelText: widget.l10n.student),
              items: studentItems(),
              onChanged: (v) => setState(() => _studentA = v),
            ),
            if (_type.needsSecondStudent) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _studentB,
                decoration: InputDecoration(
                  labelText: widget.l10n.secondStudent,
                ),
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
                      decoration: InputDecoration(labelText: widget.l10n.row),
                      items: [
                        for (var r = 0; r < room.rows; r++)
                          DropdownMenuItem(
                            value: r,
                            child: Text(widget.l10n.rowNumber(r + 1)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _row = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _col.clamp(0, room.cols - 1),
                      decoration: InputDecoration(
                        labelText: widget.l10n.column,
                      ),
                      items: [
                        for (var c = 0; c < room.cols; c++)
                          DropdownMenuItem(
                            value: c,
                            child: Text(widget.l10n.columnNumber(c + 1)),
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
                label: widget.l10n.boardRows,
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
              title: Text(widget.l10n.required),
              subtitle: Text(
                _hard
                    ? widget.l10n.requiredDescription
                    : widget.l10n.preferenceDescription,
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
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: Text(widget.l10n.add),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_studentA == null) return;
    if (_type.needsSecondStudent) {
      if (_studentB == null || _studentB == _studentA) {
        _snack(context, widget.l10n.chooseDifferentStudents);
        return;
      }
    }
    if (_type == RuleType.fixedSeat && !widget.cls.room.isSeat(_row, _col)) {
      _snack(context, widget.l10n.disabledSeat);
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

String _ruleLabel(RuleType type, AppLocalizations l10n) => switch (type) {
  RuleType.fixedSeat => l10n.ruleFixedSeat,
  RuleType.frontZone => l10n.ruleFrontZone,
  RuleType.separate => l10n.ruleSeparate,
  RuleType.keepTogether => l10n.ruleKeepTogether,
};

String _ruleDescription(RuleType type, AppLocalizations l10n) => switch (type) {
  RuleType.fixedSeat => l10n.ruleFixedSeatDescription,
  RuleType.frontZone => l10n.ruleFrontZoneDescription,
  RuleType.separate => l10n.ruleSeparateDescription,
  RuleType.keepTogether => l10n.ruleKeepTogetherDescription,
};
