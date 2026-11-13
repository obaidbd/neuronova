import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guest: Play Now starts tutorial without registration', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(NeuroNovaApp(store: store));
    expect(find.text('Play Now'), findsOneWidget);
    await t.tap(find.text('Play Now'));
    await t.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.byTooltip('First Gate'), findsOneWidget);
    expect(find.text('Watch the glowing tiles…'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.text('Now tap the tiles that glowed'), findsOneWidget);
    expect(find.textContaining('Submit (0/3)'), findsOneWidget);
  });

  test('same round cannot award XP twice', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.open();
    final skill = store.memorySkill;
    expect(
      await store.commitRound(roundId: 'r1', score: 90, xp: 18, skill: skill),
      isTrue,
    );
    expect(
      await store.commitRound(roundId: 'r1', score: 90, xp: 18, skill: skill),
      isFalse,
    );
    expect(store.xp, 18);
    expect(store.completedRounds, 1);
  });
}
