import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/app/theme.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/echo_grid_screen.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:neuronova_player/features/gameplay/echo_setup_screen.dart';
import 'package:neuronova_player/features/gameplay/match_board.dart';
import 'package:neuronova_player/features/gameplay/games/pattern_portal_game.dart';
import 'package:neuronova_player/features/gameplay/games/number_forge_game.dart';
import 'package:neuronova_player/features/gameplay/games/word_quest_game.dart';
import 'package:neuronova_player/features/gameplay/games/flip_match_game.dart';
import 'package:neuronova_player/features/gameplay/games/focus_dash_game.dart';
import 'package:neuronova_player/game/rules/flip_match.dart';
import 'package:neuronova_player/features/gameplay/games/path_recall_game.dart';
import 'package:neuronova_player/game/rules/echo_match.dart';
import 'package:neuronova_player/game/rules/echo_grid.dart';
import 'package:neuronova_player/game/rules/pattern_portal.dart';
import 'package:neuronova_player/game/rules/number_forge.dart';
import 'package:neuronova_player/game/rules/word_quest.dart';
import 'package:neuronova_player/game/rules/focus_dash.dart';
import 'package:neuronova_player/game/rules/path_recall.dart';

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> solve(WidgetTester t, GameKind kind, int turn, int level) async {
  switch (kind) {
    case GameKind.echoGrid:
      await tap(t, find.text('Start'));
      final p = EchoGridPuzzle.generate(tier: level, seed: 80 + turn);
      for (final tile in p.targets) {
        await tap(t, find.byKey(Key('tile-$tile')));
      }
      await tap(t, find.textContaining('Submit ('));
    case GameKind.patternPortal:
      final w = t.widget<PatternPortalGame>(find.byType(PatternPortalGame));
      final p = PatternPuzzle.generate(tier: w.tier, seed: w.seed);
      await tap(t, find.byKey(Key('option-${p.answerIndex}')));
    case GameKind.numberForge:
      final w = t.widget<NumberForgeGame>(find.byType(NumberForgeGame));
      final p = NumberForgePuzzle.generate(tier: w.tier, seed: w.seed);
      await tap(t, find.byKey(Key('option-${p.options.indexWhere(p.fits)}')));
    case GameKind.wordQuest:
      final w = t.widget<WordQuestGame>(find.byType(WordQuestGame));
      final p = WordPuzzle.generate(tier: w.tier, seed: w.seed);
      await tap(
        t,
        find.byKey(
          Key('option-${p.options.indexWhere((o) => o.id == p.item.id)}'),
        ),
      );
    case GameKind.focusDash:
      final w = t.widget<FocusDashGame>(find.byType(FocusDashGame));
      final p = FocusPuzzle.generate(tier: w.tier, seed: w.seed);
      for (final item in p.targets) {
        await tap(t, find.byKey(Key('item-$item')));
      }
      await tap(t, find.textContaining('Submit ('));
    case GameKind.flipMatch:
      final w = t.widget<FlipMatchGame>(find.byType(FlipMatchGame));
      final p = FlipPuzzle.generate(tier: w.tier, seed: w.seed);
      for (var i = 0; i < p.cards.length; i++) {
        if (p.partnerOf(i) < i) continue; // tap each pair once
        await tap(t, find.byKey(Key('card-$i')));
        await tap(t, find.byKey(Key('card-${p.partnerOf(i)}')));
      }
    case GameKind.pathRecall:
      final w = t.widget<PathRecallGame>(find.byType(PathRecallGame));
      final p = PathPuzzle.generate(tier: w.tier, seed: w.seed);
      await tap(t, find.text('Start'));
      for (final cell in p.expected.skip(1)) {
        await tap(t, find.byKey(Key('cell-$cell')));
      }
      await tap(t, find.textContaining('Submit ('));
  }
}

void main() {
  for (final kind in GameKind.values) {
    testWidgets('${kind.title}: settings opens its own match setup', (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      await store.setEchoPreviewSeconds(0, 0);
      await store.setPreviewSecondsFor('spatial_memory', 0);
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: kind == GameKind.echoGrid
              ? EchoGridScreen(store: store)
              : RoundShell(kind: kind, store: store),
        ),
      );
      await tap(t, find.byTooltip('Settings'));
      await tap(t, find.byKey(const Key('match-settings')));
      expect(
        t.widget<EchoSetupScreen>(find.byType(EchoSetupScreen)).kind,
        kind,
      );
      expect(t.takeException(), isNull);
    });
    testWidgets(
      '${kind.title}: computer turn uses the same handoff and completes once',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final store = await ProgressStore.open();
        final match = EchoMatch(
          roundLimit: 1,
          players: [
            EchoPlayer('Computer', computer: true, previewSeconds: 1),
            EchoPlayer('Human'),
          ],
        );
        await t.pumpWidget(
          MaterialApp(
            theme: novaTheme(),
            home: kind == GameKind.echoGrid
                ? EchoGridScreen(store: store, match: match)
                : RoundShell(kind: kind, store: store, match: match),
          ),
        );
        await t.pumpAndSettle();
        await tap(t, find.text('Start'));
        if (kind == GameKind.echoGrid || kind == GameKind.pathRecall) {
          await t.pump(const Duration(seconds: 1));
        }
        await t.pump(const Duration(milliseconds: 1400));
        await t.pumpAndSettle();
        expect(match.turn, 1);
        expect(match.players[0].rounds, 1);
        expect(match.players[1].rounds, 0);
        expect(find.text('Next player'), findsNothing);
        // A result must not hand off behind the settings route.
        await tap(t, find.byTooltip('Settings'));
        await t.pump(const Duration(seconds: 3));
        await tap(t, find.byTooltip('Back'));
        expect(find.text('Next player…'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 1300));
        await t.pumpAndSettle();
        expect(find.text('Human’s turn'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '${kind.title}: manual Next and saved automatic setting both work',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final store = await ProgressStore.open();
        await store.setAutoHandoffFor(kind.skillKey, false);
        expect(
          (await ProgressStore.open()).autoHandoffFor(kind.skillKey),
          isFalse,
        );
        for (final other in GameKind.values.where((k) => k != kind)) {
          expect(store.autoHandoffFor(other.skillKey), isTrue);
        }
        final match = EchoMatch(
          roundLimit: 1,
          players: [
            EchoPlayer('Computer', computer: true, previewSeconds: 1),
            EchoPlayer('Human', previewSeconds: 0),
          ],
        );
        await t.pumpWidget(
          MaterialApp(
            theme: novaTheme(),
            home: kind == GameKind.echoGrid
                ? EchoGridScreen(store: store, match: match, seed: 80)
                : RoundShell(kind: kind, store: store, match: match),
          ),
        );
        await t.pumpAndSettle();
        await tap(t, find.text('Start'));
        if (kind == GameKind.echoGrid || kind == GameKind.pathRecall) {
          await t.pump(const Duration(seconds: 1));
        }
        await t.pump(const Duration(milliseconds: 1400));
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 5));
        expect(find.text('Human’s turn'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('player-seat-0')),
            matching: find.text('Next player'),
          ),
          findsOneWidget,
        );
        await tap(t, find.text('Next player'));
        expect(find.text('Human’s turn'), findsOneWidget);
        await tap(t, find.byTooltip('Settings'));
        expect(find.text('Tap Next player'), findsOneWidget);
        await tap(t, find.byKey(const Key('game-turn-change')));
        await tap(t, find.text('Automatic').last);
        await tap(t, find.byKey(const Key('save-game-settings')));
        expect(
          (await ProgressStore.open()).autoHandoffFor(kind.skillKey),
          isTrue,
        );
        await tap(t, find.text('Start'));
        await solve(t, kind, 1, 1);
        expect(match.finished, isTrue);
        expect(find.text('View results'), findsNothing);
        await t.pump(const Duration(milliseconds: 1300));
        await t.pumpAndSettle();
        expect(find.byType(MatchResults), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    for (final count in [2, 3, 4]) {
      testWidgets(
        '${kind.title}: $count seats, Start at handoff, controls by name and independent points',
        (t) async {
          SharedPreferences.setMockInitialValues({});
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final store = await ProgressStore.open();
          final match = EchoMatch(
            roundLimit: count == 2 ? 2 : 1,
            players: List.generate(
              count,
              (i) => EchoPlayer('P${i + 1}', previewSeconds: 0),
            ),
          );
          await t.pumpWidget(
            MaterialApp(
              theme: novaTheme(),
              home: kind == GameKind.echoGrid
                  ? EchoGridScreen(store: store, match: match, seed: 80)
                  : RoundShell(kind: kind, store: store, match: match),
            ),
          );
          await t.pumpAndSettle();
          final bottom = t.getRect(find.byKey(const Key('player-seat-0')));
          final top = t.getRect(find.byKey(const Key('player-seat-1')));
          expect(bottom.top, greaterThan(top.bottom));
          if (count == 2) {
            expect(bottom.center.dx, closeTo(top.center.dx, 1));
          } else {
            final right = t.getRect(find.byKey(const Key('player-seat-2')));
            expect(right.left, greaterThan(top.right));
            if (count == 4) {
              expect(
                t.getRect(find.byKey(const Key('player-seat-3'))).left,
                greaterThan(bottom.right),
              );
            }
          }
          for (var turn = 0; turn < count * match.roundLimit!; turn++) {
            final index = turn % count;
            final level = match.players[index].level;
            await t.pump(const Duration(seconds: 5));
            expect(find.text('P${index + 1}’s turn'), findsOneWidget);
            expect(find.text('I’m ready'), findsNothing);
            expect(
              find.descendant(
                of: find.byKey(Key('player-seat-$index')),
                matching: find.text('Start'),
              ),
              findsOneWidget,
            );
            await tap(t, find.byKey(Key('seat-action-$index')));
            await solve(t, kind, turn, level);
            expect(match.players[index].points, ((turn ~/ count) + 1) * 10);
            expect(match.players[index].level, level + 1);
            expect(find.text('Next player'), findsNothing);
            expect(find.text('View results'), findsNothing);
            await t.pump(const Duration(milliseconds: 1300));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
          expect(find.textContaining('tie!'), findsOneWidget);
          expect(store.roundsFor(kind.skillKey), 0);
          expect(store.pointsFor(kind.skillKey), 0);
          expect(store.levelFor(kind.skillKey), 1);
        },
      );
    }
  }
}
