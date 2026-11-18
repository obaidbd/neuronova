import 'dart:math';

/// A fruit or animal that can appear on a pair of cards.
class FlipSymbol {
  const FlipSymbol(this.emoji, this.name);
  final String emoji, name;
}

const flipSymbols = <FlipSymbol>[
  FlipSymbol('🍎', 'apple'),
  FlipSymbol('🍌', 'banana'),
  FlipSymbol('🍇', 'grapes'),
  FlipSymbol('🍓', 'strawberry'),
  FlipSymbol('🍉', 'watermelon'),
  FlipSymbol('🍊', 'orange'),
  FlipSymbol('🍒', 'cherries'),
  FlipSymbol('🍍', 'pineapple'),
  FlipSymbol('🥝', 'kiwi'),
  FlipSymbol('🍑', 'peach'),
  FlipSymbol('🐯', 'tiger'),
  FlipSymbol('🐰', 'rabbit'),
  FlipSymbol('🐼', 'panda'),
  FlipSymbol('🦁', 'lion'),
  FlipSymbol('🐸', 'frog'),
  FlipSymbol('🐵', 'monkey'),
  FlipSymbol('🐶', 'dog'),
  FlipSymbol('🐱', 'cat'),
  FlipSymbol('🐘', 'elephant'),
  FlipSymbol('🐮', 'cow'),
];

class FlipResult {
  const FlipResult({
    required this.accuracy,
    required this.perfect,
    required this.mistakes,
  });
  final double accuracy;
  final bool perfect;
  final int mistakes;
}

/// Flip two cards at a time and find every matching pair of fruits / animals.
/// Every card is face down; the layout comes from [seed] so it is repeatable.
class FlipPuzzle {
  FlipPuzzle({
    required this.pairs,
    required this.cols,
    required this.cards,
    required this.tier,
    required this.seed,
  });

  final int pairs, cols, tier, seed;

  /// Index into [flipSymbols] for each card position; each value appears twice.
  final List<int> cards;

  /// Pairs per tier: 3, 4, 5, 6, 8, 9, 10, 12, 12, 12 (6 to 24 cards).
  static int pairsForTier(int tier) =>
      const [3, 4, 5, 6, 8, 9, 10, 12, 12, 12][tier.clamp(1, 10) - 1];

  static int colsFor(int cardCount) => switch (cardCount) {
    6 || 18 => 3,
    10 => 5,
    _ => 4,
  };

  static FlipPuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    final rng = Random(seed);
    final pairs = pairsForTier(t);
    final ids = List<int>.generate(flipSymbols.length, (i) => i)..shuffle(rng);
    final cards = <int>[
      for (final id in ids.take(pairs)) ...[id, id],
    ]..shuffle(rng);
    return FlipPuzzle(
      pairs: pairs,
      cols: colsFor(cards.length),
      cards: cards,
      tier: t,
      seed: seed,
    );
  }

  bool isMatch(int a, int b) => a != b && cards[a] == cards[b];

  /// Positions of the second card of each pair, given the first; for tests.
  int partnerOf(int index) {
    for (var i = 0; i < cards.length; i++) {
      if (i != index && cards[i] == cards[index]) return i;
    }
    return index;
  }

  /// Accuracy is pairs found per attempt. A round counts as a success when at
  /// least 70% of attempts were right, so a good memory is rewarded but a few
  /// misses are fine.
  FlipResult evaluate({required int mistakes}) {
    final accuracy = pairs / (pairs + max(0, mistakes));
    return FlipResult(
      accuracy: accuracy,
      perfect: accuracy >= .7,
      mistakes: mistakes,
    );
  }
}
