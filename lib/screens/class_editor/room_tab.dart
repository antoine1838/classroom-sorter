part of '../class_editor_screen.dart';

// ---------------------------------------------------------------------------
// Onglet SALLE
// ---------------------------------------------------------------------------

enum _SaveRoomChoice { update, asNew }

class _RoomTab extends StatelessWidget {
  final AppState state;
  final ClassGroup cls;
  const _RoomTab({required this.state, required this.cls});

  /// Libellé partagé par le bouton et les deux boîtes de dialogue
  /// d'enregistrement (mise à jour ou nouvelle salle).
  static const _kSaveRoomLabel = 'Enregistrer la salle';

  ClassGroupOps get _ops => ClassGroupOps(cls, commit: state.touch);

  void _resize({int? rows, int? cols}) {
    _ops.resizeRoom(rows: rows, cols: cols);
  }

  /// Ouvre le sélecteur de disposition, demande confirmation si la salle
  /// actuelle porte déjà un plan (la perte peut être totale, contrairement à
  /// un simple -1 rang/colonne), puis remplace la salle et nettoie le plan
  /// des places devenues hors grille — comme le fait déjà [_resize].
  Future<void> _pickLayout(BuildContext context) async {
    final result = await showDialog<(Room, String?)>(
      context: context,
      builder: (_) => _RoomLayoutDialog(
        state: state,
        initialRows: cls.room.rows,
        initialCols: cls.room.cols,
      ),
    );
    if (result == null || !context.mounted) return;
    final (layout, savedRoomId) = result;

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

    _ops.applyRoom(layout, savedRoomId: savedRoomId);
  }

  /// Enregistre la salle actuelle de la classe. Si elle provient déjà d'une
  /// salle enregistrée ([ClassGroup.savedRoomId]), propose de la mettre à
  /// jour plutôt que d'en créer une nouvelle sans y être invité.
  Future<void> _saveRoom(BuildContext context) async {
    final origin = state.savedRoomById(cls.savedRoomId);

    if (origin != null) {
      final choice = await showDialog<_SaveRoomChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(_kSaveRoomLabel),
          content: Text('Cette salle provient de « ${origin.name} ».'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _SaveRoomChoice.asNew),
              child: const Text('Enregistrer comme nouvelle salle'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _SaveRoomChoice.update),
              child: Text('Mettre à jour « ${origin.name} »'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      if (choice == _SaveRoomChoice.update) {
        state.updateSavedRoom(origin.id, cls.room);
        return;
      }
    }

    if (!context.mounted) return;
    await _saveRoomAsNew(context);
  }

  /// Demande un nom et enregistre la salle actuelle comme une nouvelle
  /// entrée — en remplaçant une salle existante du même nom si l'utilisateur
  /// le confirme.
  Future<void> _saveRoomAsNew(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(_kSaveRoomLabel),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex. B204'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    SavedRoom? existing;
    for (final r in state.savedRooms) {
      if (r.name == name) {
        existing = r;
        break;
      }
    }
    if (existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remplacer la salle ?'),
          content: Text(
            'Une salle nommée « $name » existe déjà. La remplacer par '
            'celle-ci ?',
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
      state.updateSavedRoom(existing.id, cls.room);
      cls.savedRoomId = existing.id;
    } else {
      final saved = state.addSavedRoom(name, cls.room);
      cls.savedRoomId = saved.id;
    }
    state.touch();
  }

  static const _helpText =
      'Touchez une case vide pour y poser une place, une place pour la '
      'faire tourner. Appui long ou clic droit sur une place pour la '
      'retirer. Touchez l\'espace entre deux cases pour ajouter un '
      'couloir : les élèves de part et d\'autre ne seront plus voisins.';
  static const _helpStyle = TextStyle(fontSize: 12);

  /// Hauteur intrinsèque de la rangée de compteurs (Rangs/Colonnes/places/
  /// disposition) : 48 dp est la cible tactile minimale Material 3 des
  /// [IconButton] des steppers (déjà utilisée ailleurs, voir [_kIconMinW]) ;
  /// le libellé au-dessus, lui, est mesuré plutôt qu'estimé.
  double _controlsRowHeight(BuildContext context) {
    final labelH = _wrappedTextHeight(
      context,
      'Colonnes',
      Theme.of(context).textTheme.labelMedium,
      double.infinity,
    );
    return labelH + 48 + 24; // + Padding.all(12) haut/bas
  }

  /// Hauteur du bandeau d'alerte (icône + texte replié), mesurée sur la
  /// largeur réellement disponible une fois icône et paddings déduits.
  double _warningHeight(BuildContext context, String text, double maxWidth) {
    const innerReserved =
        12 * 2 /* padding externe L/R */ +
        12 * 2 /* padding interne container L/R */ +
        18 /* icône */ +
        8 /* espace icône-texte */;
    final textH = _wrappedTextHeight(
      context,
      text,
      _helpStyle,
      maxWidth - innerReserved,
    );
    final rowH = textH < 18 ? 18.0 : textH;
    return rowH +
        16 /* padding interne haut/bas */ +
        8 /* padding externe bas */;
  }

  @override
  Widget build(BuildContext context) {
    final room = cls.room;
    final missing = cls.students.length - room.capacity;
    final warningText = missing > 0
        ? '${room.capacity} place(s) pour ${cls.students.length} '
              'élève(s) — $missing élève(s) ne seront pas placé(s).'
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        var fixed = _controlsRowHeight(context) + 8; // + spacer avant la grille
        if (warningText != null) {
          fixed += _warningHeight(context, warningText, constraints.maxWidth);
        }
        final helpH = _wrappedTextHeight(
          context,
          _helpText,
          _helpStyle,
          constraints.maxWidth - 24,
        );
        final showHelp =
            constraints.maxHeight - fixed - helpH >= _kMinGridHeight;

        // Le chrome (compteurs, alerte, aide) vit dans un sliver ordinaire et
        // la grille dans un SliverFillRemaining : la grille occupe tout
        // l'espace restant quand il y en a (comme l'Expanded précédent), mais
        // si la fenêtre est trop courte même une fois l'aide masquée (#17), on
        // défile plutôt que de déborder — un filet, pas la stratégie
        // principale, qui reste la dégradation par paliers ci-dessus.
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
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
                        if (state.savedRoomById(cls.savedRoomId) != null)
                          Chip(
                            avatar: const Icon(
                              Icons.bookmark_outlined,
                              size: 18,
                            ),
                            label: Text(
                              state.savedRoomById(cls.savedRoomId)!.name,
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _pickLayout(context),
                          icon: const Icon(
                            Icons.dashboard_customize_outlined,
                            size: 18,
                          ),
                          label: const Text('Disposition'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _saveRoom(context),
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 18,
                          ),
                          label: const Text(_kSaveRoomLabel),
                        ),
                      ],
                    ),
                  ),
                  if (warningText != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warningText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Premier palier de dégradation (#17) : sur fenêtre courte,
                  // ce paragraphe — le moins essentiel du lot, les commandes
                  // et l'alerte de capacité restent visibles — cède la place
                  // à la grille plutôt que de la faire déborder.
                  if (showHelp)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(_helpText, style: _helpStyle),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: RoomEditorGrid(
                  room: room,
                  onChanged: _ops.afterRoomEdited,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ouvre le même sélecteur de disposition que l'onglet Salle, pour une salle
/// neuve sans aucun plan à perdre — utilisé à la création d'une classe.
/// Renvoie `null` si annulé, auquel cas l'appelant garde la salle par
/// défaut.
Future<(Room, String?)?> pickInitialRoomLayout(
  BuildContext context, {
  required AppState state,
  required int initialRows,
  required int initialCols,
}) {
  return showDialog<(Room, String?)>(
    context: context,
    builder: (_) => _RoomLayoutDialog(
      state: state,
      initialRows: initialRows,
      initialCols: initialCols,
    ),
  );
}

/// Sélecteur de modèle de disposition : Rangées, U, Îlots, une page blanche,
/// ou une salle enregistrée par l'utilisateur (« Mes salles »). Renvoie la
/// [Room] choisie et, si elle vient de « Mes salles », l'id de la salle
/// enregistrée dont elle est issue — via `Navigator.pop`, ou `null` si
/// annulé. Ne modifie jamais la salle en cours, c'est à l'appelant de
/// l'appliquer (voir [_RoomTab._pickLayout] et [pickInitialRoomLayout]).
class _RoomLayoutDialog extends StatefulWidget {
  final AppState state;
  final int initialRows;
  final int initialCols;
  const _RoomLayoutDialog({
    required this.state,
    required this.initialRows,
    required this.initialCols,
  });

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
  String? _selectedSavedRoomId;

  /// `null` uniquement pour « Mes salles » sans sélection, ou sans aucune
  /// salle enregistrée — les autres branches produisent toujours une salle.
  Room? _build() => switch (_kind) {
    RoomLayoutKind.rangees => buildRangeesLayout(
      rows: widget.initialRows,
      cols: widget.initialCols,
    ),
    RoomLayoutKind.blanche => buildBlancheLayout(
      rows: widget.initialRows,
      cols: widget.initialCols,
    ),
    RoomLayoutKind.u => buildULayout(
      armDepth: _armDepth,
      doubleArm: _doubleArm,
    ),
    RoomLayoutKind.ilots => buildIlotsLayout(
      islandSize: _islandSize,
      islandCount: _islandCount,
      islandRows: _islandRows,
    ),
    // Copie : appliquer une salle enregistrée ne doit jamais faire de
    // cls.room et de la SavedRoom stockée le même objet — sinon une
    // retouche locale se propagerait silencieusement à la salle
    // enregistrée (et à toute autre classe qui l'utilise plus tard).
    RoomLayoutKind.mesSalles => switch (widget.state.savedRoomById(
      _selectedSavedRoomId,
    )) {
      null => null,
      final saved => Room.fromJson(saved.room.toJson()),
    },
  };

  List<SavedRoom> get _sortedSavedRooms =>
      [...widget.state.savedRooms]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Choix exclusif à puces qui se répartissent sur plusieurs lignes selon
  /// la largeur disponible, plutôt que de comprimer leur texte (issue #26).
  Widget _choiceWrap<T>({
    required List<(T value, String label)> options,
    required T selected,
    required ValueChanged<T> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }

  /// Aperçu centré, à taille fixe, de la salle que produirait la sélection
  /// courante — même pour les quatre modèles par défaut, par symétrie avec
  /// « Mes salles ».
  Widget _preview(Room room) =>
      Center(child: roomThumbnailBox(room, width: 120, height: 72));

  Future<void> _renameSavedRoom(SavedRoom saved) async {
    final ctrl = TextEditingController(text: saved.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer la salle'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    widget.state.renameSavedRoom(saved.id, name);
    setState(() {});
  }

  Future<void> _deleteSavedRoom(SavedRoom saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la salle ?'),
        content: Text('« ${saved.name} » sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.state.deleteSavedRoom(saved.id);
    setState(() {
      if (_selectedSavedRoomId == saved.id) _selectedSavedRoomId = null;
    });
  }

  /// Menu Renommer/Supprimer ouvert par l'appui long ou le clic droit sur
  /// une salle — le tap simple reste réservé à la sélection.
  Future<void> _showSavedRoomMenu(SavedRoom saved) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(saved.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'renommer'),
            child: const Text('Renommer'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'supprimer'),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'renommer':
        await _renameSavedRoom(saved);
      case 'supprimer':
        await _deleteSavedRoom(saved);
    }
  }

  Widget _savedRoomsList() {
    final rooms = _sortedSavedRooms;
    if (rooms.isEmpty) {
      return Text(
        'Aucune salle enregistrée. Utilisez « Enregistrer la salle » dans '
        'l\'onglet Salle.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final saved in rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedSavedRoomId = saved.id),
              onLongPress: () => _showSavedRoomMenu(saved),
              onSecondaryTap: () => _showSavedRoomMenu(saved),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedSavedRoomId == saved.id
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: _selectedSavedRoomId == saved.id ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    roomThumbnailBox(saved.room, width: 48, height: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(saved.name),
                          Text(
                            '${saved.room.capacity} places',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(
          'Appui long ou clic droit sur une salle pour la renommer ou la '
          'supprimer.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _build();
    return AlertDialog(
      title: const Text('Disposition de la salle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _choiceWrap<RoomLayoutKind>(
              options: const [
                (RoomLayoutKind.rangees, 'Rangées'),
                (RoomLayoutKind.u, 'U'),
                (RoomLayoutKind.ilots, 'Îlots'),
                (RoomLayoutKind.blanche, 'Vide'),
                (RoomLayoutKind.mesSalles, 'Mes salles'),
              ],
              selected: _kind,
              onChanged: (v) => setState(() => _kind = v),
            ),
            const SizedBox(height: 16),
            switch (_kind) {
              RoomLayoutKind.rangees || RoomLayoutKind.blanche => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _preview(room!),
                  const SizedBox(height: 8),
                  Text(
                    'Conserve la taille actuelle de la salle '
                    '(${widget.initialRows} × ${widget.initialCols}).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              RoomLayoutKind.u => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _preview(room!),
                  const SizedBox(height: 8),
                  _Stepper(
                    label: 'Profondeur des bras',
                    value: _armDepth,
                    onMinus: () => setState(
                      () => _armDepth = (_armDepth - 1).clamp(1, 10),
                    ),
                    onPlus: () => setState(
                      () => _armDepth = (_armDepth + 1).clamp(1, 10),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Bras doubles',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    value: _doubleArm,
                    onChanged: (v) => setState(() => _doubleArm = v),
                  ),
                ],
              ),
              RoomLayoutKind.ilots => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _preview(room!),
                  const SizedBox(height: 8),
                  _choiceWrap<int>(
                    options: const [(4, 'Tables de 4'), (6, 'Tables de 6')],
                    selected: _islandSize,
                    onChanged: (v) => setState(() => _islandSize = v),
                  ),
                  const SizedBox(height: 8),
                  _Stepper(
                    label: 'Nombre d\'îlots par rang',
                    value: _islandCount,
                    onMinus: () => setState(
                      () => _islandCount = (_islandCount - 1).clamp(1, 8),
                    ),
                    onPlus: () => setState(
                      () => _islandCount = (_islandCount + 1).clamp(1, 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Stepper(
                    label: 'Nombre de rangs d\'îlots',
                    value: _islandRows,
                    onMinus: () => setState(
                      () => _islandRows = (_islandRows - 1).clamp(1, 4),
                    ),
                    onPlus: () => setState(
                      () => _islandRows = (_islandRows + 1).clamp(1, 4),
                    ),
                  ),
                ],
              ),
              RoomLayoutKind.mesSalles => _savedRoomsList(),
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
          onPressed: room == null
              ? null
              : () => Navigator.pop(context, (
                  room,
                  _kind == RoomLayoutKind.mesSalles
                      ? _selectedSavedRoomId
                      : null,
                )),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}
