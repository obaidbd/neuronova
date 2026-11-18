import 'dart:math';

import 'flip_match.dart';

/// Pure rules for Flip Duel: a shared 6 x 6 board of 18 fruit / animal pairs,
/// two to four players taking turns. No Flutter imports, so it is easy to test.

/// How the bot's memory behaves.
enum BotLevel { easy, medium, hard }

/// Practice difficulty (Easy 2, Normal 5, Hard 8) or the player's level when
/// on Auto: low levels meet an easy bot, high levels a perfect memory.
BotLevel botLevelForTier(int tier) => tier <= 3
    ? BotLevel.easy
    : tier <= 6
    ? BotLevel.medium
    : BotLevel.hard;

extension BotLevelInfo on BotLevel {
  String get label => switch (this) {
    BotLevel.easy => 'Easy',
    BotLevel.medium => 'Medium',
    BotLevel.hard => 'Hard',
  };

  /// Chance the bot remembers a tile it has seen flipped.
  double get recall => switch (this) {
    BotLevel.easy => .30,
    BotLevel.medium => .65,
    BotLevel.hard => 1.0,
  };
}

/// What a tap on a tile did.
enum FlipOutcome {
  /// Ignored: board finished, tile removed, tile already open, or a mismatch
  /// is still showing.
  ignored,

  /// First tile of a turn is now face up.
  first,

  /// Second tile matched the first. Call [DuelGame.completeMatch] when the
  /// celebration is over.
  match,

  /// Second tile did not match. Call [DuelGame.resolveMiss] after the pause.
  miss,
}

class DuelGame {
  DuelGame({int players = 2, int? seed, Random? rng})
    : players = players.clamp(2, 4),
      scores = List.filled(players.clamp(2, 4), 0),
      cards = _deal(rng ?? Random(seed));

  /// Number of players taking turns (2 to 4).
  final int players;

  static const cols = 6;
  static const pairs = 18;
  static const tileCount = cols * cols;

  /// Symbol (index into [flipSymbols]) on each tile; every symbol twice.
  final List<int> cards;

  /// Tiles already matched and taken off the board.
  final Set<int> removed = {};

  /// Points for each player.
  final List<int> scores;

  /// Whose turn it is: 0 to players - 1.
  int turn = 0;

  /// Tiles currently face up this turn.
  int? firstTile, secondTile;

  /// A matched pair waiting to be removed (shown for a moment first).
  (int, int)? pendingPair;

  static List<int> _deal(Random rng) {
    final ids = List<int>.generate(flipSymbols.length, (i) => i)..shuffle(rng);
    return <int>[
      for (final id in ids.take(pairs)) ...[id, id],
    ]..shuffle(rng);
  }

  int symbolAt(int i) => cards[i];

  /// Tiles still on the board.
  Set<int> get available => {
    for (var i = 0; i < tileCount; i++)
      if (!removed.contains(i)) i,
  };

  int get pairsLeft => pairs - removed.length ~/ 2;
  bool get over => removed.length == tileCount;

  /// Everyone with the highest score (more than one means a tie).
  List<int> get winners {
    final best = scores.reduce(max);
    return [
      for (var i = 0; i < players; i++)
        if (scores[i] == best) i,
    ];
  }

  /// The single winner, or null when the top score is shared (a draw).
  int? get winner => winners.length == 1 ? winners.first : null;

  bool isFaceUp(int i) => i == firstTile || i == secondTile;

  /// True while a miss is showing or a match is waiting to be removed.
  bool get busy => secondTile != null;

  FlipOutcome flip(int i) {
    if (over || busy || removed.contains(i) || i == firstTile) {
      return FlipOutcome.ignored;
    }
    if (i < 0 || i >= tileCount) return FlipOutcome.ignored;
    if (firstTile == null) {
      firstTile = i;
      return FlipOutcome.first;
    }
    secondTile = i;
    if (cards[firstTile!] == cards[i]) {
      scores[turn]++; // +1 and the same player goes again
      pendingPair = (firstTile!, i);
      return FlipOutcome.match;
    }
    return FlipOutcome.miss;
  }

  /// Take the matched pair off the board; the same player keeps the turn.
  void completeMatch() {
    final pair = pendingPair;
    if (pair == null) return;
    removed
      ..add(pair.$1)
      ..add(pair.$2);
    pendingPair = null;
    firstTile = secondTile = null;
  }

  /// Turn both mismatched tiles face down and pass the turn.
  void resolveMiss() {
    if (secondTile == null || pendingPair != null) return;
    firstTile = secondTile = null;
    turn = (turn + 1) % players;
  }
}

/// A bot that only knows what it has actually seen, and sometimes forgets.
class DuelBot {
  DuelBot(this.level, {Random? rng}) : _rng = rng ?? Random();
  final BotLevel level;
  final Random _rng;

  /// Remembered tiles: position -> symbol.
  final Map<int, int> memory = {};

  /// Called for every tile flipped face up, by either player.
  void observe(int position, int symbol) {
    if (_rng.nextDouble() < level.recall) memory[position] = symbol;
  }

  /// Called when tiles leave the board.
  void forget(Iterable<int> positions) => positions.forEach(memory.remove);

  int _random(Iterable<int> from) {
    final list = from.toList();
    return list[_rng.nextInt(list.length)];
  }

  /// First flip of a turn: finish a pair it remembers, else try a new tile.
  int pickFirst(Set<int> available) {
    final bySymbol = <int, List<int>>{};
    memory.forEach((pos, symbol) {
      if (available.contains(pos)) {
        (bySymbol[symbol] ??= []).add(pos);
      }
    });
    for (final positions in bySymbol.values) {
      if (positions.length >= 2) return positions.first;
    }
    final unknown = available.where((p) => !memory.containsKey(p));
    return _random(unknown.isNotEmpty ? unknown : available);
  }

  /// Second flip: the remembered partner of the first tile if it knows it,
  /// otherwise another tile it has not seen.
  int pickSecond(int first, int firstSymbol, Set<int> available) {
    for (final entry in memory.entries) {
      if (entry.key != first &&
          entry.value == firstSymbol &&
          available.contains(entry.key)) {
        return entry.key;
      }
    }
    final others = available.where((p) => p != first);
    final unknown = others.where((p) => !memory.containsKey(p));
    return _random(unknown.isNotEmpty ? unknown : others);
  }
}
