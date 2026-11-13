import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/game/rules/adaptive.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/features/catalog/game_settings_screen.dart';

void main() {
  test('levels continue beyond 20, persist, never fall, and duplicate completions do not raise them', () async {
    SharedPreferences.setMockInitialValues({'level_logic': 20, 'xp_logic': 80});
    final store = await ProgressStore.open();
    for (var i = 0; i < 100; i++) {
      await store.commitRound(
        roundId: 'level-$i',
        score: 10,
        xp: 0,
        skill: SkillState(tier: 10),
        skillKey: 'logic',
        levelUp: true,
      );
    }
    expect(store.levelFor('logic'), 120);
    expect(store.pointsFor('logic'), 1000);
    expect(store.xpFor('logic'), 80);
    await store.commitRound(
      roundId: 'miss',
      score: 0,
      xp: 0,
      skill: SkillState(tier: 1),
      skillKey: 'logic',
    );
    expect(store.levelFor('logic'), 120);
    expect(
      await store.commitRound(
        roundId: 'level-0',
        score: 10,
        xp: 0,
        skill: SkillState(),
        skillKey: 'logic',
        levelUp: true,
      ),
      isFalse,
    );
    expect((await ProgressStore.open()).levelFor('logic'), 120);
    expect(store.levelFor('visual_memory'), 1);
  });

  testWidgets(
    'a legacy difficulty opens four choices and preserves a high player level',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'level_number_reasoning': 43,
        'practice_number_reasoning': 10,
      });
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: RoundShell(kind: GameKind.numberForge, store: store),
        ),
      );
      expect(find.byTooltip('Level 43 · Hard'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      await t.tap(find.byKey(const Key('game-settings')));
      await t.pumpAndSettle();
      expect(find.byType(GameSettingsScreen), findsOneWidget);
      final field = t.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('game-difficulty')),
      );
      expect(field.initialValue, 8);
      await t.tap(find.byKey(const Key('game-difficulty')));
      await t.pumpAndSettle();
      for (final label in ['Auto', 'Easy', 'Normal', 'Hard']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.textContaining('Practice · level'), findsNothing);
      await t.tap(find.text('Normal').last);
      await t.pumpAndSettle();
      final save = find.byKey(const Key('save-game-settings'));
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byTooltip('Level 43 · Normal'), findsOneWidget);
      expect(store.practiceTierFor('number_reasoning'), 5);
      expect(store.levelFor('number_reasoning'), 43);
      expect(t.takeException(), isNull);
    },
  );
}
