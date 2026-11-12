import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/game/rules/echo_match.dart';
import 'package:neuronova_player/game/rules/echo_grid.dart';

void main() {
  test('2, 3 and 4 seats receive exactly the requested number of turns', () {
    for (final count in [2, 3, 4]) {
      final players = List.generate(count, (i) => EchoPlayer('P$i'));
      final match = EchoMatch(players: players, roundLimit: 3);
      for (var turn = 0; turn < count * 3; turn++) {
        expect(match.finished, isFalse);
        expect(match.current, players[turn % count]);
        expect(match.round, turn ~/ count + 1);
        match.record(score: 10, perfect: true);
      }
      expect(match.finished, isTrue);
      expect(
        players.every(
          (p) => p.rounds == 3 && p.points == 30 && p.reachedLevel == 3,
        ),
        isTrue,
      );
      expect(match.winners.length, count);
      expect(() => match.record(score: 10, perfect: true), throwsStateError);
    }
  });

  test('solo ignores a legacy finite round limit and keeps adding points', () {
    final player = EchoPlayer('Solo');
    final match = EchoMatch(players: [player], roundLimit: 1);
    for (var i = 0; i < 250; i++) {
      match.record(score: 10, perfect: true);
      expect(match.finished, isFalse);
    }
    expect(match.roundLimit, isNull);
    expect(match.round, 251);
    expect(player.points, 2500);
  });

  test('completed level outranks points; points break a level tie', () {
    final a = EchoPlayer('A'), b = EchoPlayer('B'), c = EchoPlayer('C');
    final match = EchoMatch(players: [a, b, c], roundLimit: 2);
    match.record(score: 6, perfect: true);
    match.record(score: 10, perfect: false);
    match.record(score: 5, perfect: true);
    match.record(score: 6, perfect: true);
    match.record(score: 10, perfect: false);
    match.record(score: 5, perfect: true);
    expect(match.standings, [a, c, b]);
    expect(match.winners, [a]);
  });

  test(
    'continuous play has no round cap and difficulty stays within bounds',
    () {
      final player = EchoPlayer('Solo');
      final match = EchoMatch(players: [player], roundLimit: null);
      for (var i = 0; i < 150; i++) {
        match.record(score: 10, perfect: true);
        expect(match.finished, isFalse);
      }
      expect(player.points, 1500);
      expect(player.level, 20);
      expect(player.reachedLevel, 20);
      match.end();
      expect(match.finished, isTrue);
    },
  );

  test(
    'grids and targets grow through all 20 levels, generated sets stay valid',
    () {
      var size = 0, targets = 0;
      for (var level = 1; level <= 20; level++) {
        final config = EchoGridConfig.forTier(level);
        expect(config.size >= size, isTrue);
        expect(config.targets >= targets, isTrue);
        size = config.size;
        targets = config.targets;
        for (var seed = 0; seed < 50; seed++) {
          final puzzle = EchoGridPuzzle.generate(tier: level, seed: seed);
          expect(puzzle.targets.length, config.targets);
          expect(
            puzzle.targets.every((i) => i >= 0 && i < config.cells),
            isTrue,
          );
          expect(puzzle.evaluate(puzzle.targets).perfect, isTrue);
        }
      }
      expect(size, 7);
      expect(targets, 20);
    },
  );
}
