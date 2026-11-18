import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/game/content/vocab.dart';
import 'package:neuronova_player/game/rules/focus_dash.dart';
import 'package:neuronova_player/game/rules/number_forge.dart';
import 'package:neuronova_player/game/rules/path_recall.dart';
import 'package:neuronova_player/game/rules/pattern_portal.dart';
import 'package:neuronova_player/game/rules/word_quest.dart';

void main() {
  const seeds = 400;

  test('PatternPortal: exactly one valid answer, deterministic', () {
    for (var t = 1; t <= 10; t++) {
      for (var s = 0; s < seeds; s++) {
        final p = PatternPuzzle.generate(tier: t, seed: s);
        final q = PatternPuzzle.generate(tier: t, seed: s);
        expect(p.visible, q.visible);
        expect(p.options, q.options);
        expect(periodicContinuations(p.visible), {p.answer});
        expect(p.options.toSet().length, p.options.length);
        expect(p.options.where((o) => o == p.answer).length, 1);
        expect(p.isCorrect(p.answerIndex), isTrue);
      }
    }
  });

  test('NumberForge: exactly one option fits, math is exact', () {
    for (var t = 1; t <= 10; t++) {
      for (var s = 0; s < seeds; s++) {
        final p = NumberForgePuzzle.generate(tier: t, seed: s);
        expect(
          p.options.where(p.fits).length,
          1,
          reason: '${p.display} t$t s$s',
        );
        expect(p.options.toSet().length, p.options.length);
      }
    }
    expect(applyOp(7, '÷', 2), isNull);
    expect(applyOp(12, '÷', 4), 3);
  });

  test('FocusDash: targets consistent, evaluation correct', () {
    for (var t = 1; t <= 10; t++) {
      for (var s = 0; s < seeds; s++) {
        final p = FocusPuzzle.generate(tier: t, seed: s);
        expect(p.targets.isNotEmpty, isTrue);
        for (var i = 0; i < p.items.length; i++) {
          expect(p.targets.contains(i), p.isTarget(p.items[i]));
        }
        expect(p.evaluate(p.targets).perfect, isTrue);
        expect(p.evaluate({}).accuracy, 0);
      }
    }
    final p = FocusPuzzle.generate(tier: 3, seed: 1);
    expect(() => p.evaluate({999}), throwsArgumentError);
  });

  test('PathRecall: route is traversable, self-avoiding, deterministic', () {
    for (var t = 1; t <= 10; t++) {
      for (var s = 0; s < seeds; s++) {
        final p = PathPuzzle.generate(tier: t, seed: s);
        expect(p.path.toSet().length, p.path.length);
        for (var i = 1; i < p.path.length; i++) {
          expect(PathPuzzle.adjacent(p.size, p.path[i - 1], p.path[i]), isTrue);
        }
        expect(p.path, PathPuzzle.generate(tier: t, seed: s).path);
        expect(p.evaluate(p.expected.sublist(1)).perfect, isTrue);
      }
    }
    final p = PathPuzzle.generate(tier: 2, seed: 5);
    expect(p.isLegalMove([p.start], p.start), isFalse);
    expect(p.evaluate([]).perfect, isFalse);
    expect(() => p.evaluate([-1]), throwsArgumentError);
  });

  test('WordQuest: unique correct option, language gating', () {
    for (var t = 1; t <= 10; t++) {
      for (var s = 0; s < seeds; s++) {
        final p = WordPuzzle.generate(tier: t, seed: s);
        expect(p.options.map((o) => o.id).toSet().length, 4);
        expect(p.options.where((o) => o.id == p.item.id).length, 1);
        expect(WordPuzzle.languagesForTier(t).contains(p.lang), isTrue);
      }
    }
    expect(vocab.map((v) => v.id).toSet().length, vocab.length);
    expect(vocab.where((v) => v.difficulty == 1).length >= 4, isTrue);
  });
}
