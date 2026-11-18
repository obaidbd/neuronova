import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/content/bd_map.dart';
import '../../game/rules/map_puzzle.dart';

/// Pastel colours of the eight divisions (like the printed puzzle board).
const divisionColors = [
  Color(0xFFE8B4B8), // Chattogram
  Color(0xFFB8D4E8), // Dhaka
  Color(0xFFF2E2A0), // Mymensingh
  Color(0xFFB9E0B0), // Rajshahi
  Color(0xFFD4B8E8), // Rangpur
  Color(0xFFF0C8A0), // Sylhet
  Color(0xFFA8E0D8), // Khulna
  Color(0xFFE0E0E0), // Barishal
];

Color colorOf(BdMap map, MapUnit u) =>
    divisionColors[map.divisionIndex(u) % divisionColors.length];

/// Fits a region's projected bounds into a pixel size, keeping its shape.
class MapProjection {
  MapProjection(this.bounds, this.size, {this.padding = 10}) {
    final w = size.width - padding * 2, h = size.height - padding * 2;
    scale = min(w / bounds.width, h / bounds.height);
    offset = Offset(
      padding + (w - bounds.width * scale) / 2 - bounds.left * scale,
      padding + (h - bounds.height * scale) / 2 - bounds.top * scale,
    );
  }
  final Rect bounds;
  final Size size;
  final double padding;
  late final double scale;
  late final Offset offset;

  Offset toBoard(Offset p) => p * scale + offset;
  Offset fromBoard(Offset b) => (b - offset) / scale;
  Rect rectToBoard(Rect r) =>
      Rect.fromPoints(toBoard(r.topLeft), toBoard(r.bottomRight));
}

Path pathOf(MapUnit u, Offset Function(Offset) f) {
  final path = Path();
  for (final ring in u.rings) {
    path.addPolygon([for (final p in ring) f(p)], true);
  }
  return path;
}

/// Draws the map board: outlined slots, placed pieces, hints and names.
class MapBoardPainter extends CustomPainter {
  MapBoardPainter({
    required this.puzzle,
    required this.map,
    required this.projection,
    required this.paths,
    required this.controller,
    required this.pulse,
    this.hintId,
    this.wrongId,
  }) : super(repaint: Listenable.merge([controller, pulse]));

  final MapPuzzle puzzle;
  final BdMap map;
  final MapProjection projection;
  final Map<String, Path> paths;
  final TransformationController controller;
  final Animation<double> pulse;
  final String? hintId, wrongId;

  static final Map<String, TextPainter> _labels = {};

  /// Forget laid-out names: needed when fallback fonts (Bengali) finish
  /// loading, because a TextPainter laid out earlier keeps its missing-glyph
  /// boxes.
  static void clearLabels() => _labels.clear();

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = controller.value.getMaxScaleOnAxis();
    // Big regions first so a small one inside a big one stays visible.
    final units = [...puzzle.pieces]..sort((a, b) => b.area.compareTo(a.area));
    // Empty places. Every slot's edge is drawn first, then every slot's face
    // on top, so the edge between two neighbours disappears under the faces
    // and only the area's outer outline remains. Unless the board look is
    // Blank, each face carries a faint tint of its division and a hairline
    // border (drawn last, over all faces) so the extent of every place is
    // visible without any names.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 / zoom
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF8FA9BC);
    final blank = const Color(0xFFF7FAFC);
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8 / zoom
      ..color = blank;
    final empty = [
      for (final u in units)
        if (!puzzle.placed.contains(u.id)) u,
    ];
    for (final u in empty) {
      canvas.drawPath(paths[u.id]!, edge);
    }
    final face = Paint();
    for (final u in empty) {
      final path = paths[u.id]!;
      face.color = puzzle.look.showSlots
          ? Color.lerp(Colors.white, colorOf(map, u), .42)!
          : blank;
      canvas.drawPath(path, face);
      if (!puzzle.look.showSlots) canvas.drawPath(path, seam);
    }
    if (puzzle.look.showSlots) {
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55 / zoom
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF8FA9BC).withValues(alpha: .7);
      for (final u in empty) {
        canvas.drawPath(paths[u.id]!, border);
      }
    }
    // Placed pieces sit in their slots with a thin white edge.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 / zoom
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    final fill = Paint();
    for (final u in units) {
      if (!puzzle.placed.contains(u.id)) continue;
      final path = paths[u.id]!;
      canvas.drawPath(path, fill..color = colorOf(map, u));
      canvas.drawPath(path, line);
    }
    // The hint pulses; a wrong drop flashes red.
    final h = hintId == null ? null : paths[hintId];
    if (h != null) {
      final t = pulse.value;
      canvas.drawPath(
        h,
        Paint()..color = NovaColors.gold.withValues(alpha: .25 + .35 * t),
      );
      canvas.drawPath(
        h,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2 + 2 * t) / zoom
          ..color = const Color(0xFFE59A00),
      );
    }
    final w = wrongId == null ? null : paths[wrongId];
    if (w != null) {
      canvas.drawPath(
        w,
        Paint()..color = NovaColors.danger.withValues(alpha: .55),
      );
    }
    _names(canvas, size, units, zoom);
  }

  /// A name is drawn once its place is big enough on screen for the whole name
  /// to fit inside it (zoom in on crowded areas). Placed pieces always show
  /// theirs; empty places only with the "names" board look.
  void _names(Canvas canvas, Size size, List<MapUnit> units, double zoom) {
    final inv = Matrix4.copy(controller.value)..invert();
    final view = MatrixUtils.transformRect(inv, Offset.zero & size);
    for (final u in units) {
      final placed = puzzle.placed.contains(u.id);
      if (!placed && !puzzle.look.namesOnSlots) continue;
      final box = projection.rectToBoard(u.bounds);
      if (!box.overlaps(view)) continue;
      final onScreen = box.width * zoom;
      if (onScreen < 34) continue;
      final px = (onScreen * .17).clamp(9.0, 13.0);
      final fontScene = px / zoom;
      final key =
          '${u.id}${placed ? 'p' : 'e'}@${fontScene.toStringAsFixed(2)}';
      final tp = _labels.putIfAbsent(key, () {
        if (_labels.length > 800) _labels.clear();
        return TextPainter(
          text: TextSpan(
            text: u.nameBn(),
            style: TextStyle(
              fontSize: fontScene,
              fontWeight: FontWeight.w600,
              color: placed ? const Color(0xFF1C2B3A) : const Color(0xFF55708A),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
      });
      if (tp.width > box.width * .92) continue; // does not fit yet: zoom in
      final c = projection.toBoard(u.label);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // Pieces are placed in place and the zoom changes constantly: always repaint.
  @override
  bool shouldRepaint(MapBoardPainter old) => true;
}

/// A small picture of one piece, fitted into its box.
class PiecePainter extends CustomPainter {
  PiecePainter(this.unit, this.color, {this.selected = false});
  final MapUnit unit;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final b = unit.bounds;
    final s = min(size.width / b.width, size.height / b.height) * .92;
    final off = Offset(
      (size.width - b.width * s) / 2 - b.left * s,
      (size.height - b.height * s) / 2 - b.top * s,
    );
    final path = pathOf(unit, (p) => p * s + off);
    canvas.drawPath(
      path.shift(const Offset(0, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: .25),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = selected ? NovaColors.gold : Colors.white,
    );
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.unit != unit || old.color != color || old.selected != selected;
}
