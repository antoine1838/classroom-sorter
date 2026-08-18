/// Fenêtre de zoom du plan, avec un arbitrage explicite des gestes :
///
///  - **un doigt** ne zoome jamais : le geste est laissé aux enfants, donc au
///    glisser-déposer d'un élève ;
///  - **deux doigts** zooment et déplacent la vue, jamais un élève.
///
/// C'est le point risqué de la refonte de l'écran Plan : `InteractiveViewer`
/// capte les gestes à un seul pointeur et entre alors en concurrence avec le
/// `Draggable` des places. On ne l'utilise donc pas — on pilote la transformation
/// à la main derrière un [ScaleGestureRecognizer] qui refuse l'arène tant qu'il
/// n'a pas deux doigts.
///
/// Le contenu est supposé déjà mis à l'échelle pour tenir dans la fenêtre (le
/// `FittedBox` de la grille) : l'échelle 1 est donc la vue d'ensemble, et le
/// zoom vient par-dessus.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Compte les doigts actuellement posés dans la fenêtre du plan.
///
/// Partagé entre [PlanViewport] et les places déplaçables, parce que
/// l'arbitrage ne peut pas se faire d'un seul côté. Le `Draggable` standard
/// s'appuie sur un reconnaisseur *multi*-drag qui gagne l'arène pointeur par
/// pointeur : un pincement posé sur une place déclenche donc un glisser par
/// doigt — mesuré, deux glissers — et le zoom n'a jamais lieu. Il faut que la
/// place refuse elle aussi de se laisser saisir quand un second doigt est là.
class PointerTracker {
  int _count = 0;

  int get count => _count;

  void down() => _count++;

  void up() {
    if (_count > 0) _count--;
  }
}

/// Place déplaçable qui ne se laisse saisir que par un seul doigt.
///
/// Identique à [Draggable] en tout point, sauf que son reconnaisseur abandonne
/// dès qu'un second doigt est posé : le pincement revient alors au
/// [PlanViewport].
class SeatDraggable<T extends Object> extends Draggable<T> {
  const SeatDraggable({
    super.key,
    required super.child,
    required super.feedback,
    required this.tracker,
    super.data,
    super.childWhenDragging,
    super.onDragStarted,
  });

  final PointerTracker tracker;

  @override
  MultiDragGestureRecognizer createRecognizer(
          GestureMultiDragStartCallback onStart) =>
      _OneFingerDragRecognizer(tracker: tracker, debugOwner: this)
        ..onStart = onStart;
}

class _OneFingerDragRecognizer extends MultiDragGestureRecognizer {
  _OneFingerDragRecognizer({required this.tracker, super.debugOwner});

  final PointerTracker tracker;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _OneFingerPointerState(
          event.position, event.kind, gestureSettings, tracker);

  @override
  String get debugDescription => 'glisser une place (un seul doigt)';
}

class _OneFingerPointerState extends MultiDragPointerState {
  _OneFingerPointerState(
    super.initialPosition,
    super.kind,
    super.deviceGestureSettings,
    this.tracker,
  );

  final PointerTracker tracker;

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (tracker.count >= 2) {
      // Deux doigts : c'est un pincement, pas un déplacement d'élève.
      resolve(GestureDisposition.rejected);
      return;
    }
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

/// Reconnaisseur de pincement qui n'entre en jeu qu'à partir de [minPointers]
/// doigts.
///
/// Subtilité qui fait tout le sujet : les deux doigts d'un pincement n'arrivent
/// jamais dans la même frame. Refuser l'arène dès le premier mouvement à un
/// doigt rendrait le zoom impossible, parce que le second doigt arriverait après
/// le refus. On n'abandonne donc que lorsque le doigt unique a franchi le seuil
/// de déplacement ([kTouchSlop]) — à ce moment-là c'est un vrai glissement, pas
/// le début d'un pincement.
class MultiPointerScaleRecognizer extends ScaleGestureRecognizer {
  MultiPointerScaleRecognizer({super.debugOwner, this.minPointers = 2});

  final int minPointers;

  final Map<int, Offset> _origins = <int, Offset>{};
  bool _gaveUp = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origins[event.pointer] = event.position;
    if (_origins.length >= minPointers) {
      // Le pincement est constitué : on redevient candidat même si un
      // glissement à un doigt avait commencé à s'éloigner.
      _gaveUp = false;
    }
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _origins.remove(event.pointer);
      if (_origins.isEmpty) _gaveUp = false;
    }

    if (!_gaveUp &&
        _origins.length < minPointers &&
        event is PointerMoveEvent &&
        _movedPastSlop(event)) {
      // Un seul doigt qui glisse franchement : ce n'est pas un pincement.
      // On laisse la main aux enfants (glisser-déposer d'un élève).
      _gaveUp = true;
      resolve(GestureDisposition.rejected);
      return;
    }

    if (_gaveUp) return;
    super.handleEvent(event);
  }

  bool _movedPastSlop(PointerMoveEvent event) {
    final origin = _origins[event.pointer];
    if (origin == null) return false;
    return (event.position - origin).distance > computeHitSlop(
      event.kind,
      gestureSettings,
    );
  }

  @override
  void dispose() {
    _origins.clear();
    super.dispose();
  }
}

/// Fenêtre zoomable autour du plan.
class PlanViewport extends StatefulWidget {
  const PlanViewport({
    super.key,
    required this.child,
    required this.tracker,
    this.minScale = 1,
    this.maxScale = 3,
    this.onScaleChanged,
    this.onDiagnostic,
  });

  final Widget child;

  /// Compteur de doigts, à partager avec les [SeatDraggable] du contenu.
  final PointerTracker tracker;

  /// Échelle minimale. 1 = la vue d'ensemble, puisque le contenu est déjà ajusté.
  final double minScale;
  final double maxScale;

  /// Notifie l'échelle courante, dont dépend le contenu des places : au-delà
  /// d'une certaine taille rendue, une case affiche le prénom plutôt que les
  /// initiales.
  final ValueChanged<double>? onScaleChanged;

  /// Trace des gestes, pour le prototype sur appareil. Sans effet en production.
  final ValueChanged<String>? onDiagnostic;

  @override
  State<PlanViewport> createState() => PlanViewportState();
}

class PlanViewportState extends State<PlanViewport> {
  double _scale = 1;
  Offset _translation = Offset.zero;

  double _startScale = 1;
  Offset _childFocal = Offset.zero;
  Size _viewport = Size.zero;

  /// Vrai dès qu'on n'est plus sur la vue d'ensemble : le bouton « recentrer »
  /// n'a de sens qu'à ce moment-là.
  bool get isZoomed => _scale > widget.minScale + 0.001;

  double get scale => _scale;

  /// Revient à la vue d'ensemble.
  void recenter() {
    setState(() {
      _scale = widget.minScale;
      _translation = Offset.zero;
    });
    widget.onScaleChanged?.call(_scale);
    widget.onDiagnostic?.call('recentrage');
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _childFocal = (details.localFocalPoint - _translation) / _scale;
    widget.onDiagnostic
        ?.call('zoom début (${details.pointerCount} doigts)');
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final next = (_startScale * details.scale)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    setState(() {
      _scale = next;
      _translation = _clampTranslation(
        details.localFocalPoint - _childFocal * next,
        next,
      );
    });
    widget.onScaleChanged?.call(next);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    widget.onDiagnostic?.call('zoom fin (×${_scale.toStringAsFixed(2)})');
  }

  /// Garde le contenu couvrant la fenêtre : pas de bande vide sur les bords.
  /// À l'échelle 1 la seule translation possible est nulle.
  Offset _clampTranslation(Offset t, double scale) {
    if (_viewport.isEmpty) return Offset.zero;
    final minX = _viewport.width * (1 - scale);
    final minY = _viewport.height * (1 - scale);
    return Offset(
      t.dx.clamp(minX <= 0 ? minX : 0, 0).toDouble(),
      t.dy.clamp(minY <= 0 ? minY : 0, 0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        // Le Listener est au-dessus du reconnaisseur : il voit tous les doigts,
        // quel que soit le vainqueur de l'arène.
        return ClipRect(
          child: Listener(
            onPointerDown: (_) => widget.tracker.down(),
            onPointerUp: (_) => widget.tracker.up(),
            onPointerCancel: (_) => widget.tracker.up(),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                MultiPointerScaleRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        MultiPointerScaleRecognizer>(
                  () => MultiPointerScaleRecognizer(debugOwner: this),
                  (instance) => instance
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate
                    ..onEnd = _onScaleEnd,
                ),
              },
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(_translation.dx, _translation.dy, 0, 1)
                  ..scaleByDouble(_scale, _scale, 1, 1),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
