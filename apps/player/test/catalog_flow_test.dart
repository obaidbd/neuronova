import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/app/theme.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/home/home_screen.dart';
import 'package:neuronova_player/features/catalog/game_details_screen.dart';

void main() {
  testWidgets(
    'every home card opens its own details without starting a round',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: HomeScreen(store: store),
        ),
      );
      for (final game in GameKind.values) {
        final card = find.byKey(Key('game-${game.name}'));
        await t.ensureVisible(card);
        await t.tap(card);
        await t.pumpAndSettle();
        expect(find.byType(GameDetailsScreen), findsOneWidget);
        expect(find.text('How to play'), findsOneWidget);
        expect(find.text(game.title), findsNWidgets(2));
        expect(store.completedRounds, 0);
        await t.pageBack();
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('game settings reach gameplay, persist, and stay independent', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: novaTheme(),
        home: GameDetailsScreen(kind: GameKind.numberForge, store: store),
      ),
    );
    final difficulty = find.byKey(const Key('game-difficulty'));
    await t.ensureVisible(difficulty);
    await t.tap(difficulty);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Practice · level 8').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('Practice · level 8').last);
    await t.pumpAndSettle();
    final relaxed = find.byKey(const Key('game-untimed'));
    await t.ensureVisible(relaxed);
    await t.tap(relaxed);
    await t.pumpAndSettle();
    final play = find.byKey(const Key('play-game'));
    await t.ensureVisible(play);
    await t.tap(play);
    await t.pumpAndSettle();
    expect(find.text('Tier 8 (test)'), findsOneWidget);
    final saved = await ProgressStore.open();
    expect(saved.practiceTierFor('number_reasoning'), 8);
    expect(saved.untimedFor('number_reasoning'), isTrue);
    expect(saved.practiceTierFor('visual_memory'), isNull);
    expect(saved.untimedFor('visual_memory'), isFalse);
    expect(saved.skillFor('number_reasoning').tier, 1);
    expect(t.takeException(), isNull);
  });
}
