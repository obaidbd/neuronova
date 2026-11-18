import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/games/flip_match_game.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/game/rules/flip_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every tier deals each symbol exactly twice, repeatably', () {
    for (var tier = 1; tier <= 10; tier++) {
      final a = FlipPuzzle.generate(tier: tier, seed: 42);
      final b = FlipPuzzle.generate(tier: tier, seed: 42);
      expect(a.cards, b.cards);
      expect(a.cards.length, a.pairs * 2);
      expect(a.cards.length % a.cols, 0, reason: 'tier $tier fills its grid');
      final counts = <int, int>{};
      for (final c in a.cards) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts.values.every((n) => n == 2), isTrue);
      expect(counts.length, a.pairs);
    }
    expect(FlipPuzzle.pairsForTier(1), 3);
    expect(FlipPuzzle.pairsForTier(10), 12);
    expect(flipSymbols.length, greaterThanOrEqualTo(12));
  });

  test('matching and scoring rules', () {
    final p = FlipPuzzle.generate(tier: 2, seed: 7);
    final i = 0, j = p.partnerOf(0);
    expect(p.isMatch(i, j), isTrue);
    expect(p.isMatch(i, i), isFalse);
    final other = List.generate(
      p.cards.length,
      (k) => k,
    ).firstWhere((k) => p.cards[k] != p.cards[i]);
    expect(p.isMatch(i, other), isFalse);
    expect(p.evaluate(mistakes: 0).accuracy, 1);
    expect(p.evaluate(mistakes: 0).perfect, isTrue);
    expect(p.evaluate(mistakes: 1).perfect, isTrue); // 4/5
    expect(p.evaluate(mistakes: 8).perfect, isFalse); // 4/12
    expect(p.evaluate(mistakes: 8).accuracy, greaterThan(0));
  });

  testWidgets('Flip Match: a miss flips back, matches stay, round completes', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: RoundShell(
          kind: GameKind.flipMatch,
          store: store,
          tierOverride: 1,
        ),
      ),
    );
    final g = t.widget<FlipMatchGame>(find.byType(FlipMatchGame));
    final p = FlipPuzzle.generate(tier: g.tier, seed: g.seed);
    expect(find.byKey(const Key('pairs-found')), findsOneWidget);
    expect(find.text('0 / 3 found'), findsOneWidget);

    // one deliberate miss
    final other = List.generate(
      p.cards.length,
      (k) => k,
    ).firstWhere((k) => p.cards[k] != p.cards[0]);
    await t.tap(find.byKey(const Key('card-0')));
    await t.pump();
    await t.tap(find.byKey(Key('card-$other')));
    await t.pump();
    // while the miss is showing, taps are ignored
    // a face-down tile whose picture differs from both open tiles
    final third = List.generate(p.cards.length, (k) => k).firstWhere(
      (k) => p.cards[k] != p.cards[0] && p.cards[k] != p.cards[other],
    );
    await t.tap(find.byKey(Key('card-$third')));
    await t.pump();
    expect(find.text(flipSymbols[p.cards[third]].emoji), findsNothing);
    await t.pump(
      const Duration(milliseconds: 900),
    ); // timer fires, tiles flip back
    await t.pump(const Duration(milliseconds: 500)); // the 3D turn finishes
    expect(find.text(flipSymbols[p.cards[0]].emoji), findsNothing);

    // then solve every pair
    for (var i = 0; i < p.cards.length; i++) {
      if (p.partnerOf(i) < i) continue;
      await t.tap(find.byKey(Key('card-$i')));
      await t.pump();
      await t.tap(find.byKey(Key('card-${p.partnerOf(i)}')));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('3 / 3 found'), findsOneWidget);
    expect(find.byKey(const Key('round-feedback')), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget); // 3/4 = 75% accuracy
    expect(store.pointsFor('pair_memory'), greaterThan(0));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); // dispose timers
  });
}
