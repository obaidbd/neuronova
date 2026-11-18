import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/game/rules/difficulty.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/games/number_forge_game.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/game/rules/number_forge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final kind in GameKind.values.where((k) => k != GameKind.echoGrid)) {
    testWidgets('${kind.title} renders at every tier without errors', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (var tier = 1; tier <= 10; tier++) {
        await t.pumpWidget(
          MaterialApp(
            home: RoundShell(kind: kind, store: store, tierOverride: tier),
          ),
        );
        await t.pump(const Duration(milliseconds: 50));
        expect(
          find.byTooltip('Level 1 · ${difficultyName(tier)}'),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox()); // dispose timers
      }
    });
  }

  testWidgets('Number Forge: a tap completes one round using points only', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: RoundShell(kind: GameKind.numberForge, store: store),
      ),
    );
    await t.tap(find.byKey(const Key('option-0')));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    // Feedback is a small pill above the puzzle; no separate result page.
    expect(find.byKey(const Key('round-feedback')), findsOneWidget);
    expect(find.text('Next round'), findsNothing);
    expect(store.completedRounds, 1);
    expect(store.xp, 0);
    expect(find.textContaining('XP'), findsNothing);
    // test-mode override must not change the real skill tier
    expect(store.skillFor('number_reasoning').recent.length, 1);
    // The next round starts by itself after the short feedback pause.
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('round-feedback')), findsNothing);
    expect(find.text('R2'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // dispose timers
  });

  testWidgets(
    'Number Forge: streak, right/wrong card marks and header gain pop',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: RoundShell(kind: GameKind.numberForge, store: store),
        ),
      );
      NumberForgePuzzle puzzle() {
        final g = t.widget<NumberForgeGame>(find.byType(NumberForgeGame));
        return NumberForgePuzzle.generate(tier: g.tier, seed: g.seed);
      }

      Future<void> answer({required bool right}) async {
        final p = puzzle();
        final good = p.options.indexWhere(p.fits);
        final pick = right ? good : (good + 1) % p.options.length;
        await t.tap(find.byKey(Key('option-$pick')));
        await t.pump(const Duration(milliseconds: 50));
      }

      await answer(right: true);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.byKey(const Key('streak-count')), findsNothing);
      await t.pump(const Duration(seconds: 2));
      await answer(right: true);
      expect(find.byKey(const Key('streak-count')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.byKey(const Key('header-gain')), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await answer(right: false);
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.byKey(const Key('streak-count')), findsNothing);
      expect(find.textContaining('The answer was'), findsOneWidget);
      // the chosen wrong card and the right card are both marked
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2)); // card + pill
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox()); // dispose timers
    },
  );
}
