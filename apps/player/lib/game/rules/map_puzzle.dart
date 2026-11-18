import 'dart:math';
import 'dart:ui';

import '../content/bd_map.dart';

/// How much help the player gets. The board itself is always one blank
/// outline of the area (no inner lines, no names), like the physical puzzle;
/// the help level changes the pieces and how forgiving a drop is.
enum MapHelp {
  /// Names on the pieces, generous drops, a wrong drop says which region it was.
  easy,

  /// Names on the pieces, moderate drops.
  normal,

  /// No names anywhere until a piece is placed; precise drops.
  hard,
}

extension MapHelpInfo on MapHelp {
  bool get namesOnPieces => this != MapHelp.hard;

  /// A wrong drop tells the player which region they landed in.
  bool get tellsWrongRegion => this == MapHelp.easy;

  /// How far a drop may miss a slot, as a fraction of the piece's size.
  double get tolerance => switch (this) {
    MapHelp.easy => .5,
    MapHelp.normal => .25,
    MapHelp.hard => .08,
  };
}

/// Practice difficulty (Easy 2, Normal 5, Hard 8), or the player's level when
/// on Auto, to a help level.
MapHelp mapHelpForTier(int tier) => tier <= 3
    ? MapHelp.easy
    : tier <= 6
    ? MapHelp.normal
    : MapHelp.hard;

bool pointInRing(Offset p, List<Offset> ring) {
  var inside = false;
  var j = ring.length - 1;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final d = b - a;
  final len2 = d.dx * d.dx + d.dy * d.dy;
  final t = len2 == 0
      ? 0.0
      : (((p - a).dx * d.dx + (p - a).dy * d.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + d * t)).distance;
}

/// 0 when [p] is inside the unit, else the distance to its nearest edge.
double distanceToUnit(Offset p, MapUnit u) {
  if (!u.bounds.inflate(1).contains(p)) return double.infinity;
  for (final r in u.rings) {
    if (pointInRing(p, r)) return 0;
  }
  var best = double.infinity;
  for (final r in u.rings) {
    for (var i = 0; i < r.length; i++) {
      best = min(best, _segmentDistance(p, r[i], r[(i + 1) % r.length]));
    }
  }
  return best;
}

/// What happened when a piece was dropped.
enum PlaceOutcome {
  /// The piece went into its slot.
  placed,

  /// The piece was dropped in another region: counts as a mistake.
  wrong,

  /// Dropped on open sea / outside the map, or the piece is already placed.
  missed,
}

class MapResult {
  const MapResult({
    required this.accuracy,
    required this.success,
    required this.mistakes,
    required this.hints,
  });
  final double accuracy;
  final bool success;
  final int mistakes, hints;
}

/// A jigsaw of administrative regions. Pure logic: no Flutter widgets.
class MapPuzzle {
  MapPuzzle({
    required this.map,
    required this.selection,
    required this.help,
    int? seed,
  }) : pieces = map.piecesFor(selection) {
    order = [for (final p in pieces) p.id]..shuffle(Random(seed));
  }

  final BdMap map;
  final MapSelection selection;
  final MapHelp help;
  final List<MapUnit> pieces;

  /// The tray order (shuffled, repeatable by seed).
  late final List<String> order;

  final Set<String> placed = {};
  int mistakes = 0, hints = 0;

  /// The region the last wrong drop landed in (for the "that is X" message).
  MapUnit? lastWrong;

  MapUnit unit(String id) => pieces.firstWhere((p) => p.id == id);

  int get total => pieces.length;
  bool get done => placed.length == total;

  /// Tray pieces still to place, in tray order.
  List<String> get remaining => [
    for (final id in order)
      if (!placed.contains(id)) id,
  ];

  /// Bounds of everything in the puzzle.
  Rect get bounds {
    var r = pieces.first.bounds;
    for (final p in pieces) {
      r = r.expandToInclude(p.bounds);
    }
    return r;
  }

  /// The piece whose slot contains [p] (smallest first, so a district inside
  /// a bigger one wins), or null in open water.
  MapUnit? pieceAt(Offset p) {
    MapUnit? best;
    for (final u in pieces) {
      if (u.bounds.contains(p) && distanceToUnit(p, u) == 0) {
        if (best == null || u.area < best.area) best = u;
      }
    }
    return best;
  }

  /// Drop [id] at [p] (projected coordinates).
  ///
  /// * Inside the right slot: placed.
  /// * Inside a different unplaced region: a mistake (unless the point is
  ///   within [slack] of the right slot, a finger-width forgiveness for tiny
  ///   pieces on a small screen; [slack] is in the same units as [p]).
  /// * Between regions or out at sea: placed if it is near enough to the right
  ///   slot, a fraction of the piece's size that depends on the help level;
  ///   otherwise nothing happens (no penalty).
  PlaceOutcome tryPlace(String id, Offset p, {double slack = 0}) {
    if (placed.contains(id)) return PlaceOutcome.missed;
    final u = unit(id);
    final d = distanceToUnit(p, u);
    if (d == 0) return _place(id);
    final other = pieceAt(p);
    if (other != null && other.id != id) {
      if (d <= slack) return _place(id);
      if (placed.contains(other.id)) return PlaceOutcome.missed;
      mistakes++;
      lastWrong = other;
      return PlaceOutcome.wrong;
    }
    if (d <= help.tolerance * u.bounds.longestSide + slack) return _place(id);
    return PlaceOutcome.missed;
  }

  PlaceOutcome _place(String id) {
    placed.add(id);
    lastWrong = null;
    return PlaceOutcome.placed;
  }

  /// Using a hint costs score: it counts against the final points.
  MapUnit useHint(String id) {
    hints++;
    return unit(id);
  }

  /// Accuracy is pieces per attempt; 70% or better is a success.
  MapResult result() {
    final acc = total / (total + mistakes);
    return MapResult(
      accuracy: acc,
      success: acc >= .7,
      mistakes: mistakes,
      hints: hints,
    );
  }
}
