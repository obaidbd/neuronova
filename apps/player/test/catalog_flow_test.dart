import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/app/theme.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/home/home_screen.dart';
import 'package:neuronova_player/features/catalog/game_settings_screen.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';

void main() {
  testWidgets('every home icon opens gameplay directly with in-game settings', (
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
        home: HomeScreen(store: store),
      ),
    );
    for (final game in GameKind.values) {
      await t.tap(find.byKey(Key('game-${game.name}')));
      await t.pumpAndSettle();
      expect(find.byType(GameSettingsScreen), findsNothing);
      expect(find.byKey(const Key('game-settings')), findsOneWidget);
      expect(find.byKey(const Key('game-score-bar')), findsOneWidget);
      expect(find.text(game.title), findsOneWidget);
      expect(store.completedRounds, 0);
      await t.tap(find.byKey(const Key('game-settings')));
      await t.pumpAndSettle();
      expect(find.byType(GameSettingsScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
    }
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'saving in-game settings resumes gameplay and keeps other games independent',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: RoundShell(kind: GameKind.numberForge, store: store),
        ),
      );
      await t.tap(find.byKey(const Key('game-settings')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('game-difficulty')));
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
      final save = find.byKey(const Key('save-game-settings'));
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byType(GameSettingsScreen), findsNothing);
      expect(find.text('Lv 8 · Practice'), findsOneWidget);
      final saved = await ProgressStore.open();
      expect(saved.practiceTierFor('number_reasoning'), 8);
      expect(saved.untimedFor('number_reasoning'), isTrue);
      expect(saved.practiceTierFor('visual_memory'), isNull);
      expect(saved.untimedFor('visual_memory'), isFalse);
      expect(saved.skillFor('number_reasoning').tier, 1);
      expect(t.takeException(), isNull);
    },
  );

  test(
    'game totals persist separately and duplicate rounds never add twice',
    () async {
      SharedPreferences.setMockInitialValues({
        'best_visual_memory': 100,
        'xp': 1068,
        'points_attention': 1200,
      });
      final store = await ProgressStore.open();
      final numbers = store.skillFor('number_reasoning');
      final memory = store.memorySkill;
      await store.commitRound(
        roundId: 'number-1',
        score: 9,
        xp: 2,
        skill: numbers,
        skillKey: 'number_reasoning',
      );
      await store.commitRound(
        roundId: 'number-2',
        score: 7,
        xp: 1,
        skill: numbers,
        skillKey: 'number_reasoning',
      );
      await store.commitRound(
        roundId: 'memory-1',
        score: 10,
        xp: 2,
        skill: memory,
      );
      expect(
        await store.commitRound(
          roundId: 'number-1',
          score: 9,
          xp: 2,
          skill: numbers,
          skillKey: 'number_reasoning',
        ),
        isFalse,
      );
      final saved = await ProgressStore.open();
      expect(saved.pointsFor('number_reasoning'), 16);
      expect(saved.xpFor('number_reasoning'), 3);
      expect(saved.roundsFor('number_reasoning'), 2);
      expect(saved.pointsFor('visual_memory'), 10);
      expect(saved.xpFor('visual_memory'), 2);
      expect(saved.bestFor('visual_memory'), 10);
      expect(saved.pointsFor('logic'), 0);
      expect(saved.pointsFor('attention'), 1200);
      expect(saved.bestFor('number_reasoning'), 9);
      expect(
        (await SharedPreferences.getInstance()).getInt('best_visual_memory'),
        100,
      );
      expect(saved.xp, 1073);
    },
  );
}
