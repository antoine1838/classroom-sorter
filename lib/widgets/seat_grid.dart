/// Grilles réutilisables de la salle :
///  - [RoomEditorGrid] : éditer le plan (toucher une case pour retirer/remettre
///    une place — utile pour dessiner les allées).
///  - [PlanGrid] : afficher l'affectation, avec glisser-déposer pour échanger
///    deux élèves à la main.
library;

import 'package:flutter/material.dart';

import '../models/classroom.dart';
import '../models/room.dart';
import '../models/student.dart';

const double kCell = 62;
const double kGap = 6;

double gridWidth(Room room) => room.cols * kCell + (room.cols - 1) * kGap;

Color studentColor(Student s, ColorScheme cs) => switch (s.gender) {
      Gender.fille => const Color(0xFFF3B8D0),
      Gender.garcon => const Color(0xFFA9CCF5),
      Gender.autre => cs.surfaceContainerHighest,
    };

class _FrontBanner extends StatelessWidget {
  final double width;
  const _FrontBanner(this.width);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width < 120 ? 120 : width,
      margin: const EdgeInsets.only(bottom: kGap + 2),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text('⬆  DEVANT (tableau)',
          style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Enveloppe scrollable (H + V) commune aux deux grilles.
class _ScrollableGrid extends StatelessWidget {
  final Room room;
  final Widget Function(int r, int c) cellBuilder;
  const _ScrollableGrid({required this.room, required this.cellBuilder});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FrontBanner(gridWidth(room)),
              for (var r = 0; r < room.rows; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: kGap),
                  child: Row(
                    children: [
                      for (var c = 0; c < room.cols; c++)
                        Padding(
                          padding: EdgeInsets.only(
                              right: c < room.cols - 1 ? kGap : 0),
                          child: cellBuilder(r, c),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomEditorGrid extends StatelessWidget {
  final Room room;
  final VoidCallback onChanged;
  const RoomEditorGrid({super.key, required this.room, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ScrollableGrid(
      room: room,
      cellBuilder: (r, c) {
        final isSeat = room.isSeat(r, c);
        return InkWell(
          onTap: () {
            room.toggle(r, c);
            onChanged();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: kCell,
            height: kCell,
            decoration: BoxDecoration(
              color: isSeat ? cs.surface : cs.surfaceContainerLow,
              border: Border.all(
                color: isSeat ? cs.primary : cs.outlineVariant,
                width: isSeat ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSeat ? Icons.event_seat_outlined : Icons.block,
              color: isSeat ? cs.primary : cs.outlineVariant,
              size: 26,
            ),
          ),
        );
      },
    );
  }
}

class PlanGrid extends StatelessWidget {
  final ClassGroup cls;

  /// Échanger les occupants de deux places (glisser-déposer).
  final void Function(String seatA, String seatB) onSwap;

  const PlanGrid({super.key, required this.cls, required this.onSwap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ScrollableGrid(
      room: cls.room,
      cellBuilder: (r, c) {
        if (!cls.room.isSeat(r, c)) {
          // Allée / vide : simple espace.
          return const SizedBox(width: kCell, height: kCell);
        }
        final seatKey = Room.keyOf(r, c);
        final student = cls.studentById(cls.assignment[seatKey]);

        return DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data != seatKey,
          onAcceptWithDetails: (d) => onSwap(d.data, seatKey),
          builder: (context, candidate, rejected) {
            final hovering = candidate.isNotEmpty;
            final cell = _seatContent(context, student, hovering);
            if (student == null) return cell;
            // Occupé : rendre l'élève déplaçable.
            return Draggable<String>(
              data: seatKey,
              feedback: Material(
                color: Colors.transparent,
                child: _seatContent(context, student, false, elevated: true),
              ),
              childWhenDragging: _emptySeat(cs, false),
              child: cell,
            );
          },
        );
      },
    );
  }

  Widget _seatContent(BuildContext context, Student? student, bool hovering,
      {bool elevated = false}) {
    final cs = Theme.of(context).colorScheme;
    if (student == null) return _emptySeat(cs, hovering);
    return Container(
      width: kCell,
      height: kCell,
      decoration: BoxDecoration(
        color: studentColor(student, cs),
        border: Border.all(
          color: hovering ? cs.primary : cs.outline,
          width: hovering ? 2.4 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: elevated
            ? [const BoxShadow(blurRadius: 8, color: Colors.black26)]
            : null,
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(student.initials,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            student.firstName.isEmpty ? student.fullName : student.firstName,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptySeat(ColorScheme cs, bool hovering) => Container(
        width: kCell,
        height: kCell,
        decoration: BoxDecoration(
          color: hovering ? cs.primaryContainer : cs.surface,
          border: Border.all(
            color: hovering ? cs.primary : cs.outlineVariant,
            width: hovering ? 2.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.event_seat_outlined, color: cs.outlineVariant, size: 22),
      );
}
