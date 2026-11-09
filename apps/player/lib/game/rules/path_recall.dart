import 'dart:math';

class PathPuzzle {
  PathPuzzle(this.size, this.path, this.reverse, this.tier, this.seed);
  final int size, tier, seed;
  final List<int> path; // cell indices, row-major, path[0] is the start shown
  final bool reverse;

  int get cells => size * size;
  int get previewMs => 1500 + path.length * 450;

  /// The sequence the player must reproduce (including the given start).
  List<int> get expected => reverse ? path.reversed.toList() : path;
  int get start => expected.first;

  static bool adjacent(int size, int a, int b) {
    final ar = a ~/ size, ac = a % size, br = b ~/ size, bc = b % size;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  /// A legal move goes to an unvisited orthogonal neighbour.
  bool isLegalMove(List<int> visited, int next) =>
      next >= 0 &&
      next < cells &&
      !visited.contains(next) &&
      adjacent(size, visited.last, next);

  static PathPuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    final size = t <= 3 ? 4 : (t <= 6 ? 5 : 6);
    final steps = t <= 3 ? 3 + t : (t <= 6 ? 3 + t : 4 + t);
    final rng = Random(seed);
    for (var attempt = 0; attempt < 500; attempt++) {
      var cur = rng.nextInt(size * size);
      final path = [cur];
      while (path.length <= steps) {
        final opts = <int>[];
        final r = cur ~/ size, c = cur % size;
        if (r > 0) opts.add(cur - size);
        if (r < size - 1) opts.add(cur + size);
        if (c > 0) opts.add(cur - 1);
        if (c < size - 1) opts.add(cur + 1);
        opts.removeWhere(path.contains);
        if (opts.isEmpty) break;
        cur = opts[rng.nextInt(opts.length)];
        path.add(cur);
      }
      if (path.length == steps + 1) {
        return PathPuzzle(size, path, t >= 8 && rng.nextBool(), t, seed);
      }
    }
    throw StateError('No path for tier $t seed $seed');
  }

  /// [moves] are the cells tapped after the start.
  ({int correct, double accuracy, bool perfect}) evaluate(List<int> moves) {
    final exp = expected.sublist(1);
    if (moves.length > exp.length || moves.any((m) => m < 0 || m >= cells)) {
      throw ArgumentError('Illegal moves');
    }
    var ok = 0;
    for (var i = 0; i < moves.length; i++) {
      if (moves[i] != exp[i]) break;
      ok++;
    }
    return (
      correct: ok,
      accuracy: ok / exp.length,
      perfect: ok == exp.length && moves.length == exp.length,
    );
  }
}
