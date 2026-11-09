import 'dart:math';

class FocusItem {
  const FocusItem(this.shape, this.color);
  final int shape, color;
}

class FocusPuzzle {
  FocusPuzzle({
    required this.targetShape,
    required this.targetColor,
    required this.items,
    required this.targets,
    required this.cols,
    required this.tier,
    required this.seed,
  });

  final int targetShape, targetColor, cols, tier, seed;
  final List<FocusItem> items;
  final Set<int> targets;

  bool isTarget(FocusItem i) =>
      i.shape == targetShape && i.color == targetColor;

  static FocusPuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    final rng = Random(seed);
    final ts = rng.nextInt(4), tc = rng.nextInt(4);
    final count = min(8 + t, 18);
    final nTargets = 3 + t ~/ 4;
    final items = <FocusItem>[];
    for (var i = 0; i < count; i++) {
      if (i < nTargets) {
        items.add(FocusItem(ts, tc));
        continue;
      }
      FocusItem d;
      do {
        if (t <= 3) {
          // Easy: differs in both properties.
          d = FocusItem(
            (ts + 1 + rng.nextInt(3)) % 4,
            (tc + 1 + rng.nextInt(3)) % 4,
          );
        } else {
          // Harder: often shares one property with the target.
          final keepShape = rng.nextBool();
          d = keepShape
              ? FocusItem(ts, (tc + 1 + rng.nextInt(3)) % 4)
              : FocusItem((ts + 1 + rng.nextInt(3)) % 4, tc);
        }
      } while (d.shape == ts && d.color == tc);
      items.add(d);
    }
    items.shuffle(rng);
    final targets = <int>{
      for (var i = 0; i < items.length; i++)
        if (items[i].shape == ts && items[i].color == tc) i,
    };
    return FocusPuzzle(
      targetShape: ts,
      targetColor: tc,
      items: items,
      targets: targets,
      cols: count > 12 ? 5 : 4,
      tier: t,
      seed: seed,
    );
  }

  ({int hits, int wrong, double accuracy, bool perfect}) evaluate(
    Set<int> selection,
  ) {
    if (selection.any((i) => i < 0 || i >= items.length)) {
      throw ArgumentError('Illegal selection');
    }
    final hits = selection.intersection(targets).length;
    final wrong = selection.length - hits;
    final acc = ((hits - wrong).clamp(0, targets.length)) / targets.length;
    return (
      hits: hits,
      wrong: wrong,
      accuracy: acc,
      perfect: hits == targets.length && wrong == 0,
    );
  }
}
