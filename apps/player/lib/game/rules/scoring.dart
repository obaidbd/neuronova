import 'dart:math';

const maxRoundScore = 10;

int hintFactorPercent(int hints) => max(0, 100 - 25 * hints);

/// Accuracy earns points; speed can only boost points from a correct answer.
/// A round awards 0–10 points, with no participation points for a wrong answer.
int gameScore({
  required double accuracy,
  required bool timed,
  required int hints,
  int? targetMs,
  int? actualMs,
}) {
  final acc = accuracy.clamp(0.0, 1.0);
  if (acc == 0) return 0;
  final hint = hintFactorPercent(hints) / 100;
  final speed = targetMs == null || actualMs == null || actualMs <= 0
      ? 0.0
      : (targetMs / actualMs).clamp(0.0, 1.0);
  final timing = timed ? 0.8 + 0.2 * speed : 1.0;
  return (maxRoundScore * acc * timing * hint).round().clamp(0, maxRoundScore);
}

/// Full completion earns up to 2 XP; replay rewards remain reduced.
int xpForScore(int score, {required bool firstCompletion}) {
  final base = (score.clamp(0, maxRoundScore) / 5).round();
  return firstCompletion ? base : (base / 4).floor();
}
