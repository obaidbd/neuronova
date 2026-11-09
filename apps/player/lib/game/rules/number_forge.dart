import 'dart:math';

int? applyOp(int a, String op, int b) {
  switch (op) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '×':
      return a * b;
    case '÷':
      if (b == 0 || a % b != 0) return null;
      return a ~/ b;
  }
  throw ArgumentError('Unknown operator $op');
}

class NumberForgePuzzle {
  NumberForgePuzzle({
    required this.a,
    required this.b,
    required this.op,
    required this.result,
    required this.blank,
    required this.options,
    required this.tier,
    required this.seed,
  });

  final int a, b, result, tier, seed;
  final String op;

  /// 0 = first operand, 1 = operator, 2 = second operand.
  final int blank;
  final List<String> options;

  /// Deterministic check: does substituting [option] make the equation true?
  bool fits(String option) {
    final x = blank == 0 ? int.parse(option) : a;
    final y = blank == 2 ? int.parse(option) : b;
    final o = blank == 1 ? option : op;
    return applyOp(x, o, y) == result;
  }

  bool isCorrect(int i) {
    if (i < 0 || i >= options.length) throw ArgumentError('Illegal option');
    return fits(options[i]);
  }

  String get display {
    final sa = blank == 0 ? '?' : '$a';
    final so = blank == 1 ? '?' : op;
    final sb = blank == 2 ? '?' : '$b';
    return '$sa $so $sb = $result';
  }

  static NumberForgePuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    for (var attempt = 0; attempt < 500; attempt++) {
      final rng = Random(seed * 1000 + attempt);
      int r(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
      late int a, b;
      late String op;
      var blank = 2;
      if (t <= 3) {
        op = '+';
        a = r(1, 4 + t * 3);
        b = r(1, 4 + t * 3);
        blank = rng.nextBool() ? 2 : 0;
      } else if (t <= 6) {
        op = rng.nextBool() ? '+' : '-';
        a = r(5, 10 * (t - 2));
        b = r(1, a);
        blank = t >= 5 && rng.nextBool() ? 1 : (rng.nextBool() ? 2 : 0);
      } else if (t <= 8) {
        op = rng.nextBool() ? '×' : '÷';
        b = r(2, 9);
        a = op == '×' ? r(2, 9) : b * r(2, 9);
        blank = rng.nextBool() ? 2 : 0;
      } else {
        op = ['×', '÷', '+', '-'][rng.nextInt(4)];
        b = r(3, 15);
        a = op == '÷' ? b * r(3, 15) : r(6, 25);
        if (op == '-' && b > a) continue;
        blank = rng.nextInt(3);
      }
      final result = applyOp(a, op, b);
      if (result == null || result < 0) continue;

      List<String> options;
      if (blank == 1) {
        options = ['+', '-', '×', '÷'];
      } else {
        final answer = blank == 0 ? a : b;
        final set = <int>{answer};
        var guard = 0;
        while (set.length < 4 && guard++ < 50) {
          final d = answer + r(-4, 4);
          if (d >= 0) set.add(d);
        }
        if (set.length < 4) continue;
        options = set.map((e) => '$e').toList()..shuffle(rng);
      }
      final p = NumberForgePuzzle(
        a: a,
        b: b,
        op: op,
        result: result,
        blank: blank,
        options: options,
        tier: t,
        seed: seed,
      );
      if (options.where(p.fits).length != 1) continue; // exactly one answer
      return p;
    }
    throw StateError('No puzzle for tier $t seed $seed');
  }
}
