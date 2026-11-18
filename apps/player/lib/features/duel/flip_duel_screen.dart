import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/sfx.dart';
import '../../game/rules/flip_duel.dart';
import '../../game/rules/flip_match.dart';

/// Who plays player 2.
enum DuelMode { vsAi, twoPlayers }

// Colours of the plastic board game: green board, purple token backs.
const _boardLight = Color(0xFF4FD18B);
const _boardDark = Color(0xFF1E9E63);
const _recess = Color(0xFF137A4C);
const _tokenLight = Color(0xFFA97CFF);
const _tokenDark = Color(0xFF5B34B8);
const _cream = Color(0xFFFFF8E7);

/// A shared 6 x 6 board of 18 fruit / animal pairs for two players, taking
/// turns on one device or against a bot with a memory.
class FlipDuelScreen extends StatefulWidget {
  const FlipDuelScreen({
    super.key,
    this.mode = DuelMode.vsAi,
    this.level = BotLevel.medium,
    this.seed,
    this.sfx,
    this.botRng,
  });
  final DuelMode mode;
  final BotLevel level;

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
  late BotLevel level = widget.level;
  late final Sfx sfx = widget.sfx ?? createSfx();
  late DuelGame game;
  late DuelBot bot;
  bool muted = false;
  Timer? _timer;
  int _burstId = 0;
  final List<_Burst> bursts = [];

  /// Input is ignored while a result is showing or the bot is playing.
  bool locked = false;

  bool get botTurn => mode == DuelMode.vsAi && game.turn == 1 && !game.over;

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
    game = DuelGame(seed: seed);
    bot = DuelBot(level, rng: widget.botRng);
    locked = false;
    bursts.clear();
    setState(() {});
  }

  String get p0 => mode == DuelMode.vsAi ? 'You' : 'Player 1';
  String get p1 => mode == DuelMode.vsAi ? 'AI' : 'Player 2';
  String nameOf(int player) => player == 0 ? p0 : p1;

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
        // Let both players see the pair, then take it off the board.
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
      return;
    }
    _maybeBot(); // a match keeps the turn
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
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text('Flip Duel', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            key: const Key('duel-sound'),
            tooltip: muted ? 'Sound off' : 'Sound on',
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
            onPressed: () => setState(() => muted = !muted),
          ),
          IconButton(
            key: const Key('duel-restart'),
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh_rounded),
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

  Widget _scoreCard(int player) {
    final active = game.turn == player && !game.over;
    final color = player == 0 ? NovaColors.emerald : NovaColors.gold;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .16) : NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withValues(alpha: .18),
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nameOf(player),
                key: Key('duel-name-$player'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? color : NovaColors.textSecondary,
                ),
              ),
            ),
            Semantics(
              label: '${nameOf(player)} score ${game.scores[player]}',
              excludeSemantics: true,
              child: Text(
                '${game.scores[player]}',
                key: Key('duel-score-$player'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreboard() => Row(
    children: [
      _scoreCard(0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Tooltip(
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
        ),
      ),
      _scoreCard(1),
    ],
  );

  /// Current turn indicator, in words.
  Widget _status() {
    final String text;
    if (game.over) {
      text = 'Game over';
    } else if (botTurn) {
      text = '$p1 is thinking…';
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
          color: game.turn == 0 ? NovaColors.emerald : NovaColors.gold,
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
          segments: const [
            ButtonSegment(
              value: DuelMode.vsAi,
              label: Text('vs AI'),
              icon: Icon(Icons.smart_toy_outlined, size: 18),
            ),
            ButtonSegment(
              value: DuelMode.twoPlayers,
              label: Text('2 Players'),
              icon: Icon(Icons.people_alt_outlined, size: 18),
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

  Widget _board(double side) {
    const pad = 10.0, gap = 6.0;
    final cell = (side - pad * 2 - gap * (DuelGame.cols - 1)) / DuelGame.cols;
    return Container(
      key: const Key('duel-board'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_boardLight, _boardDark],
        ),
        border: Border.all(color: const Color(0xFF8CF0BC), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(pad),
            child: Column(
              children: [
                for (var r = 0; r < DuelGame.cols; r++) ...[
                  if (r > 0) const SizedBox(height: gap),
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < DuelGame.cols; col++) ...[
                          if (col > 0) const SizedBox(width: gap),
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
                child: _BurstView(
                  key: ValueKey(b.id),
                  centers: b.centers,
                  radius: cell * .8,
                  onDone: () {
                    if (mounted) setState(() => bursts.remove(b));
                  },
                ),
              ),
            ),
          if (game.over) Positioned.fill(child: _winPanel()),
        ],
      ),
    );
  }

  /// Side of the board in pixels, remembered from the last layout so bursts
  /// can be placed over the two matched tiles.
  double _side = 300;

  void _addBurst((int, int) pair) {
    const pad = 10.0, gap = 6.0;
    final cell = (_side - pad * 2 - gap * (DuelGame.cols - 1)) / DuelGame.cols;
    Offset centerOf(int i) => Offset(
      pad + (i % DuelGame.cols) * (cell + gap) + cell / 2,
      pad + (i ~/ DuelGame.cols) * (cell + gap) + cell / 2,
    );
    bursts.add(_Burst(_burstId++, [centerOf(pair.$1), centerOf(pair.$2)]));
  }

  Widget _slot(int i) {
    final removed = game.removed.contains(i);
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(c.maxWidth, c.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The recessed hole the token sits in.
                DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF1B9560), _recess],
                      stops: [.55, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x55FFFFFF),
                        blurRadius: 1,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: SizedBox.expand(),
                ),
                _Token(
                  key: Key('duel-token-$i'),
                  faceUp: game.isFaceUp(i),
                  removed: removed,
                  symbol: flipSymbols[game.symbolAt(i)],
                  size: size,
                  label: 'Tile ${i + 1}',
                  onTap: () => _onTap(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _winPanel() {
    final w = game.winner;
    final title = w == null
        ? 'It’s a draw!'
        : (mode == DuelMode.vsAi && w == 0 ? 'You win!' : '${nameOf(w)} wins!');
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${game.scores[0]}  –  ${game.scores[1]}',
              key: const Key('duel-final'),
              style: const TextStyle(
                fontSize: 22,
                color: NovaColors.gold,
                fontWeight: FontWeight.w800,
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

/// A round token: purple "?" back, cartoon front, 3D flip, tap bounce, and a
/// shrink-away when its pair is taken off the board.
class _Token extends StatefulWidget {
  const _Token({
    super.key,
    required this.faceUp,
    required this.removed,
    required this.symbol,
    required this.size,
    required this.label,
    required this.onTap,
  });
  final bool faceUp, removed;
  final FlipSymbol symbol;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Token> createState() => _TokenState();
}

class _TokenState extends State<_Token> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.faceUp ? 1 : 0,
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(_Token old) {
    super.didUpdateWidget(old);
    if (widget.faceUp != old.faceUp) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _flip.value = widget.faceUp ? 1 : 0;
      } else {
        widget.faceUp ? _flip.forward() : _flip.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Widget _back() => _disc(
    gradient: const RadialGradient(
      center: Alignment(-.3, -.4),
      colors: [_tokenLight, _tokenDark],
    ),
    ring: const Color(0xFFC9AEFF),
    child: Text(
      '?',
      style: TextStyle(
        fontSize: widget.size * .52,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1,
      ),
    ),
  );

  Widget _front() => _disc(
    gradient: const RadialGradient(
      center: Alignment(-.3, -.4),
      colors: [Colors.white, _cream],
    ),
    ring: const Color(0xFFFFD27A),
    child: Text(
      widget.symbol.emoji,
      style: TextStyle(fontSize: widget.size * .55, height: 1),
    ),
  );

  Widget _disc({
    required Gradient gradient,
    required Color ring,
    required Widget child,
  }) => Container(
    width: widget.size * .9,
    height: widget.size * .9,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: gradient,
      border: Border.all(color: ring, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 4,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: widget.removed,
      child: AnimatedScale(
        scale: widget.removed ? 0 : (_pressed ? .9 : 1),
        duration: Duration(
          milliseconds: reduce ? 0 : (widget.removed ? 260 : 90),
        ),
        curve: widget.removed ? Curves.easeInBack : Curves.easeOut,
        child: Semantics(
          button: true,
          label: widget.faceUp
              ? '${widget.label}: ${widget.symbol.name}'
              : '${widget.label}, face down',
          excludeSemantics: true,
          onTap: widget.onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            // The whole slot is the tap target; the disc is a little smaller.
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) {
                    final v = _flip.value;
                    final showFront = v > .5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015) // perspective
                        ..rotateY(pi * v),
                      child: showFront
                          // Mirror the front so it reads correctly after the turn.
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: _front(),
                            )
                          : _back(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short burst of coloured dots from each matched tile.
class _BurstView extends StatefulWidget {
  const _BurstView({
    super.key,
    required this.centers,
    required this.radius,
    required this.onDone,
  });
  final List<Offset> centers;
  final double radius;
  final VoidCallback onDone;

  @override
  State<_BurstView> createState() => _BurstViewState();
}

class _BurstViewState extends State<_BurstView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _BurstPainter(widget.centers, widget.radius, _c.value),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.centers, this.radius, this.t);
  final List<Offset> centers;
  final double radius, t;
  static const _colors = [
    Color(0xFFFFD27A),
    Color(0xFFFF8D9B),
    Color(0xFF7AA9FF),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    for (final c in centers) {
      for (var k = 0; k < 10; k++) {
        final a = k * 2 * pi / 10;
        final p = c + Offset(cos(a), sin(a)) * (radius * ease);
        canvas.drawCircle(
          p,
          (1 - t) * 4 + .5,
          Paint()..color = _colors[k % _colors.length].withValues(alpha: 1 - t),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
