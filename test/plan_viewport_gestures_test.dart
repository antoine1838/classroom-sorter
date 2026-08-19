// Arbitrage des gestes de la fenêtre du plan (issue #8, étape 2).
//
// Ce que ces tests prouvent : le routage un doigt / deux doigts fonctionne dans
// l'arène de gestes de Flutter — un doigt atteint le Draggable, deux doigts
// zooment, et aucun des deux ne déclenche l'autre.
//
// Ce qu'ils NE prouvent pas : le comportement avec de vrais doigts. La jitter,
// le décalage réel entre la pose des deux doigts, le rejet de paume et le seuil
// de déplacement du système ne sont pas reproduits ici. La validation finale se
// fait sur l'appareil (voir notes/refonte-ecran-plan.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/widgets/plan_viewport.dart';

/// Fenêtre contenant une place déplaçable (à gauche) et une place d'accueil
/// (à droite) : la structure du plan, réduite à l'essentiel.
class _Harness extends StatefulWidget {
  const _Harness({this.viewportKey, this.diagnostics});

  final GlobalKey<PlanViewportState>? viewportKey;

  /// Reçoit la trace des gestes quand le test veut l'inspecter.
  final List<String>? diagnostics;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final tracker = PointerTracker();
  double scale = 1;
  String? dropped;
  int dragStarts = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: PlanViewport(
              key: widget.viewportKey,
              tracker: tracker,
              onScaleChanged: (s) => scale = s,
              onDiagnostic: widget.diagnostics?.add,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SeatDraggable<String>(
                    tracker: tracker,
                    data: 'eleve',
                    onDragStarted: () => dragStarts++,
                    feedback: const SizedBox(width: 80, height: 80),
                    child: Container(
                      key: const Key('seatA'),
                      width: 120,
                      height: 400,
                      color: const Color(0xFFA9CCF5),
                      alignment: Alignment.center,
                      child: const Text('A'),
                    ),
                  ),
                  DragTarget<String>(
                    onAcceptWithDetails: (d) => setState(() => dropped = d.data),
                    builder: (_, _, _) => Container(
                      width: 120,
                      height: 400,
                      color: const Color(0xFFF3B8D0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  /// Centre de la place déplaçable et de la place d'accueil.
  Offset seatA(WidgetTester tester) => tester.getCenter(find.text('A'));
  Offset target(WidgetTester tester) =>
      tester.getCenter(find.byType(DragTarget<String>));

  _HarnessState state(WidgetTester tester) =>
      tester.state<_HarnessState>(find.byType(_Harness));

  testWidgets('un doigt sur une place déclenche le glisser-déposer', (t) async {
    await t.pumpWidget(const _Harness());

    await t.drag(find.text('A'), target(t) - seatA(t));
    await t.pumpAndSettle();

    expect(state(t).dragStarts, 1,
        reason: 'le geste à un doigt doit atteindre le Draggable');
    expect(state(t).dropped, 'eleve');
    expect(state(t).scale, 1, reason: 'un doigt ne doit pas zoomer');
  });

  testWidgets('deux doigts zooment', (t) async {
    await t.pumpWidget(const _Harness());
    final center = t.getCenter(find.byType(PlanViewport));

    // Deux doigts qui s'écartent depuis le centre.
    final f1 = await t.startGesture(center - const Offset(30, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(30, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(90, 0));
    await f2.moveTo(center + const Offset(90, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(state(t).scale, greaterThan(1.5),
        reason: 'écarter deux doigts de 60 à 180 px doit zoomer ×3 environ');
  });

  testWidgets('deux doigts sur une place ne déplacent aucun élève', (t) async {
    await t.pumpWidget(const _Harness());
    final a = seatA(t);

    // Le pincement commence SUR la place déplaçable : c'est le cas piégeux.
    final f1 = await t.startGesture(a - const Offset(20, 0), pointer: 1);
    final f2 = await t.startGesture(a + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(a - const Offset(70, 0));
    await f2.moveTo(a + const Offset(70, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(state(t).dragStarts, 0,
        reason: 'deux doigts ne doivent jamais saisir un élève');
    expect(state(t).dropped, isNull);
    expect(state(t).scale, greaterThan(1));
  });

  testWidgets('le second doigt arrivant en retard zoome quand même', (t) async {
    await t.pumpWidget(const _Harness());
    final center = t.getCenter(find.byType(PlanViewport));

    // Cas réel : les deux doigts ne se posent jamais dans la même frame, et le
    // premier bouge un peu en attendant. Tant qu'il reste sous le seuil de
    // déplacement, le pincement doit encore être possible.
    final f1 = await t.startGesture(center - const Offset(20, 0), pointer: 1);
    await t.pump(const Duration(milliseconds: 40));
    await f1.moveBy(const Offset(6, 0)); // sous kTouchSlop (18 px)
    await t.pump(const Duration(milliseconds: 40));

    final f2 = await t.startGesture(center + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(80, 0));
    await f2.moveTo(center + const Offset(80, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(state(t).scale, greaterThan(1),
        reason: 'un léger mouvement avant le second doigt ne doit pas '
            'condamner le pincement');
    expect(state(t).dragStarts, 0);
  });

  testWidgets('le zoom reste borné entre la vue d\'ensemble et ×3', (t) async {
    final key = GlobalKey<PlanViewportState>();
    await t.pumpWidget(_Harness(viewportKey: key));
    final center = t.getCenter(find.byType(PlanViewport));

    // Écartement très large : doit plafonner à 3.
    final f1 = await t.startGesture(center - const Offset(10, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(10, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(400, 0));
    await f2.moveTo(center + const Offset(400, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(key.currentState!.scale, 3);
    expect(key.currentState!.isZoomed, isTrue);

    // Pincement inverse très serré : ne doit pas descendre sous 1. On reste à
    // ±150 : à ±200 le second doigt tomberait sur le bord droit exclusif de la
    // fenêtre, donc n'atteindrait aucun reconnaisseur.
    final g1 = await t.startGesture(center - const Offset(150, 0), pointer: 3);
    final g2 = await t.startGesture(center + const Offset(150, 0), pointer: 4);
    await t.pump();
    await g1.moveTo(center - const Offset(5, 0));
    await g2.moveTo(center + const Offset(5, 0));
    await t.pump();
    await g1.up();
    await g2.up();
    await t.pumpAndSettle();

    expect(key.currentState!.scale, 1);
    expect(key.currentState!.isZoomed, isFalse);
  });

  testWidgets('recentrer revient à la vue d\'ensemble', (t) async {
    final key = GlobalKey<PlanViewportState>();
    await t.pumpWidget(_Harness(viewportKey: key));
    final center = t.getCenter(find.byType(PlanViewport));

    final f1 = await t.startGesture(center - const Offset(20, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(80, 0));
    await f2.moveTo(center + const Offset(80, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(key.currentState!.isZoomed, isTrue);

    key.currentState!.recenter();
    await t.pumpAndSettle();

    expect(key.currentState!.scale, 1);
    expect(key.currentState!.isZoomed, isFalse);
  });

  testWidgets('la trace de diagnostic rapporte le zoom', (t) async {
    final log = <String>[];
    await t.pumpWidget(_Harness(diagnostics: log));
    final center = t.getCenter(find.byType(PlanViewport));

    final f1 = await t.startGesture(center - const Offset(20, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(70, 0));
    await f2.moveTo(center + const Offset(70, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(log.where((l) => l.startsWith('zoom début')), hasLength(1));
    expect(log.where((l) => l.startsWith('zoom fin')), hasLength(1));
    expect(log.first, contains('2 doigts'));
  });

  testWidgets('un doigt sur le vide ne déplace pas la vue', (t) async {
    final log = <String>[];
    await t.pumpWidget(_Harness(diagnostics: log));
    final center = t.getCenter(find.byType(PlanViewport));

    // L'espace entre les deux places n'a aucun Draggable : rien ne dispute le
    // geste au reconnaisseur de zoom, qui doit pourtant renoncer de lui-même.
    await t.dragFrom(center, const Offset(60, 0), pointer: 1);
    await t.pumpAndSettle();

    expect(state(t).scale, 1, reason: 'un doigt ne déplace jamais la vue');
    expect(log.where((l) => l.startsWith('zoom début')), isEmpty,
        reason: 'aucun geste de zoom ne doit être ouvert par un seul doigt');
  });

  testWidgets('zoomé, un doigt sur le vide ne déplace toujours pas la vue',
      (t) async {
    // Le test précédent ne prouve rien à l'échelle 1, où la translation est
    // bornée à zéro quoi qu'il arrive. C'est zoomé que le défaut se voyait :
    // le reconnaisseur gagnait l'arène avec un seul doigt et déplaçait la vue.
    final key = GlobalKey<PlanViewportState>();
    await t.pumpWidget(_Harness(viewportKey: key));
    final center = t.getCenter(find.byType(PlanViewport));

    final f1 = await t.startGesture(center - const Offset(20, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(50, 0));
    await f2.moveTo(center + const Offset(50, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(key.currentState!.isZoomed, isTrue);

    // Position à l'écran d'une place, avant et après un glissement à un doigt
    // dans le vide : la vue ne doit pas avoir bougé d'un pixel.
    final before = t.getRect(find.byKey(const Key('seatA')));
    await t.dragFrom(center, const Offset(70, 40), pointer: 3);
    await t.pumpAndSettle();
    final after = t.getRect(find.byKey(const Key('seatA')));

    expect(after, before,
        reason: 'seuls deux doigts déplacent la vue');
  });

  testWidgets('un doigt annulé libère le compteur', (t) async {
    await t.pumpWidget(const _Harness());

    // Un pointeur annulé (appel entrant, geste système…) doit décrémenter le
    // compteur : sinon il reste bloqué à 1, et un pincement ultérieur serait
    // pris pour un simple glissement — ou pire, les places deviendraient
    // insaisissables.
    final g = await t.startGesture(seatA(t), pointer: 1);
    await t.pump();
    expect(state(t).tracker.count, 1);

    await g.cancel();
    await t.pumpAndSettle();
    expect(state(t).tracker.count, 0, reason: 'le compteur doit se libérer');

    // Et tout fonctionne encore après.
    await t.drag(find.text('A'), target(t) - seatA(t), pointer: 2);
    await t.pumpAndSettle();
    expect(state(t).dropped, 'eleve');
  });

  testWidgets('après un zoom, un doigt saisit toujours un élève', (t) async {
    final key = GlobalKey<PlanViewportState>();
    await t.pumpWidget(_Harness(viewportKey: key));
    final center = t.getCenter(find.byType(PlanViewport));

    final f1 = await t.startGesture(center - const Offset(20, 0), pointer: 1);
    final f2 = await t.startGesture(center + const Offset(20, 0), pointer: 2);
    await t.pump();
    await f1.moveTo(center - const Offset(30, 0));
    await f2.moveTo(center + const Offset(30, 0));
    await t.pump();
    await f1.up();
    await f2.up();
    await t.pumpAndSettle();

    expect(key.currentState!.isZoomed, isTrue);

    // Une fois zoomé, la place déborde de la fenêtre : on part du point
    // réellement visible, sinon le hit-test tombe dans la zone rognée.
    final seat = t.getRect(find.byKey(const Key('seatA')));
    final visible = seat.intersect(t.getRect(find.byType(PlanViewport)));
    expect(visible.isEmpty, isFalse,
        reason: 'la place doit rester partiellement visible à ce zoom');

    await t.dragFrom(visible.center, const Offset(40, 0), pointer: 5);
    await t.pumpAndSettle();

    expect(state(t).dragStarts, 1,
        reason: 'le glisser-déposer doit survivre au zoom');
  });
}
