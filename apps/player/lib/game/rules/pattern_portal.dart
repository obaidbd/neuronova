import 'dart:math';

class PatternItem {
  const PatternItem(this.shape, this.color);
  final int shape; // 0..3
  final int color; // 0..3
  @override
  bool operator ==(Object other) =>
      other is PatternItem && other.shape == shape && other.color == color;
  @override
  int get hashCode => shape * 4 + color;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
int _lcm(int a, int b) => a * b ~/ _gcd(a, b);

/// Continuations of [v] under every periodic rule with period <= len/2
/// that fits the visible items. A puzzle is unambiguous iff this set has
/// exactly one element (the answer).
Set<PatternItem> periodicContinuations(List<PatternItem> v) {
  final out = <PatternItem>{};
  for (var p = 1; p <= v.length ~/ 2; p++) {
    var ok = true;
    for (var i = p; i < v.length; i++) {
      if (v[i] != v[i - p]) {
        ok = false;
        break;
      }
    }
    if (ok) out.add(v[v.length - p]);
  }
  return out;
}

class PatternPuzzle {
  PatternPuzzle(this.visible, this.answer, this.options, this.tier, this.seed);
  final List<PatternItem> visible;
  final PatternItem answer;
  final List<PatternItem> options;
  final int tier;
  final int seed;

  int get answerIndex => options.indexOf(answer);
  bool isCorrect(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= options.length) {
      throw ArgumentError('Illegal option');
    }
    return options[optionIndex] == answer;
  }

  static PatternPuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    final (ps, pc) = t <= 2
        ? (2, 1)
        : t == 3
        ? (3, 1)
        : t <= 6
        ? (3, 2)
        : t <= 8
        ? (4, 2)
        : (3, 2);
    final len = max(6, 2 * _lcm(ps, pc));
    for (var attempt = 0; attempt < 200; attempt++) {
      final rng = Random(seed * 1000 + attempt);
      final shapes = [0, 1, 2, 3]..shuffle(rng);
      final colors = [0, 1, 2, 3]..shuffle(rng);
      PatternItem at(int i) => PatternItem(shapes[i % ps], colors[i % pc]);
      final visible = [for (var i = 0; i < len; i++) at(i)];
      final answer = at(len);
      final cont = periodicContinuations(visible);
      if (cont.length != 1 || !cont.contains(answer)) continue;
      // Plausible distractors: change one or both properties.
      final cands = <PatternItem>{};
      for (var s = 0; s < 4; s++) {
        for (var c = 0; c < 4; c++) {
          final it = PatternItem(s, c);
          if (it != answer) cands.add(it);
        }
      }
      final list = cands.toList()..shuffle(rng);
      list.sort((a, b) {
        int sim(PatternItem x) =>
            (x.shape == answer.shape ? 1 : 0) +
            (x.color == answer.color ? 1 : 0);
        return sim(b).compareTo(sim(a));
      });
      final options = [answer, ...list.take(3)]..shuffle(rng);
      return PatternPuzzle(visible, answer, options, t, seed);
    }
    throw StateError('No unambiguous pattern for tier $t seed $seed');
  }
}
