import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../core/progress_store.dart';
import '../../core/sfx.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/flip_duel.dart';
import '../../game/rules/flip_match.dart';
import '../../game/rules/scoring.dart';
import '../catalog/game_presentation.dart';
import '../catalog/game_settings_screen.dart';
import '../gameplay/game_header.dart';
import '../gameplay/nova_board.dart';

/// Who plays: you against the AI, or friends sharing the device (2 to 4, set
/// in the game's Settings).
enum DuelMode { vsAi, friends }

/// Seat colours: player 1 to 4.
const _seatColors = [
  NovaColors.emerald,
  NovaColors.gold,
  Color(0xFF83B6FF),
  Color(0xFFFF8E91),
];

/// A shared 6 x 6 board of 18 fruit / animal pairs. Players take turns on one
/// device, or you play against a bot with a memory.
class FlipDuelScreen extends StatefulWidget {
  const FlipDuelScreen({
    super.key,
    required this.store,
    this.mode = DuelMode.vsAi,
    this.level,
    this.seed,
    this.sfx,
    this.botRng,
  });
  final ProgressStore store;
  final DuelMode mode;

  /// Bot difficulty; from the game's settings (or the player's level) if null.
  final BotLevel? level;

  /// Fixed deal (tests); random when null.
  final int? seed;

  /// Injected sound (tests); synthesized Web Audio sounds by default.
  final Sfx? sfx;

  /// Fixed randomness for the bot (tests).
  final Random? botRng;

  @override
  State<FlipDuelScreen> createState() => _FlipDuelScreenState();
}

class _Burst {
  _Burst(this.id, this.centers);
  final int id;
  final List<Offset> centers;
}

class _FlipDuelScreenState extends State<FlipDuelScreen> {
  late DuelMode mode = widget.mode;
  late BotLevel level = widget.level ?? _levelFromSettings();
  late final Sfx sfx = widget.sfx ?? createSfx();
  late DuelGame game;
  late DuelBot bot;
  bool muted = false;
  Timer? _timer;
  int _burstId = 0;
  final List<_Burst> bursts = [];

  /// Input is ignored while a result is showing or the bot is playing.
  bool locked = false;

  /// Points just earned from a finished game against the AI (header pop).
  int? gain;
  late String roundId;
  bool committed = false;

  /// Side of the board in pixels, remembered from the last layout so bursts
  /// can be placed over the two matched tiles.
  double _side = 300;

  int get players => mode == DuelMode.vsAi ? 2 : widget.store.duelPlayers;
  bool get botTurn => mode == DuelMode.vsAi && game.turn == 1 && !game.over;

  BotLevel _levelFromSettings() {
    final key = GameKind.flipDuel.skillKey;
    return botLevelForTier(
      widget.store.practiceTierFor(key) ?? widget.store.levelFor(key),
    );
  }

  @override
  void initState() {
    super.initState();
    _newGame(widget.seed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    sfx.dispose();
    super.dispose();
  }

  void _newGame([int? seed]) {
    _timer?.cancel();
    game = DuelGame(players: players, seed: seed);
    roundId = '${DateTime.now().microsecondsSinceEpoch}-${game.hashCode}';
    committed = false;
    gain = null;
    bot = DuelBot(level, rng: widget.botRng);
    locked = false;
    bursts.clear();
    setState(() {});
  }

  String nameOf(int player) => mode == DuelMode.vsAi
      ? (player == 0 ? 'You' : 'AI')
      : 'Player ${player + 1}';

  void _play(void Function() sound) {
    if (!muted) sound();
  }

  // ---- turn flow -----------------------------------------------------------

  void _onTap(int i) {
    if (locked || botTurn || game.over) return;
    _flip(i);
  }

  /// Flip tile [i] for the current player and run whatever follows.
  void _flip(int i) {
    final outcome = game.flip(i);
    if (outcome == FlipOutcome.ignored) return;
    bot.observe(i, game.symbolAt(i)); // the bot watches every flip
    _play(sfx.flip);
    HapticFeedback.selectionClick();
    setState(() {});
    switch (outcome) {
      case FlipOutcome.first:
        _maybeBot();
      case FlipOutcome.match:
        locked = true;
        _play(sfx.match);
        HapticFeedback.lightImpact();
        _addBurst(game.pendingPair!);
        // Let everyone see the pair, then take it off the board.
        _timer = Timer(const Duration(milliseconds: 650), _finishMatch);
      case FlipOutcome.miss:
        locked = true;
        _play(sfx.miss);
        // One second to memorise before flipping back.
        _timer = Timer(const Duration(milliseconds: 1000), _finishMiss);
      case FlipOutcome.ignored:
        break;
    }
  }

  void _finishMatch() {
    if (!mounted) return;
    final pair = game.pendingPair!;
    game.completeMatch();
    bot.forget([pair.$1, pair.$2]);
    locked = false;
    setState(() {});
    if (game.over) {
      _play(sfx.win);
      HapticFeedback.mediumImpact();
      _commit();
      return;
    }
    _maybeBot(); // a match keeps the turn
  }

  /// A finished game against the AI feeds the same points / level system as
  /// the other games: 0-10 points by your share of the pairs, and a level-up
  /// for a win. Games with friends never touch saved progress.
  Future<void> _commit() async {
    if (mode != DuelMode.vsAi || committed) return;
    committed = true;
    final key = GameKind.flipDuel.skillKey;
    final mine = game.scores[0];
    final won = game.winner == 0;
    final points = (maxRoundScore * mine / DuelGame.pairs).round();
    final skill = widget.store.skillFor(key);
    skill.record(RoundRecord(accuracy: mine / DuelGame.pairs, success: won));
    await widget.store.commitRound(
      roundId: roundId,
      score: points,
      xp: 0,
      skill: skill,
      skillKey: key,
      levelUp: won,
    );
    if (mounted) setState(() => gain = points);
  }

  void _finishMiss() {
    if (!mounted) return;
    game.resolveMiss();
    locked = false;
    setState(() {});
    _maybeBot();
  }

  /// If it is the bot's turn, make its next flip after a short think.
  void _maybeBot() {
    if (!botTurn || locked) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted || !botTurn || locked) return;
      final first = game.firstTile;
      if (first == null) {
        _flip(bot.pickFirst(game.available));
      } else {
        _flip(bot.pickSecond(first, game.symbolAt(first), game.available));
      }
    });
  }

  Future<void> _openSettings() async {
    _timer?.cancel();
    locked = true; // freeze the board while settings are open
    final seatsBefore = players;
    await Navigator.of(context).push<GameSettingsAction>(
      MaterialPageRoute(
        builder: (_) =>
            GameSettingsScreen(kind: GameKind.flipDuel, store: widget.store),
      ),
    );
    if (!mounted) return;
    final before = level;
    level = _levelFromSettings();
    if (level != before || players != seatsBefore) {
      _newGame(); // a new difficulty or player count starts a fresh game
      return;
    }
    // Same settings: carry on exactly where the game was paused.
    locked = false;
    if (game.pendingPair != null) {
      _finishMatch();
    } else if (game.busy) {
      _finishMiss();
    } else {
      _maybeBot();
    }
  }

  void _setMode(DuelMode m) {
    if (m == mode) return;
    mode = m;
    _newGame();
  }

  void _setLevel(BotLevel l) {
    if (l == level) return;
    level = l;
    _newGame();
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameHeader(
        kind: GameKind.flipDuel,
        points: widget.store.pointsFor(GameKind.flipDuel.skillKey),
        round: widget.store.roundsFor(GameKind.flipDuel.skillKey) + 1,
        level: widget.store.levelFor(GameKind.flipDuel.skillKey),
        difficulty: mode == DuelMode.vsAi ? level.label : '$players players',
        onSettings: _openSettings,
        animate: true,
        gain: gain,
        gainKey: roundId,
        extraActions: [
          IconButton(
            key: const Key('duel-sound'),
            tooltip: muted ? 'Sound off' : 'Sound on',
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 23,
            ),
            onPressed: () => setState(() => muted = !muted),
          ),
          IconButton(
            key: const Key('duel-restart'),
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh_rounded, size: 23),
            onPressed: () => _newGame(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  _scoreboard(),
                  const SizedBox(height: 6),
                  _status(),
                  const SizedBox(height: 6),
                  _modeBar(),
                  const SizedBox(height: 10),
                  Expanded(child: _boardArea()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One player's card. Two players get a wide card (name left, score right);
  /// three or four get narrow stacked cards so they all fit on one row.
  Widget _scoreCard(int player) {
    final active = game.turn == player && !game.over;
    final color = _seatColors[player];
    final wide = game.players == 2;
    final name = Text(
      nameOf(player),
      key: Key('duel-name-$player'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: wide ? 13 : 11,
        fontWeight: FontWeight.w700,
        color: active ? color : NovaColors.textSecondary,
      ),
    );
    final score = Semantics(
      label: '${nameOf(player)} score ${game.scores[player]}',
      excludeSemantics: true,
      child: Text(
        '${game.scores[player]}',
        key: Key('duel-score-$player'),
        style: TextStyle(
          fontSize: wide ? 26 : 24,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 6, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .16) : NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withValues(alpha: .18),
            width: active ? 2 : 1,
          ),
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(child: name),
                  score,
                ],
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [name, score]),
      ),
    );
  }

  Widget _scoreboard() => Row(
    children: [
      for (var i = 0; i < game.players; i++) ...[
        _scoreCard(i),
        if (i == 0 && game.players == 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _left(),
          )
        else if (i < game.players - 1)
          const SizedBox(width: 6),
      ],
    ],
  );

  /// Pairs still on the board.
  Widget _left() => Tooltip(
    message: '${game.pairsLeft} pairs left',
    child: Text(
      '${game.pairsLeft}\nleft',
      textAlign: TextAlign.center,
      key: const Key('duel-left'),
      style: const TextStyle(
        fontSize: 11,
        height: 1.1,
        color: NovaColors.textSecondary,
      ),
    ),
  );

  /// Current turn indicator, in words.
  Widget _status() {
    final String text;
    if (game.over) {
      text = 'Game over';
    } else if (botTurn) {
      text = '${nameOf(1)} is thinking…';
    } else if (game.pendingPair != null) {
      text = 'Match! +1 for ${nameOf(game.turn)}';
    } else if (game.busy) {
      text = 'No match — remember them!';
    } else if (game.firstTile == null) {
      text = '${nameOf(game.turn)}: flip a tile';
    } else {
      text = '${nameOf(game.turn)}: flip a second tile';
    }
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: const Key('duel-turn'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _seatColors[game.turn],
        ),
      ),
    );
  }

  Widget _modeBar() => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<DuelMode>(
          key: const Key('duel-mode'),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          segments: [
            const ButtonSegment(
              value: DuelMode.vsAi,
              label: Text('vs AI'),
              icon: Icon(Icons.smart_toy_outlined, size: 18),
            ),
            ButtonSegment(
              value: DuelMode.friends,
              label: Text('${widget.store.duelPlayers} Players'),
              icon: const Icon(Icons.people_alt_outlined, size: 18),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => _setMode(s.first),
        ),
      ),
      if (mode == DuelMode.vsAi) ...[
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<BotLevel>(
            key: const Key('duel-level'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final l in BotLevel.values)
                ButtonSegment(value: l, label: Text(l.label)),
            ],
            selected: {level},
            onSelectionChanged: (s) => _setLevel(s.first),
          ),
        ),
      ],
    ],
  );

  /// The board is a square sized to whatever room is left, so it always fits
  /// in portrait without scrolling.
  Widget _boardArea() => LayoutBuilder(
    builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      _side = side;
      return Center(
        child: SizedBox(width: side, height: side, child: _board(side)),
      );
    },
  );

  /// Board padding and gap; tighter on very small screens so tiles stay big.
  (double, double) _metrics(double side) =>
      side < 300 ? (7.0, 4.0) : (10.0, 6.0);

  Widget _board(double side) {
    final (pad, gap) = _metrics(side);
    return Stack(
      key: const Key('duel-board'),
      children: [
        NovaBoardFrame(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              for (var r = 0; r < DuelGame.cols; r++) ...[
                if (r > 0) SizedBox(height: gap),
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < DuelGame.cols; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        Expanded(child: _slot(r * DuelGame.cols + col)),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final b in bursts)
          Positioned.fill(
            child: IgnorePointer(
              child: NovaBurst(
                key: ValueKey(b.id),
                centers: b.centers,
                radius: (side / 6) * .8,
                onDone: () {
                  if (mounted) setState(() => bursts.remove(b));
                },
              ),
            ),
          ),
        if (game.over) Positioned.fill(child: _winPanel()),
      ],
    );
  }

  void _addBurst((int, int) pair) {
    final (pad, gap) = _metrics(_side);
    final cell = (_side - pad * 2 - gap * (DuelGame.cols - 1)) / DuelGame.cols;
    Offset centerOf(int i) => Offset(
      pad + (i % DuelGame.cols) * (cell + gap) + cell / 2,
      pad + (i ~/ DuelGame.cols) * (cell + gap) + cell / 2,
    );
    bursts.add(_Burst(_burstId++, [centerOf(pair.$1), centerOf(pair.$2)]));
  }

  Widget _slot(int i) => LayoutBuilder(
    builder: (context, c) {
      final size = min(c.maxWidth, c.maxHeight);
      return Center(
        child: NovaSlot(
          size: size,
          child: NovaToken(
            key: Key('duel-token-$i'),
            faceUp: game.isFaceUp(i),
            removed: game.removed.contains(i),
            symbol: flipSymbols[game.symbolAt(i)],
            size: size,
            label: 'Tile ${i + 1}',
            onTap: () => _onTap(i),
          ),
        ),
      );
    },
  );

  Widget _winPanel() {
    final w = game.winners;
    final String title;
    if (w.length == game.players) {
      title = 'It’s a draw!';
    } else if (w.length > 1) {
      title = '${w.map(nameOf).join(' & ')} tie!';
    } else if (mode == DuelMode.vsAi && w.first == 0) {
      title = 'You win!';
    } else {
      title = '${nameOf(w.first)} wins!';
    }
    return Container(
      key: const Key('duel-win'),
      decoration: BoxDecoration(
        color: const Color(0xE60B1426),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: NovaColors.gold,
              size: 56,
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              game.scores.join('  –  '),
              key: const Key('duel-final'),
              style: const TextStyle(
                fontSize: 22,
                color: NovaColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (gain != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$gain points',
                  key: const Key('duel-gain'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GameKind.flipDuel.accent,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('duel-play-again'),
              onPressed: () => _newGame(),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play again'),
            ),
          ],
        ),
      ),
    );
  }
}
