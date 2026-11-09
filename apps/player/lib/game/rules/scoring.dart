import 'dart:math';

/// Spec §16. All inputs validated; pure functions.
int hintFactorPercent(int hints) => max(0, 100 - 25 * hints);

int gameScore({
  required double accuracy,
  required bool timed,
  required int hints,
  int? targetMs,
  int? actualMs,
}) {
  final acc = accuracy.clamp(0.0, 1.0);
  final hint = hintFactorPercent(hints) / 100;
  if (!timed) {
    return (100 * (0.90 * acc + 0.10 * hint)).round();
  }
  final speed = (targetMs == null || actualMs == null || actualMs <= 0)
      ? 0.0
      : (targetMs / actualMs).clamp(0.0, 1.0);
  return (100 * (0.75 * acc + 0.15 * speed + 0.10 * hint)).round();
}

/// XP from a score; replays of a mission earn reduced XP (anti-farming).
int xpForScore(int score, {required bool firstCompletion}) {
  final base = (score / 5).round();
  return firstCompletion ? base : (base / 4).floor();
}
