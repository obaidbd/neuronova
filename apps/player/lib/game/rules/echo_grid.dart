import 'dart:math';

/// Difficulty band configuration for Echo Grid (spec §6).
class EchoGridConfig {
  const EchoGridConfig({
    required this.size,
    required this.targets,
    required this.previewMs,
  });

  final int size;
  final int targets;
  final int previewMs;

  int get cells => size * size;

  /// Levels 1–20. Grid size increases from 3×3 to 7×7.
  /// Tier 2/5/8 match the spec's starting configurations.
  factory EchoGridConfig.forTier(int tier) {
    final t = tier.clamp(1, 20);
    if (t > 10) {
      return EchoGridConfig(
        size: t <= 15 ? 6 : 7,
        targets: 10 + (t - 10),
        previewMs: 2000,
      );
    }
    if (t <= 3) {
      return EchoGridConfig(size: 3, targets: t == 3 ? 4 : 3, previewMs: 4000);
    }
    if (t <= 6) {
      return EchoGridConfig(size: 4, targets: t == 6 ? 6 : 5, previewMs: 3000);
    }
    return EchoGridConfig(
      size: 5,
      targets: t >= 9 ? 8 + (t - 8) : 8,
      previewMs: 2000,
    );
  }
}

class EchoGridPuzzle {
  const EchoGridPuzzle({
    required this.config,
    required this.targets,
    required this.seed,
    required this.generatorVersion,
  });

  static const currentGeneratorVersion = 1;

  final EchoGridConfig config;
  final Set<int> targets;
  final int seed;
  final int generatorVersion;

  /// Deterministic for (tier, seed, generatorVersion).
  factory EchoGridPuzzle.generate({required int tier, required int seed}) {
    final config = EchoGridConfig.forTier(tier);
    final rng = Random(seed);
    final all = List<int>.generate(config.cells, (i) => i)..shuffle(rng);
    return EchoGridPuzzle(
      config: config,
      targets: all.take(config.targets).toSet(),
      seed: seed,
      generatorVersion: currentGeneratorVersion,
    );
  }

  /// Compares a submission to the target set.
  EchoGridResult evaluate(Set<int> selection) {
    final valid =
        selection.every((c) => c >= 0 && c < config.cells) &&
        selection.length <= config.targets;
    if (!valid) {
      throw ArgumentError('Illegal selection');
    }
    final hits = selection.intersection(targets).length;
    final wrong = selection.length - hits;
    final accuracy = ((hits - wrong).clamp(0, config.targets)) / config.targets;
    return EchoGridResult(
      hits: hits,
      wrong: wrong,
      accuracy: accuracy,
      perfect: hits == config.targets && wrong == 0,
    );
  }
}

class EchoGridResult {
  const EchoGridResult({
    required this.hits,
    required this.wrong,
    required this.accuracy,
    required this.perfect,
  });
  final int hits;
  final int wrong;
  final double accuracy;
  final bool perfect;
}
