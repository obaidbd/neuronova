import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/app/theme.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/echo_grid_screen.dart';
import 'package:neuronova_player/features/gameplay/echo_setup_screen.dart';
import 'package:neuronova_player/game/rules/echo_match.dart';
import 'package:neuronova_player/game/rules/echo_grid.dart';

Future<ProgressStore> boot(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return ProgressStore.open();
}

void main() {
  testWidgets('solo is endless; groups choose fixed rounds and 2–4 seats', (
    t,
  ) async {
    final store = await boot(t);
    await t.pumpWidget(
      MaterialApp(
        theme: novaTheme(),
        home: EchoSetupScreen(store: store),
      ),
    );
    expect(find.text('Continuous play · No round limit'), findsOneWidget);
    expect(find.byKey(const Key('match-rounds')), findsNothing);
    await t.tap(find.text('Friends'));
    await t.pumpAndSettle();
    expect(find.text('Continuous play · No round limit'), findsNothing);
    for (final n in [2, 3, 4]) {
      await t.tap(find.text('$n players'));
      await t.pumpAndSettle();
      expect(
        find.text('10 rounds per player · ${10 * n} turns total'),
        findsOneWidget,
      );
    }
    await t.tap(find.text('Computer'));
    await t.pumpAndSettle();
    expect(find.text('10 rounds per player · 20 turns total'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'four-player match hides handoff, honors times, scores and finishes',
    (t) async {
      final store = await boot(t);
      final match = EchoMatch(
        roundLimit: 1,
        players: List.generate(
          4,
          (i) => EchoPlayer('P${i + 1}', previewSeconds: i + 1),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: novaTheme(),
          home: EchoGridScreen(store: store, match: match, seed: 80),
        ),
      );
      await t.pumpAndSettle();
      for (var seat = 0; seat < 4; seat++) {
        expect(find.text('P${seat + 1}’s turn'), findsOneWidget);
        expect(find.byKey(const Key('tile-0')), findsNothing);
        expect(find.text('I’m ready'), findsNothing);
        await t.tap(find.text('Start'));
        await t.pump();
        await t.pump();
        await t.pump(Duration(seconds: seat + 1, milliseconds: -100));
        expect(find.text('Remember the glowing tiles'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('Tap the tiles that glowed'), findsOneWidget);
        final puzzle = EchoGridPuzzle.generate(tier: 1, seed: 80 + seat);
        for (final tile in puzzle.targets) {
          await t.tap(find.byKey(Key('tile-$tile')));
          await t.pumpAndSettle();
        }
        await t.tap(find.text('Submit (3/3)'));
        await t.pumpAndSettle();
        expect(match.players[seat].points, 10);
        expect(match.players[seat].level, 2);
        final next = find.text(seat == 3 ? 'View results' : 'Next player');
        await t.ensureVisible(next);
        await t.tap(next);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      expect(find.text('P1 & P2 & P3 & P4 tie!'), findsOneWidget);
      expect(store.completedRounds, 0);
      expect(store.xp, 0);
    },
  );

  testWidgets('computer takes its own turn and solo preferences persist', (
    t,
  ) async {
    final store = await boot(t);
    await store.setEchoPreviewSeconds(0, 7);
    expect((await ProgressStore.open()).echoPreviewSeconds(0), 7);
    final match = EchoMatch(
      roundLimit: 1,
      players: [EchoPlayer('Computer', computer: true, previewSeconds: 1)],
    );
    await t.pumpWidget(
      MaterialApp(
        theme: novaTheme(),
        home: EchoGridScreen(store: store, match: match, seed: 2),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Computer is recalling…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1400));
    await t.pumpAndSettle();
    expect(match.finished, isTrue);
    expect(match.players.single.rounds, 1);
    expect(find.text('View results'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
