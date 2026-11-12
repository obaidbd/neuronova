import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/game/rules/adaptive.dart';
import 'package:neuronova_player/game/rules/echo_grid.dart';
import 'package:neuronova_player/game/rules/scoring.dart';

void main() {
  group('EchoGrid generation', () {
    test('valid and deterministic across many seeds/tiers', () {
      for (var tier = 1; tier <= 10; tier++) {
        for (var seed = 0; seed < 500; seed++) {
          final a = EchoGridPuzzle.generate(tier: tier, seed: seed);
          final b = EchoGridPuzzle.generate(tier: tier, seed: seed);
          expect(a.targets, b.targets);
          expect(a.targets.length, a.config.targets);
          expect(a.targets.every((c) => c >= 0 && c < a.config.cells), isTrue);
          expect(a.config.targets < a.config.cells, isTrue);
        }
      }
    });
    test('spec starting configs', () {
      final b = EchoGridConfig.forTier(2);
      expect([b.size, b.targets, b.previewMs], [3, 3, 4000]);
      final i = EchoGridConfig.forTier(5);
      expect([i.size, i.targets, i.previewMs], [4, 5, 3000]);
      final a = EchoGridConfig.forTier(8);
      expect([a.size, a.targets, a.previewMs], [5, 8, 2000]);
    });
    test('evaluate perfect, partial, and illegal', () {
      final p = EchoGridPuzzle.generate(tier: 2, seed: 7);
      expect(p.evaluate(p.targets).perfect, isTrue);
      final wrong = (List<int>.generate(
        9,
        (i) => i,
      )..removeWhere(p.targets.contains)).first;
      final partial = {...p.targets.take(2), wrong};
      final r = p.evaluate(partial);
      expect(r.perfect, isFalse);
      expect(r.hits, 2);
      expect(() => p.evaluate({99}), throwsArgumentError);
      expect(() => p.evaluate({0, 1, 2, 3}), throwsArgumentError);
    });
  });

  group('scoring', () {
    test('timed formula', () {
      expect(
        gameScore(
          accuracy: 1,
          timed: true,
          hints: 0,
          targetMs: 5000,
          actualMs: 5000,
        ),
        10,
      );
      expect(
        gameScore(
          accuracy: 1,
          timed: true,
          hints: 0,
          targetMs: 5000,
          actualMs: 10000,
        ),
        9,
      );
    });
    test('untimed formula ignores speed', () {
      expect(gameScore(accuracy: 1, timed: false, hints: 0), 10);
      expect(gameScore(accuracy: 0.5, timed: false, hints: 0), 5);
    });
    test('wrong answers never earn points, regardless of speed or mode', () {
      expect(
        gameScore(
          accuracy: 0,
          timed: true,
          hints: 0,
          targetMs: 5000,
          actualMs: 1,
        ),
        0,
      );
      expect(gameScore(accuracy: 0, timed: false, hints: 0), 0);
      expect(xpForScore(0, firstCompletion: true), 0);
    });
    test('accuracy and hints keep every award within 0–10', () {
      for (var i = 0; i <= 100; i++) {
        final accuracy = i / 100;
        final score = gameScore(
          accuracy: accuracy,
          timed: true,
          hints: 0,
          targetMs: 5000,
          actualMs: 1000,
        );
        expect(score, inInclusiveRange(0, 10));
        expect(score <= (10 * accuracy).round(), isTrue);
      }
      expect(gameScore(accuracy: 1, timed: false, hints: 4), 0);
      expect(
        gameScore(
          accuracy: 0.5,
          timed: true,
          hints: 0,
          targetMs: 5000,
          actualMs: 1000,
        ),
        5,
      );
    });
    test('replay XP is reduced', () {
      expect(xpForScore(10, firstCompletion: true), 2);
      expect(xpForScore(10, firstCompletion: false), 0);
    });
  });

  group('adaptive', () {
    test('increase after 5 strong rounds by exactly one tier', () {
      final s = SkillState();
      for (var i = 0; i < 5; i++) {
        s.record(const RoundRecord(accuracy: 1, success: true));
      }
      expect(s.tier, 2);
    });
    test('decrease after 3 consecutive failures, never below 1', () {
      final s = SkillState(tier: 3);
      for (var i = 0; i < 3; i++) {
        s.record(const RoundRecord(accuracy: 0.2, success: false));
      }
      expect(s.tier, 2);
      final low = SkillState();
      for (var i = 0; i < 6; i++) {
        low.record(const RoundRecord(accuracy: 0, success: false));
      }
      expect(low.tier, 1);
    });
    test('hint-dependent rounds block promotion; json round-trips', () {
      final s = SkillState();
      for (var i = 0; i < 5; i++) {
        s.record(const RoundRecord(accuracy: 1, success: true, usedHint: true));
      }
      expect(s.tier, 1);
      expect(SkillState.fromJson(s.toJson()).recent.length, 5);
    });
  });
}
