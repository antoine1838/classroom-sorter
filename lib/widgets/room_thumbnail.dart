/// Miniature d'une [Room] : un carré par place, sans interaction — les
/// couloirs et les places désactivées restent vides. Le rang 0 (devant,
/// côté tableau) est affiché en bas, comme le reste de l'application.
library;

import 'package:flutter/material.dart';

import '../models/room.dart';

class RoomThumbnail extends StatelessWidget {
  final Room room;
  const RoomThumbnail({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomThumbnailPainter(
        room: room,
        seatColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Cale une [RoomThumbnail] dans une boîte de taille fixe ([width] ×
/// [height]) sans distordre ses cases carrées : la grille est dessinée à sa
/// taille naturelle (proportionnelle à `rows`/`cols`), puis mise à l'échelle
/// en conservant son ratio — comme un `BoxFit.contain` sur une image.
Widget roomThumbnailBox(
  Room room, {
  required double width,
  required double height,
}) {
  const cellSize = 12.0;
  return SizedBox(
    width: width,
    height: height,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: room.cols * cellSize,
        height: room.rows * cellSize,
        child: RoomThumbnail(room: room),
      ),
    ),
  );
}

class _RoomThumbnailPainter extends CustomPainter {
  final Room room;
  final Color seatColor;
  const _RoomThumbnailPainter({required this.room, required this.seatColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (room.rows <= 0 || room.cols <= 0) return;
    final cellSize = (size.width / room.cols) < (size.height / room.rows)
        ? size.width / room.cols
        : size.height / room.rows;
    final offsetX = (size.width - cellSize * room.cols) / 2;
    final offsetY = (size.height - cellSize * room.rows) / 2;
    const gap = 1.0;
    final paint = Paint()..color = seatColor;

    for (var r = 0; r < room.rows; r++) {
      // Le rang 0 (devant, côté tableau) s'affiche en bas.
      final displayRow = room.rows - 1 - r;
      for (var c = 0; c < room.cols; c++) {
        if (!room.isSeat(r, c)) continue;
        final rect = Rect.fromLTWH(
          offsetX + c * cellSize + gap / 2,
          offsetY + displayRow * cellSize + gap / 2,
          cellSize - gap,
          cellSize - gap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.15)),
          paint,
        );
      }
    }
  }

  // Une nouvelle Room est reconstruite à chaque changement de réglage dans
  // le sélecteur de disposition : repeindre systématiquement est plus simple
  // qu'un Room.== sur des Set/Map, pour un coût négligeable (miniature).
  @override
  bool shouldRepaint(covariant _RoomThumbnailPainter oldDelegate) => true;
}
