import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/core/sfx.dart';
import 'package:neuronova_player/features/maps/map_painters.dart';
import 'package:neuronova_player/features/maps/map_puzzle_screen.dart';
import 'package:neuronova_player/game/content/bd_map.dart';
import 'package:neuronova_player/game/rules/map_puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BdMap map;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    map = await BdMap.load();
  });

  group('bundled Bangladesh data', () {
    test('has 8 divisions, 64 districts and every upazila', () {
      expect(map.divisions.length, 8);
      expect(map.districts.length, 64);
      expect(map.upazilas.length, greaterThanOrEqualTo(490));
      final divIds = {for (final d in map.divisions) d.id};
      final distIds = {for (final z in map.districts) z.id};
      expect(map.districts.every((z) => divIds.contains(z.parent)), isTrue);
      expect(map.upazilas.every((u) => distIds.contains(u.parent)), isTrue);
      // every division has districts, every district has upazilas
      for (final d in map.divisions) {
        expect(map.districts.where((z) => z.parent == d.id), isNotEmpty);
      }
      for (final z in map.districts) {
        expect(map.upazilas.where((u) => u.parent == z.id), isNotEmpty);
      }
    });

    test('every unit has a shape, a Bengali name and sits in Bangladesh', () {
      for (final u in [...map.divisions, ...map.districts, ...map.upazilas]) {
        expect(u.rings, isNotEmpty, reason: u.en);
        expect(u.rings.every((r) => r.length >= 3), isTrue, reason: u.en);
        expect(u.bn, isNotEmpty, reason: '${u.en} needs a Bengali name');
        expect(u.en, isNotEmpty);
        // longitude 88-93 E, latitude 20.5-26.7 N once un-projected
        final cos23 = cos(23.7 * pi / 180);
        expect(u.bounds.left / cos23, greaterThan(88.0), reason: u.en);
        expect(u.bounds.right / cos23, lessThan(93.0), reason: u.en);
        expect(-u.bounds.bottom, greaterThan(20.4), reason: u.en);
        expect(-u.bounds.top, lessThan(26.8), reason: u.en);
        expect(u.area, greaterThan(0));
      }
    });

    test('label points lie inside their own region', () {
      var inside = 0;
      final all = [...map.divisions, ...map.districts, ...map.upazilas];
      for (final u in all) {
        if (distanceToUnit(u.label, u) == 0) inside++;
      }
      expect(inside / all.length, greaterThan(.97));
    });

    test('districts in a division add up to the whole country', () {
      final names = {for (final d in map.divisions) d.en};
      expect(
        names,
        containsAll([
          'Dhaka',
          'Chattogram',
          'Khulna',
          'Rajshahi',
          'Rangpur',
          'Sylhet',
          'Barishal',
          'Mymensingh',
        ]),
      );
      final dhaka = map.divisions.firstWhere((d) => d.en == 'Dhaka');
      expect(map.districts.where((z) => z.parent == dhaka.id).length, 13);
    });

    test('selections: scopes, levels, piece counts, storage key', () {
      expect(map.piecesFor(MapSelection.country).length, 8);
      expect(
        map.piecesFor(const MapSelection(level: MapLevel.district)).length,
        64,
      );
      final dhaka = map.divisions.firstWhere((d) => d.en == 'Dhaka');
      final inDhaka = MapSelection(scopeId: dhaka.id, level: MapLevel.district);
      expect(map.piecesFor(inDhaka).length, 13);
      expect(map.levelsFor(null), MapLevel.values);
      expect(map.levelsFor(dhaka.id), [MapLevel.district, MapLevel.upazila]);
      final gazipur = map.districts.firstWhere((z) => z.en == 'Gazipur');
      expect(map.levelsFor(gazipur.id), [MapLevel.upazila]);
      expect(
        map
            .piecesFor(
              MapSelection(scopeId: gazipur.id, level: MapLevel.upazila),
            )
            .every((u) => u.parent == gazipur.id),
        isTrue,
      );
      expect(map.titleFor(inDhaka), 'Dhaka · Districts');
      for (final s in [MapSelection.country, inDhaka]) {
        expect(MapSelection.parse(s.key), s);
      }
      expect(MapSelection.parse('nonsense'), isNull);
      expect(MapSelection.parse(null), isNull);
    });
  });

  group('puzzle rules', () {
    MapPuzzle puzzle(MapSelection s, {MapHelp help = MapHelp.normal}) =>
        MapPuzzle(map: map, selection: s, help: help, seed: 5);

    test('the tray is shuffled but repeatable', () {
      final a = puzzle(const MapSelection(level: MapLevel.district));
      final b = puzzle(const MapSelection(level: MapLevel.district));
      expect(a.order, b.order);
      expect(a.order.toSet().length, 64);
      expect(
        a.order,
        isNot([for (final p in a.pieces) p.id]),
        reason: 'not in map order',
      );
    });

    test('dropping inside the right slot places the piece', () {
      final p = puzzle(MapSelection.country);
      final id = p.order.first;
      expect(p.tryPlace(id, p.unit(id).label), PlaceOutcome.placed);
      expect(p.placed, {id});
      expect(p.remaining.length, 7);
      expect(p.tryPlace(id, p.unit(id).label), PlaceOutcome.missed);
    });

    test('dropping in another region is a mistake; open sea is not', () {
      final p = puzzle(const MapSelection(level: MapLevel.district));
      final id = p.order.first;
      final other = p.pieces.firstWhere(
        (u) => u.id != id && distanceToUnit(u.label, p.unit(id)) > 1,
      );
      expect(p.tryPlace(id, other.label), PlaceOutcome.wrong);
      expect(p.mistakes, 1);
      expect(p.lastWrong, other);
      // far out in the Bay of Bengal
      final sea = BdMap.project(90.0, 17.0);
      expect(p.tryPlace(id, sea), PlaceOutcome.missed);
      expect(p.mistakes, 1);
      expect(p.placed, isEmpty);
    });

    test('near misses in open water: easy forgives, hard does not', () {
      // find a district with a free point 20% of its size to its west
      for (final u in map.districts) {
        var west = u.rings.first.first;
        for (final q in u.rings.first) {
          if (q.dx < west.dx) west = q;
        }
        final out = west + Offset(-u.bounds.longestSide * .2, 0);
        final probe = puzzle(const MapSelection(level: MapLevel.district));
        if (distanceToUnit(out, u) > 0 && probe.pieceAt(out) == null) {
          final easy = puzzle(
            const MapSelection(level: MapLevel.district),
            help: MapHelp.easy,
          );
          final hard = puzzle(
            const MapSelection(level: MapLevel.district),
            help: MapHelp.hard,
          );
          expect(easy.tryPlace(u.id, out), PlaceOutcome.placed);
          expect(hard.tryPlace(u.id, out), PlaceOutcome.missed);
          expect(hard.mistakes, 0);
          return;
        }
      }
      fail('no district with open water to its west');
    });

    test('a drop inside a neighbour is wrong even when it is close', () {
      final p = puzzle(
        const MapSelection(level: MapLevel.district),
        help: MapHelp.easy,
      );
      final a = p.pieces.first;
      final b = p.pieces.firstWhere(
        (u) =>
            u.id != a.id && distanceToUnit(u.label, a) < a.bounds.longestSide,
      );
      expect(p.tryPlace(a.id, b.label), PlaceOutcome.wrong);
      expect(p.mistakes, 1);
    });

    test('finishing: accuracy, success and hints', () {
      final p = puzzle(MapSelection.country);
      for (final id in [...p.order]) {
        p.tryPlace(id, p.unit(id).label);
      }
      expect(p.done, isTrue);
      expect(p.result().accuracy, 1);
      expect(p.result().success, isTrue);
      final q = puzzle(MapSelection.country);
      q.useHint(q.order.first);
      expect(q.hints, 1);
      q.mistakes = 20;
      expect(q.result().success, isFalse); // 8 of 28 attempts
      expect(q.result().accuracy, closeTo(8 / 28, 1e-9));
    });

    test('help levels follow the difficulty tier', () {
      expect(mapHelpForTier(1), MapHelp.easy);
      expect(mapHelpForTier(5), MapHelp.normal);
      expect(mapHelpForTier(9), MapHelp.hard);
      expect(MapHelp.easy.namesOnSlots, isTrue);
      expect(MapHelp.normal.namesOnSlots, isFalse);
      expect(MapHelp.normal.namesOnPieces, isTrue);
      expect(MapHelp.hard.namesOnPieces, isFalse);
      expect(MapHelp.hard.showSlots, isFalse);
    });
  });

  group('screen', () {
    late ProgressStore store;

    Future<void> open(
      WidgetTester t, {
      MapSelection selection = MapSelection.country,
      Size size = const Size(390, 844),
      Map<String, Object> prefs = const {},
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      store = await ProgressStore.open();
      await t.pumpWidget(
        MaterialApp(
          home: MapPuzzleScreen(
            store: store,
            map: map,
            selection: selection,
            seed: 3,
            sfx: SilentSfx(),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
    }

    String text(WidgetTester t, String key) =>
        t.widget<Text>(find.byKey(Key(key))).data!;

    /// Global position of a region's label point on the board.
    Offset spot(WidgetTester t, MapPuzzle pz, MapUnit u) {
      final top = t.getTopLeft(find.byKey(const Key('map-scene')));
      final size = t.getSize(find.byKey(const Key('map-scene')));
      return top + MapProjection(pz.bounds, size).toBoard(u.label);
    }

    MapPuzzle shadow(MapSelection s, {MapHelp help = MapHelp.easy}) =>
        MapPuzzle(map: map, selection: s, help: help, seed: 3);

    testWidgets('shows the header, tray, board and progress', (t) async {
      await open(t);
      expect(find.byKey(const Key('game-score-bar')), findsOneWidget);
      expect(find.byKey(const Key('game-settings')), findsOneWidget);
      expect(text(t, 'map-title'), 'Bangladesh · Divisions');
      expect(text(t, 'map-progress'), '0 / 8 placed');
      expect(find.byKey(const Key('map-tray')), findsOneWidget);
      expect(find.byKey(const Key('map-scene')), findsOneWidget);
      final pz = shadow(MapSelection.country);
      // the tray builds the pieces on screen; the first one is selected
      expect(find.byKey(Key('piece-${pz.order.first}')), findsOneWidget);
      expect(find.byType(Draggable<String>), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('select a piece, tap its place: it snaps in', (t) async {
      await open(t);
      final pz = shadow(MapSelection.country);
      final id = pz.order.first;
      // the first tray piece is already selected; tap its slot
      await t.tapAt(spot(t, pz, pz.unit(id)));
      await t.pump();
      expect(text(t, 'map-progress'), '1 / 8 placed');
      expect(find.byKey(Key('piece-$id')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a wrong place is a mistake and says so', (t) async {
      await open(t);
      final pz = shadow(MapSelection.country);
      final id = pz.order.first;
      final other = pz.pieces.firstWhere((u) => u.id != id);
      await t.tapAt(spot(t, pz, other));
      await t.pump();
      expect(text(t, 'map-progress'), '0 / 8 placed');
      expect(text(t, 'map-status'), startsWith('That is '));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });

    testWidgets('drag a piece from the tray onto the map', (t) async {
      await open(t);
      final pz = shadow(MapSelection.country);
      final id = pz.order[1]; // not the auto-selected one
      final from = t.getCenter(find.byKey(Key('piece-$id')));
      final g = await t.startGesture(from);
      await g.moveBy(const Offset(0, 40));
      await t.pump();
      await g.moveTo(spot(t, pz, pz.unit(id)));
      await t.pump();
      await g.up();
      await t.pump();
      expect(text(t, 'map-progress'), '1 / 8 placed');
      expect(find.byKey(Key('piece-$id')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('completing the map scores, levels up and offers more', (
      t,
    ) async {
      await open(t);
      final pz = shadow(MapSelection.country);
      // the next piece in the tray is selected automatically
      for (final id in pz.order) {
        await t.tapAt(spot(t, pz, pz.unit(id)));
        await t.pump();
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('map-done')), findsOneWidget);
      final key = GameKind.mapPuzzle.skillKey;
      expect(store.roundsFor(key), 1);
      expect(store.pointsFor(key), 10); // no mistakes or hints
      expect(store.levelFor(key), 2);
      expect(text(t, 'map-summary'), '8 pieces · 0 wrong tries · 0 hints');
      expect(find.byKey(const Key('map-again')), findsOneWidget);
      await t.tap(find.byKey(const Key('map-again')));
      await t.pump();
      expect(text(t, 'map-progress'), '0 / 8 placed');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a hint costs points but finds the place', (t) async {
      await open(t);
      final pz = shadow(MapSelection.country);
      await t.tap(find.byKey(const Key('map-hint')));
      await t.pump(const Duration(milliseconds: 300));
      expect(text(t, 'map-status'), startsWith('Hint used'));
      await t.pump(const Duration(seconds: 4));
      for (final id in pz.order) {
        // after the hint the map is zoomed on one region: reset the view
        await t.tap(find.byKey(const Key('map-zoom-fit')));
        await t.pump();
        await t.tapAt(spot(t, pz, pz.unit(id)));
        await t.pump();
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('map-done')), findsOneWidget);
      final key = GameKind.mapPuzzle.skillKey;
      expect(store.pointsFor(key), 8); // one hint: -25%
      expect(text(t, 'map-summary'), contains('1 hints'));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('zoom buttons change the scale and reset', (t) async {
      await open(t);
      double scale() => t
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      expect(scale(), 1);
      await t.tap(find.byKey(const Key('map-zoom-in')));
      await t.pump();
      expect(scale(), closeTo(1.6, .01));
      await t.tap(find.byKey(const Key('map-zoom-in')));
      await t.pump();
      expect(scale(), closeTo(2.56, .01));
      await t.tap(find.byKey(const Key('map-zoom-out')));
      await t.pump();
      expect(scale(), closeTo(1.6, .01));
      await t.tap(find.byKey(const Key('map-zoom-fit')));
      await t.pump();
      expect(scale(), 1);
    });

    testWidgets('choose a map: districts of Dhaka division', (t) async {
      await open(t);
      await t.tap(find.byKey(const Key('map-change')));
      await t.pumpAndSettle();
      expect(text(t, 'map-piece-count'), '8 pieces');
      await t.tap(find.byKey(const Key('level-district')));
      await t.pump();
      expect(text(t, 'map-piece-count'), '64 pieces');
      await t.tap(find.byKey(const Key('level-upazila')));
      await t.pump();
      expect(
        int.parse(text(t, 'map-piece-count').split(' ').first),
        greaterThanOrEqualTo(490),
      );
      expect(find.textContaining('big puzzle'), findsOneWidget);
      // narrow to one division: only finer levels stay selectable
      await t.tap(find.byKey(const Key('map-scope')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Dhaka Division').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('level-district')));
      await t.pump();
      expect(text(t, 'map-piece-count'), '13 pieces');
      final division = t.widget<ChoiceChip>(
        find.byKey(const Key('level-division')),
      );
      expect(division.onSelected, isNull); // not finer than the scope
      await t.tap(find.byKey(const Key('map-start')));
      await t.pumpAndSettle();
      expect(text(t, 'map-title'), 'Dhaka · Districts');
      expect(text(t, 'map-progress'), '0 / 13 placed');
      expect(store.mapSelection, contains('/district'));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('settings: difficulty changes the help; attribution shown', (
      t,
    ) async {
      await open(t);
      // a new player is on Easy: names on the pieces
      final pz = shadow(MapSelection.country);
      final firstName = pz.unit(pz.order.first).nameBn();
      expect(find.text(firstName), findsWidgets);
      await t.tap(find.byKey(const Key('game-settings')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('game-untimed')), findsNothing);
      expect(find.byKey(const Key('match-settings')), findsNothing);
      expect(find.byKey(const Key('map-attribution')), findsOneWidget);
      expect(find.textContaining('CC BY 3.0 IGO'), findsOneWidget);
      await t.tap(find.byKey(const Key('game-difficulty')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hard').last);
      await t.pumpAndSettle();
      final save = find.byKey(const Key('save-game-settings'));
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('map-title')), findsOneWidget);
      // hard: no names on the pieces
      expect(text(t, 'map-status'), 'Place the selected piece');
      expect(find.text(firstName), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    for (final size in const [Size(390, 844), Size(320, 568)]) {
      testWidgets('upazila puzzle fits on ${size.width.toInt()}x'
          '${size.height.toInt()} without errors', (t) async {
        await open(
          t,
          size: size,
          selection: const MapSelection(level: MapLevel.upazila),
        );
        expect(text(t, 'map-progress'), startsWith('0 / '));
        final board = t.getRect(find.byKey(const Key('map-board')));
        expect(board.bottom, lessThanOrEqualTo(size.height));
        expect(board.height, greaterThan(180));
        await t.tap(find.byKey(const Key('map-zoom-in')));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  });
}
