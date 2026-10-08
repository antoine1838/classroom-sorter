part of '../class_editor_screen.dart';

// ---------------------------------------------------------------------------
// Onglet PLAN
// ---------------------------------------------------------------------------

class _PlanTab extends StatefulWidget {
  final AppState state;
  final ClassGroup cls;
  final PlanGenerator planGenerator;
  const _PlanTab({
    required this.state,
    required this.cls,
    required this.planGenerator,
  });

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  PlanResult? _result;
  String? _resultSignature;
  bool _generating = false;
  int _generationToken = 0;

  /// Partagé entre la fenêtre de zoom et les places : un pincement posé sur une
  /// place ne doit pas saisir d'élève (voir PlanViewport).
  final _tracker = PointerTracker();
  final _viewport = GlobalKey<PlanViewportState>();

  /// Échelle courante du zoom à deux doigts, répercutée sur [PlanGrid] pour
  /// qu'une case zoomée bascule des initiales vers le prénom.
  double _zoom = 1;

  ClassGroup get cls => widget.cls;
  ClassGroupOps get _ops => ClassGroupOps(cls, commit: widget.state.touch);

  @override
  void didUpdateWidget(covariant _PlanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_result != null && _resultSignature != planEvaluationSignature(cls)) {
      _clearResult();
    }
  }

  void _setResult(PlanResult result) {
    _result = result;
    _resultSignature = planEvaluationSignature(cls);
  }

  void _clearResult() {
    _result = null;
    _resultSignature = null;
  }

  Future<void> _generate() async {
    if (_generating || cls.students.isEmpty) return;

    final token = ++_generationToken;
    final signature = planEvaluationSignature(cls);
    setState(() {
      _generating = true;
      _clearResult();
    });

    try {
      final generated = await widget.planGenerator(cls);
      if (!mounted ||
          !shouldApplyGeneratedPlan(
            requestSignature: signature,
            currentSignature: planEvaluationSignature(cls),
            requestToken: token,
            currentToken: _generationToken,
          )) {
        return;
      }

      final result = _ops.applyGeneratedPlan(generated);
      setState(() => _setResult(result));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n(context).generationFailed)),
        );
      }
    } finally {
      if (mounted && token == _generationToken) {
        setState(() => _generating = false);
      }
    }
  }

  void _validate() {
    final result = SeatingEngine(cls).evaluate();
    setState(() => _setResult(result));
  }

  void _swap(String seatA, String seatB) {
    setState(() {
      _ops.swapSeats(seatA, seatB);
      _clearResult();
    });
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
      return Row(
        children: [
          Expanded(child: grid),
          _controls(vertical: true),
        ],
      );
    }
    return Column(
      children: [
        _controls(vertical: false),
        Expanded(child: grid),
      ],
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
    if (hasPlan) {
      widest = max(widest, _labelledWidth(context, _l10n(context).validate));
    }
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

  String get _generateLabel => cls.assignment.isNotEmpty
      ? _l10n(context).regenerate
      : _l10n(context).generatePlan;

  /// Résumé porté par le bouton du rapport.
  String get _reportLabel {
    final result = _result;
    if (result == null || result.isClean) {
      return _l10n(context).report;
    }
    // Une contrainte dure prime ; sinon on annonce les points perfectibles,
    // objectifs d'équilibre compris.
    return result.hardCount > 0
        ? _l10n(context).problemsCount(result.hardCount)
        : _l10n(context).improvementsCount(result.softCount);
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
    final onPressed = cls.students.isEmpty || _generating ? null : _generate;
    final icon = _generating
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.auto_awesome);
    if (!labelled) {
      return IconButton.filled(
        tooltip: label,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return Expanded(
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
      ),
    );
  }

  Widget _validateControl({required bool labelled}) {
    const icon = Icon(Icons.fact_check);
    if (!labelled) {
      return IconButton.filledTonal(
        tooltip: _l10n(context).validate,
        onPressed: _validate,
        icon: icon,
      );
    }
    return Expanded(
      child: FilledButton.tonalIcon(
        onPressed: _validate,
        icon: icon,
        label: Text(_l10n(context).validate),
      ),
    );
  }

  Widget _recenterControl() => IconButton(
    tooltip: _l10n(context).recenter,
    onPressed: () => setState(() => _viewport.currentState?.recenter()),
    icon: const Icon(Icons.center_focus_strong),
  );

  /// Dispose les contrôles en rangée ou en colonne, séparés d'un espace.
  Widget _spacedBar(
    List<Widget> controls, {
    required bool vertical,
    required bool labelled,
  }) {
    final spaced = <Widget>[];
    for (final control in controls) {
      if (spaced.isNotEmpty) {
        spaced.add(
          vertical ? const SizedBox(height: 8) : const SizedBox(width: 8),
        );
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
                children: spaced,
              ),
            ),
          ),
        ),
      );
    }
    // Sans libellé, les contrôles ne s'étirent pas : on les centre plutôt que
    // de les laisser collés au bord.
    final alignment = labelled
        ? MainAxisAlignment.start
        : MainAxisAlignment.center;
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
        _l10n(context).constraintsNotMet(r.hardCount),
      ),
      final r when r.softCount > 0 => (
        Icons.warning_amber,
        _kSoftColour,
        _l10n(context).improvableCount(r.softCount),
      ),
      _ => (
        Icons.check_circle_outline,
        // Explicitement vert : laisser la couleur par défaut donnait une
        // coche grise, indiscernable d'un état neutre.
        _kCleanColour,
        _l10n(context).allGoalsMet,
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
      return Center(child: Text(_l10n(context).addStudentsThenGenerate));
    }
    if (cls.assignment.isEmpty) {
      return Center(
        child: Text(
          _l10n(context).generatePlanHint,
          textAlign: TextAlign.center,
        ),
      );
    }
    // Un doigt déplace un élève, deux doigts zooment et déplacent la vue.
    return PlanViewport(
      key: _viewport,
      tracker: _tracker,
      onScaleChanged: (scale) => setState(() => _zoom = scale),
      child: PlanGrid(
        cls: cls,
        onSwap: _swap,
        tracker: _tracker,
        result: _result,
        onTapSeat: (student) => _showSeatDetail(context, student),
        zoom: _zoom,
        genderPalette: widget.state.genderColorPalette,
      ),
    );
  }

  /// Feuille de détail d'un élève, ouverte au tap sur sa place : nom complet,
  /// tous les attributs en clair (y compris ceux muets sur la case, sinon les
  /// glyphes redeviennent indevinables), les motifs de problème s'il y en a,
  /// et un accès direct au formulaire d'édition existant.
  void _showSeatDetail(BuildContext context, Student student) {
    final l10n = _l10n(context);
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
              Text(
                student.fullName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _SeatDetailAttributes(student: student, l10n: l10n),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.toNote,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final issue in issues)
                  _ReportLine(
                    icon: issue.isHard ? Icons.error : Icons.warning_amber,
                    color: issue.isHard ? Colors.red.shade600 : _kSoftColour,
                    text: localizedPlanIssue(issue, l10n, cls.studentById),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  _editStudentFromPlan(student);
                },
                icon: const Icon(Icons.edit),
                label: Text(l10n.editStudent),
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
      _ops.upsertStudent(result, existing: existing);
    });
  }

  void _deleteStudentFromPlan(Student s) {
    setState(() {
      _ops.removeStudent(s);
      _clearResult();
    });
  }

  /// Le rapport complet, en feuille.
  void _showReport(BuildContext context) {
    final l10n = _l10n(context);
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
              _ReportCard(result: result, l10n: l10n, cls: cls),
              if (unplaced.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.unplacedStudents(
                      unplaced
                          .map((id) => cls.studentById(id)?.fullName ?? '?')
                          .join(', '),
                    ),
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
  final AppLocalizations l10n;
  const _SeatDetailAttributes({required this.student, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      _genderLabel(l10n, student.gender),
      l10n.attributeLevel(_levelLabel(l10n, student.level)),
      l10n.attributeEnergy(_energyLabel(l10n, student.energy)),
      l10n.attributeSize(_sizeLabel(l10n, student.size)),
      student.poorEyesight ? l10n.poorEyesight : l10n.goodEyesight,
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
            child: Text(
              student.notes,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final PlanResult result;
  final AppLocalizations l10n;
  final ClassGroup cls;
  const _ReportCard({
    required this.result,
    required this.l10n,
    required this.cls,
  });

  @override
  Widget build(BuildContext context) {
    final ok = result.isClean;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ok)
              _ReportLine(
                icon: Icons.check_circle,
                color: Colors.green,
                text: l10n.allRulesMet,
              ),
            for (final v in result.violations)
              _ReportLine(
                icon: Icons.error,
                color: Colors.red.shade600,
                text: localizedPlanIssue(v, l10n, cls.studentById),
              ),
            for (final w in result.warnings)
              _ReportLine(
                icon: Icons.warning_amber,
                color: Colors.orange.shade700,
                text: localizedPlanIssue(w, l10n, cls.studentById),
              ),
            if (result.balance.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l10n.balance,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              for (final n in result.balance)
                _ReportLine(
                  icon: n.ok ? Icons.check_circle_outline : Icons.info_outline,
                  color: n.ok ? Colors.green : Colors.orange.shade700,
                  text: localizedBalanceNote(n, l10n),
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
  const _ReportLine({
    required this.icon,
    required this.color,
    required this.text,
  });

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
