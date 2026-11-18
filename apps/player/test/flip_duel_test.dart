import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronova_player/core/game_kind.dart';
import 'package:neuronova_player/core/progress_store.dart';
import 'package:neuronova_player/core/sfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuronova_player/features/duel/flip_duel_screen.dart';
import 'package:neuronova_player/game/rules/flip_duel.dart';

/// Counts sounds so tests can check the right effect plays.
class _Sounds extends Sfx {
  final log = <String>[];
  @override
  void flip() => log.add('flip');
  @override
  void match() => log.add('match');
  @override
  void miss() => log.add('miss');
  @override
  void win() => log.add('win');
}

int partner(DuelGame g, int i) => List.generate(
  DuelGame.tileCount,
  (k) => k,
).firstWhere((k) => k != i && g.cards[k] == g.cards[i]);
int stranger(DuelGame g, int i) => List.generate(
  DuelGame.tileCount,
  (k) => k,
).firstWhere((k) => g.cards[k] != g.cards[i]);

void main() {
  group('rules', () {
    test('deals 36 tiles: 18 pairs, repeatable by seed', () {
      final a = DuelGame(seed: 3), b = DuelGame(seed: 3);
      expect(a.cards, b.cards);
      expect(a.cards.length, 36);
      final counts = <int, int>{};
      for (final c in a.cards) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts.length, 18);
      expect(counts.values.every((n) => n == 2), isTrue);
    });

    test('a match scores +1, keeps the turn and removes the pair', () {
      final g = DuelGame(seed: 1);
      expect(g.flip(0), FlipOutcome.first);
      expect(g.flip(0), FlipOutcome.ignored); // same tile twice
      expect(g.flip(partner(g, 0)), FlipOutcome.match);
      expect(g.flip(5), FlipOutcome.ignored); // busy until resolved
      expect(g.scores, [1, 0]);
      g.completeMatch();
      expect(g.removed.length, 2);
      expect(g.turn, 0);
      expect(g.pairsLeft, 17);
      expect(g.flip(0), FlipOutcome.ignored); // removed tile
      expect(g.flip(1), FlipOutcome.first);
    });

    test('a miss changes nothing until resolved, then passes the turn', () {
      final g = DuelGame(seed: 1);
      g.flip(0);
      expect(g.flip(stranger(g, 0)), FlipOutcome.miss);
      expect(g.busy, isTrue);
      expect(g.scores, [0, 0]);
      g.resolveMiss();
      expect(g.turn, 1);
      expect(g.firstTile, isNull);
      expect(g.removed, isEmpty);
    });

    test('winner and draw', () {
      final g = DuelGame(seed: 2);
      var i = 0;
      while (!g.over) {
        while (g.removed.contains(i)) {
          i++;
        }
        g.flip(i);
        g.flip(partner(g, i));
        g.completeMatch();
      }
      expect(g.scores, [18, 0]);
      expect(g.winner, 0);
      g.scores
        ..[0] = 9
        ..[1] = 9;
      expect(g.winner, isNull);
      g.scores
        ..[0] = 8
        ..[1] = 10;
      expect(g.winner, 1);
    });
  });

  group('bot memory', () {
    test('Hard never forgets; Easy forgets most of what it sees', () {
      int remembered(BotLevel level) {
        final bot = DuelBot(level, rng: Random(5));
        for (var i = 0; i < 1000; i++) {
          bot.observe(i, i);
        }
        return bot.memory.length;
      }

      expect(remembered(BotLevel.hard), 1000);
      expect(remembered(BotLevel.easy), inInclusiveRange(240, 360));
      final medium = remembered(BotLevel.medium);
      expect(medium, inInclusiveRange(580, 720));
      expect(remembered(BotLevel.easy), lessThan(medium));
    });

    test('a bot that has seen both halves completes the pair', () {
      final bot = DuelBot(BotLevel.hard, rng: Random(1));
      bot.observe(3, 7);
      bot.observe(20, 7);
      bot.observe(9, 2);
      final all = {for (var i = 0; i < 36; i++) i};
      final first = bot.pickFirst(all);
      expect([3, 20], contains(first));
      expect(bot.pickSecond(first, 7, all), first == 3 ? 20 : 3);
      bot.forget([3, 20]);
      expect(bot.memory.keys, [9]);
    });

    test('with no memory it flips unseen tiles, never removed ones', () {
      final bot = DuelBot(BotLevel.hard, rng: Random(2));
      bot.observe(0, 1);
      final avail = {0, 1, 2, 3};
      for (var n = 0; n < 50; n++) {
        final f = bot.pickFirst(avail);
        expect(f, isNot(0)); // 0 is known, others are unseen
        final s = bot.pickSecond(f, 99, avail);
        expect(s, isNot(f));
        expect(avail, contains(s));
      }
      // Only known tiles left: still returns a legal tile.
      expect(bot.pickFirst({0}), 0);
    });

    test('Hard beats Easy over many seeded games', () {
      int play(BotLevel level, int seed) {
        final g = DuelGame(seed: seed);
        final bot = DuelBot(level, rng: Random(seed));
        var flips = 0;
        while (!g.over && flips < 2000) {
          final a = bot.pickFirst(g.available);
          g.flip(a);
          bot.observe(a, g.symbolAt(a));
          final b = bot.pickSecond(a, g.symbolAt(a), g.available);
          final out = g.flip(b);
          bot.observe(b, g.symbolAt(b));
          flips += 2;
          if (out == FlipOutcome.match) {
            final pair = g.pendingPair!;
            g.completeMatch();
            bot.forget([pair.$1, pair.$2]);
          } else {
            g.resolveMiss();
          }
        }
        expect(g.over, isTrue);
        return flips;
      }

      var easy = 0, hard = 0;
      for (var seed = 0; seed < 20; seed++) {
        easy += play(BotLevel.easy, seed);
        hard += play(BotLevel.hard, seed);
      }
      expect(hard, lessThan(easy)); // a perfect memory needs fewer flips
    });
  });

  group('screen', () {
    late ProgressStore store;
    Future<void> open(
      WidgetTester t, {
      DuelMode mode = DuelMode.twoPlayers,
      Size size = const Size(390, 844),
      Sfx? sfx,
      int seed = 11,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      store = await ProgressStore.open();
      await t.pumpWidget(
        MaterialApp(
          home: FlipDuelScreen(
            store: store,
            mode: mode,
            seed: seed,
            sfx: sfx ?? SilentSfx(),
            botRng: Random(4),
          ),
        ),
      );
    }

    String text(WidgetTester t, String key) =>
        t.widget<Text>(find.byKey(Key(key))).data!;

    for (final size in const [Size(390, 844), Size(320, 568), Size(360, 640)]) {
      testWidgets('fits the whole board and header on ${size.width.toInt()}x'
          '${size.height.toInt()} without scrolling', (t) async {
        await open(t, size: size, mode: DuelMode.vsAi);
        expect(find.byType(Scrollable), findsNothing);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final board = t.getRect(find.byKey(const Key('duel-board')));
        expect(board.top, greaterThanOrEqualTo(0));
        expect(board.bottom, lessThanOrEqualTo(size.height));
        expect(board.right, lessThanOrEqualTo(size.width));
        for (var i = 0; i < 36; i++) {
          final r = t.getRect(find.byKey(Key('duel-token-$i')));
          expect(r.width, greaterThanOrEqualTo(40), reason: 'tap target');
        }
        expect(find.byKey(const Key('duel-score-0')), findsOneWidget);
        expect(find.byKey(const Key('duel-score-1')), findsOneWidget);
        expect(find.byKey(const Key('duel-restart')), findsOneWidget);
        expect(find.byKey(const Key('duel-mode')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('two players: match keeps the turn, miss passes it', (t) async {
      final sounds = _Sounds();
      await open(t, sfx: sounds);
      final g = DuelGame(seed: 11);
      expect(text(t, 'duel-turn'), 'Player 1: flip a tile');
      await t.tap(find.byKey(const Key('duel-token-0')));
      await t.pump(const Duration(milliseconds: 400));
      expect(text(t, 'duel-turn'), 'Player 1: flip a second tile');
      await t.tap(find.byKey(Key('duel-token-${partner(g, 0)}')));
      await t.pump(const Duration(milliseconds: 100));
      expect(text(t, 'duel-score-0'), '1');
      expect(sounds.log, ['flip', 'flip', 'match']);
      expect(text(t, 'duel-turn'), 'Match! +1 for Player 1');
      await t.pump(const Duration(milliseconds: 800)); // pair is removed
      expect(text(t, 'duel-left'), '17\nleft');
      expect(text(t, 'duel-turn'), 'Player 1: flip a tile'); // same player

      // A miss: both stay visible for a second, then the turn passes.
      // two tiles still on the board whose pictures differ
      final gone = {0, partner(g, 0)};
      final left = List.generate(36, (k) => k).where((k) => !gone.contains(k));
      final a = left.first;
      final b = left.firstWhere((k) => g.cards[k] != g.cards[a]);
      await t.tap(find.byKey(Key('duel-token-$a')));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(Key('duel-token-$b')));
      await t.pump(const Duration(milliseconds: 400));
      expect(sounds.log.last, 'miss');
      expect(text(t, 'duel-turn'), 'No match — remember them!');
      await t.tap(find.byKey(const Key('duel-token-30'))); // ignored: locked
      await t.pump(const Duration(milliseconds: 700));
      expect(text(t, 'duel-turn'), 'Player 2: flip a tile');
      expect(text(t, 'duel-score-0'), '1');
      expect(text(t, 'duel-score-1'), '0');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a whole two-player game ends with a winner and replay', (
      t,
    ) async {
      final sounds = _Sounds();
      await open(t, sfx: sounds);
      final g = DuelGame(seed: 11);
      for (var i = 0; i < 36; i++) {
        final p = partner(g, i);
        if (p < i) continue;
        await t.tap(find.byKey(Key('duel-token-$i')));
        await t.pump(const Duration(milliseconds: 50));
        await t.tap(find.byKey(Key('duel-token-$p')));
        await t.pump(const Duration(milliseconds: 800));
      }
      expect(find.byKey(const Key('duel-win')), findsOneWidget);
      expect(find.text('Player 1 wins!'), findsOneWidget);
      expect(text(t, 'duel-final'), '18  –  0');
      expect(sounds.log.last, 'win');
      await t.tap(find.byKey(const Key('duel-play-again')));
      await t.pump();
      expect(find.byKey(const Key('duel-win')), findsNothing);
      expect(text(t, 'duel-score-0'), '0');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('mute silences sounds; restart and mode change reset', (
      t,
    ) async {
      final sounds = _Sounds();
      await open(t, sfx: sounds);
      await t.tap(find.byKey(const Key('duel-sound')));
      await t.pump();
      expect(find.byTooltip('Sound off'), findsOneWidget);
      await t.tap(find.byKey(const Key('duel-token-0')));
      await t.pump(const Duration(milliseconds: 400));
      expect(sounds.log, isEmpty);
      await t.tap(find.byKey(const Key('duel-sound')));
      await t.pump();
      await t.tap(find.byKey(const Key('duel-token-1')));
      await t.pump(const Duration(milliseconds: 400));
      expect(sounds.log, contains('flip'));
      await t.pump(const Duration(seconds: 2));
      await t.tap(find.byKey(const Key('duel-restart')));
      await t.pump();
      expect(text(t, 'duel-turn'), 'Player 1: flip a tile');
      await t.tap(find.text('vs AI'));
      await t.pump();
      expect(text(t, 'duel-name-1'), 'AI');
      expect(find.byKey(const Key('duel-level')), findsOneWidget);
      await t.tap(find.text('Hard'));
      await t.pump();
      expect(text(t, 'duel-name-0'), 'You');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'vs AI: the bot plays by itself and the board stays consistent',
      (t) async {
        await open(t, mode: DuelMode.vsAi, seed: 11);
        final g = DuelGame(seed: 11);
        final a = 0, b = stranger(g, 0);
        await t.tap(find.byKey(Key('duel-token-$a')));
        await t.pump(const Duration(milliseconds: 100));
        await t.tap(find.byKey(Key('duel-token-$b')));
        await t.pump(const Duration(milliseconds: 1100)); // miss, then AI turn
        expect(text(t, 'duel-turn'), 'AI is thinking…');
        // The human cannot move during the bot's turn.
        await t.tap(find.byKey(const Key('duel-token-20')));
        await t.pump(const Duration(milliseconds: 100));
        expect(text(t, 'duel-turn'), 'AI is thinking…');
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 500));
        }
        final left = int.parse(text(t, 'duel-left').split('\n').first);
        final total =
            int.parse(text(t, 'duel-score-0')) +
            int.parse(text(t, 'duel-score-1'));
        expect(total + left, 18);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    Future<void> playAllPairs(WidgetTester t, DuelGame g) async {
      for (var i = 0; i < 36; i++) {
        final p = partner(g, i);
        if (p < i) continue;
        await t.tap(find.byKey(Key('duel-token-$i')));
        await t.pump(const Duration(milliseconds: 50));
        await t.tap(find.byKey(Key('duel-token-$p')));
        await t.pump(const Duration(milliseconds: 800));
      }
    }

    testWidgets('vs AI: a win feeds the shared points, level and header', (
      t,
    ) async {
      await open(t, mode: DuelMode.vsAi);
      final key = GameKind.flipDuel.skillKey;
      expect(store.pointsFor(key), 0);
      expect(find.byKey(const Key('game-score-bar')), findsOneWidget);
      expect(find.byKey(const Key('game-settings')), findsOneWidget);
      await playAllPairs(t, DuelGame(seed: 11));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('You win!'), findsOneWidget);
      expect(store.pointsFor(key), 10); // all 18 pairs = 10 points
      expect(store.roundsFor(key), 1);
      expect(store.levelFor(key), 2); // a win raises the level
      expect(text(t, 'game-total-score'), '10'); // the shared header counted up
      expect(text(t, 'duel-gain'), '+10 points');
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('Lv2'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('two players: a finished game saves nothing', (t) async {
      await open(t);
      await playAllPairs(t, DuelGame(seed: 11));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Player 1 wins!'), findsOneWidget);
      final key = GameKind.flipDuel.skillKey;
      expect(store.pointsFor(key), 0);
      expect(store.roundsFor(key), 0);
      expect(find.byKey(const Key('duel-gain')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('shared settings: no timer or seat options; difficulty sets '
        'the bot', (t) async {
      await open(t, mode: DuelMode.vsAi);
      expect(
        t
            .widget<SegmentedButton<BotLevel>>(
              find.byKey(const Key('duel-level')),
            )
            .selected,
        {BotLevel.easy}, // a new player's level 1 meets the easy bot
      );
      await t.tap(find.byKey(const Key('game-settings')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('game-untimed')), findsNothing);
      expect(find.byKey(const Key('match-settings')), findsNothing);
      await t.tap(find.byKey(const Key('game-difficulty')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hard').last);
      await t.pumpAndSettle();
      final save = find.byKey(const Key('save-game-settings'));
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(
        t
            .widget<SegmentedButton<BotLevel>>(
              find.byKey(const Key('duel-level')),
            )
            .selected,
        {BotLevel.hard},
      );
      expect(text(t, 'duel-turn'), 'You: flip a tile'); // fresh game
      await t.pumpWidget(const SizedBox());
    });
  });
}
