import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/echo_grid_screen.dart';
import 'package:neuronova_player/features/gameplay/games/path_recall_game.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/game/rules/echo_grid.dart';
import 'package:neuronova_player/game/rules/echo_match.dart';
import 'package:neuronova_player/game/rules/path_recall.dart';

void main() {
  testWidgets(
    'zero preview waits for Start, then Echo solo keeps its score and continues',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      await store.setEchoPreviewSeconds(0, 0);
      expect((await ProgressStore.open()).echoPreviewSeconds(0), 0);
      t.view.physicalSize = const Size(390, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final match = EchoMatch(
        players: [EchoPlayer('Solo', previewSeconds: 0)],
        roundLimit: 1,
      );
      await t.pumpWidget(
        MaterialApp(
          home: EchoGridScreen(store: store, match: match, seed: 7),
        ),
      );
      await t.pump(const Duration(minutes: 3));
      expect(find.text('Remember the glowing tiles'), findsOneWidget);
      expect(find.byKey(const Key('preview-start')), findsOneWidget);
      expect(find.textContaining('Submit ('), findsNothing);
      await t.tap(find.byKey(const Key('preview-start')));
      await t.pump();
      for (final cell in EchoGridPuzzle.generate(tier: 1, seed: 7).targets) {
        await t.tap(find.byKey(Key('tile-$cell')));
        await t.pump();
      }
      await t.tap(find.text('Submit (3/3)'));
      await t.pumpAndSettle();
      expect(store.pointsFor('visual_memory'), 10);
      expect(find.text('Finish run'), findsNothing);
      expect(find.text('View results'), findsNothing);
      await t.tap(find.text('Next round'));
      await t.pumpAndSettle();
      expect(find.text('Round 2 · Continuous'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('game-total-score'))).data,
        '10',
      );
      expect(find.byKey(const Key('preview-start')), findsOneWidget);
      expect(find.byKey(const Key('header-game-icon')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Path Recall keeps manual preview, shows Submit on small screens and scores only after submit',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      await store.setPreviewSecondsFor('spatial_memory', 0);
      expect(
        (await ProgressStore.open()).previewSecondsFor('spatial_memory'),
        0,
      );
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: RoundShell(
            kind: GameKind.pathRecall,
            store: store,
            tierOverride: 4,
          ),
        ),
      );
      await t.pump(const Duration(minutes: 3));
      expect(find.byKey(const Key('preview-start')), findsOneWidget);
      final game = t.widget<PathRecallGame>(find.byType(PathRecallGame));
      final puzzle = PathPuzzle.generate(tier: game.tier, seed: game.seed);
      await t.tap(find.byKey(const Key('preview-start')));
      await t.pump();
      final submit = find.byKey(const Key('submit'));
      expect(submit, findsOneWidget);
      expect(t.getRect(submit).bottom <= 640, isTrue);
      for (final cell in puzzle.expected.skip(1)) {
        await t.tap(find.byKey(Key('cell-$cell')));
        await t.pump();
      }
      expect(store.roundsFor('spatial_memory'), 0);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(store.roundsFor('spatial_memory'), 1);
      expect(store.pointsFor('spatial_memory'), 10);
      expect(store.pointsFor('visual_memory'), 0);
      expect(find.byKey(const Key('result-score')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'positive Path Recall preview automatically starts recall at its selected time',
    (t) async {
      var started = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 700,
              child: PathRecallGame(
                tier: 1,
                seed: 4,
                previewSeconds: 2,
                onRecallStarted: () => started++,
                onFinished: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 1999));
      expect(started, 0);
      expect(find.byKey(const Key('preview-start')), findsNothing);
      await t.pump(const Duration(milliseconds: 1));
      expect(started, 1);
      expect(find.byKey(const Key('submit')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
