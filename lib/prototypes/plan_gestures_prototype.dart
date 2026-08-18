/// Banc d'essai de l'arbitrage des gestes du plan, à lancer sur un vrai
/// téléphone — les tests widget ne reproduisent ni la jitter des doigts, ni le
/// décalage réel entre la pose des deux doigts, ni le rejet de paume.
///
/// Lancement :
/// ```
/// flutter run -t lib/prototypes/plan_gestures_prototype.dart
/// ```
///
/// Critère d'acceptation (issue #8, étape 2) : sur une vingtaine d'essais, un
/// glissement à un doigt ne zoome jamais, et un pincement à deux doigts ne
/// déplace jamais un élève — y compris quand le pincement démarre PILE sur une
/// place, qui est le cas piégeux.
///
/// Le compteur en haut de l'écran tient le score tout seul : il suffit de faire
/// les gestes et de lire les totaux.
library;

import 'package:flutter/material.dart';

import '../widgets/plan_viewport.dart';

void main() => runApp(const _PrototypeApp());

class _PrototypeApp extends StatelessWidget {
  const _PrototypeApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gestes du plan — banc d\'essai',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3F51B5),
          useMaterial3: true,
        ),
        home: const _Bench(),
      );
}

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  static const _cols = 8;
  static const _rows = 5;
  static const _cell = 62.0;
  static const _gap = 6.0;
  static const _rowGap = 14.0;

  final _tracker = PointerTracker();
  final _viewport = GlobalKey<PlanViewportState>();

  /// Place -> initiales, pour pouvoir échanger deux élèves comme dans l'app.
  late final Map<int, String> _seats = {
    for (var i = 0; i < _cols * _rows; i++) i: _initials[i % _initials.length],
  };

  static const _initials = [
    'AB', 'CD', 'EF', 'GH', 'IJ', 'KL', 'MN', 'OP',
    'QR', 'ST', 'UV', 'WX', 'YZ', 'AC', 'BD', 'CE',
  ];

  int _drags = 0;
  int _zooms = 0;
  double _scale = 1;
  final List<String> _log = [];

  void _note(String line) {
    setState(() {
      _log.insert(0, line);
      if (_log.length > 6) _log.removeLast();
    });
  }

  void _swap(int a, int b) {
    setState(() {
      final tmp = _seats[a];
      _seats[a] = _seats[b] ?? '';
      _seats[b] = tmp ?? '';
      _drags++;
    });
    _note('élève déplacé ($a → $b)');
  }

  void _reset() {
    setState(() {
      _drags = 0;
      _zooms = 0;
      _log.clear();
    });
    _viewport.currentState?.recenter();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestes du plan'),
        actions: [
          if (_viewport.currentState?.isZoomed ?? false)
            IconButton(
              tooltip: 'Recentrer',
              onPressed: () => setState(() => _viewport.currentState?.recenter()),
              icon: const Icon(Icons.center_focus_strong),
            ),
          IconButton(
            tooltip: 'Remettre les compteurs à zéro',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          _Scoreboard(drags: _drags, zooms: _zooms, scale: _scale),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Un doigt = déplacer un élève. Deux doigts = zoomer.\n'
              'Essayez surtout un pincement démarré sur une place.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: PlanViewport(
              key: _viewport,
              tracker: _tracker,
              onScaleChanged: (s) => setState(() => _scale = s),
              onDiagnostic: (d) {
                if (d.startsWith('zoom fin')) _zooms++;
                _note(d);
              },
              child: _grid(cs),
            ),
          ),
          _LogPanel(lines: _log),
        ],
      ),
    );
  }

  Widget _grid(ColorScheme cs) {
    final grid = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = _rows - 1; r >= 0; r--)
            Padding(
              padding: EdgeInsets.only(bottom: r > 0 ? _rowGap : 0),
              child: Row(
                children: [
                  for (var c = 0; c < _cols; c++) ...[
                    _seat(r * _cols + c, cs),
                    if (c < _cols - 1) const SizedBox(width: _gap),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    // Comme dans l'app : la salle est réduite pour tenir d'un coup, et le zoom
    // vient par-dessus.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: grid,
      ),
    );
  }

  Widget _seat(int index, ColorScheme cs) {
    final label = _seats[index] ?? '';
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _swap(d.data, index),
      builder: (context, candidate, rejected) {
        final cell = _cellBox(label, cs, hovering: candidate.isNotEmpty);
        return SeatDraggable<int>(
          tracker: _tracker,
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: _cellBox(label, cs, hovering: false, elevated: true),
          ),
          childWhenDragging: _cellBox('', cs, hovering: false),
          child: cell,
        );
      },
    );
  }

  Widget _cellBox(String label, ColorScheme cs,
          {required bool hovering, bool elevated = false}) =>
      Container(
        width: _cell,
        height: _cell,
        decoration: BoxDecoration(
          color: label.isEmpty ? cs.surface : const Color(0xFFA9CCF5),
          border: Border.all(
            color: hovering ? cs.primary : cs.outline,
            width: hovering ? 2.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: elevated
              ? [const BoxShadow(blurRadius: 8, color: Colors.black26)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard(
      {required this.drags, required this.zooms, required this.scale});

  final int drags;
  final int zooms;
  final double scale;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Stat(label: 'Élèves déplacés', value: '$drags'),
            _Stat(label: 'Zooms', value: '$zooms'),
            _Stat(label: 'Échelle', value: '×${scale.toStringAsFixed(2)}'),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 104,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListView(
          children: [
            for (final l in lines)
              Text(l, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
