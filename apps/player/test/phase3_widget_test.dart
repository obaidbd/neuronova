import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/features/gameplay/round_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final kind in GameKind.values.where((k) => k != GameKind.echoGrid)) {
    testWidgets('${kind.title} renders at every tier without errors', (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.open();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (var tier = 1; tier <= 10; tier++) {
        await t.pumpWidget(MaterialApp(
            home: RoundShell(kind: kind, store: store, tierOverride: tier)));
        await t.pump(const Duration(milliseconds: 50));
        expect(find.text('Tier $tier (test)'), findsOneWidget);
        await t.pumpWidget(const SizedBox()); // dispose timers
      }
    });
  }

  testWidgets('Number Forge: a tap finishes the round and commits XP once', (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: RoundShell(kind: GameKind.numberForge, store: store)));
    await t.tap(find.byKey(const Key('option-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('result-score')), findsOneWidget);
    expect(store.completedRounds, 1);
    // test-mode override must not change the real skill tier
    expect(store.skillFor('number_reasoning').recent.length, 1);
  });
}
