import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/app/theme.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/home/home_screen.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/features/gameplay/round_journey.dart';

void main() {
  test(
    'daily suggestion rotates through six games without changing within a day',
    () {
      final days = List.generate(
        6,
        (i) => dailyGame(DateTime(2026, 11, 16 + i)),
      );
      expect(days.toSet().length, 6);
      expect(
        dailyGame(DateTime(2026, 11, 16, 1)),
        dailyGame(DateTime(2026, 11, 16, 23)),
      );
    },
  );

  test('checkpoint goals keep advancing at high levels', () {
    for (final level in [1, 4, 5, 9, 10, 1000, 10001]) {
      expect(nextCheckpoint(level), greaterThan(level));
      expect(nextCheckpoint(level) - level, lessThanOrEqualTo(5));
    }
    for (final kind in GameKind.values) {
      expect(List.generate(3, (i) => roundTip(kind, i)).toSet().length, 3);
    }
  });

  testWidgets(
    'Continue remembers the selected game without changing its points',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'points_number_reasoning': 424,
        'level_number_reasoning': 10,
      });
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: HomeScreen(store: store),
        ),
      );
      await t.tap(find.byKey(const Key('game-numberForge')));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      final saved = await ProgressStore.open();
      expect(saved.lastPlayedGame, 'numberForge');
      expect(saved.pointsFor('number_reasoning'), 424);
      expect(saved.levelFor('number_reasoning'), 10);
      final button = find.byKey(const Key('home-continue'));
      expect(t.getRect(button).bottom, greaterThan(580));
      await t.tap(button);
      await t.pumpAndSettle();
      expect(
        t.widget<RoundShell>(find.byType(RoundShell)).kind,
        GameKind.numberForge,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'checkpoint feedback renders with reduced motion and large text',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(1.6),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: RoundJourney(
                    kind: GameKind.echoGrid,
                    level: 1000,
                    round: 999,
                    perfect: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Checkpoint reached · Lv1000'), findsOneWidget);
      expect(find.text('Next checkpoint · Lv1005'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
