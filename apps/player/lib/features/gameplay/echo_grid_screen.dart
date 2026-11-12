import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/echo_grid.dart';
import '../../game/rules/echo_match.dart';
import '../../game/rules/scoring.dart';
import '../../core/game_kind.dart';
import '../catalog/game_settings_screen.dart';
import 'echo_setup_screen.dart';
import 'game_score_bar.dart';

enum _Phase { ready, preview, recall, result, finished }

class EchoGridScreen extends StatefulWidget {
  const EchoGridScreen({
    super.key,
    required this.store,
    this.tutorial = false,
    this.seed,
    this.tierOverride,
    this.match,
  });
  final ProgressStore store;
  final bool tutorial;
  final int? seed;
  final int? tierOverride;
  final EchoMatch? match;
  @override
  State<EchoGridScreen> createState() => _EchoGridScreenState();
}

class _EchoGridScreenState extends State<EchoGridScreen> {
  late EchoMatch match;
  late EchoPlayer player;
  late EchoGridPuzzle puzzle;
  late SkillState skill;
  final selected = <int>{};
  _Phase phase = _Phase.preview;
  Timer? timer;
  final clock = Stopwatch();
  EchoGridResult? result;
  int remaining = 4, playedRound = 1, score = 0, xpAwarded = 0;
  bool committing = false;
  late String roundId;
  int? activeTierOverride;

  @override
  void initState() {
    super.initState();
    skill = widget.store.memorySkill;
    activeTierOverride =
        widget.tierOverride ?? widget.store.practiceTierFor('visual_memory');
    match =
        widget.match ??
        EchoMatch(
          roundLimit: widget.tutorial ? 1 : null,
          players: [
            EchoPlayer(
              'Player 1',
              previewSeconds: widget.store.echoPreviewSeconds(0),
              level: activeTierOverride ?? skill.tier,
            ),
          ],
        );
    newRound();
  }

  void newRound() {
    timer?.cancel();
    player = match.current;
    playedRound = match.round;
    final seed = widget.seed == null
        ? Random().nextInt(1 << 30)
        : widget.seed! + match.turn;
    puzzle = EchoGridPuzzle.generate(
      tier: widget.tutorial ? 1 : activeTierOverride ?? player.level,
      seed: seed,
    );
    roundId = '${DateTime.now().microsecondsSinceEpoch}-$seed';
    selected.clear();
    result = null;
    score = xpAwarded = 0;
    committing = false;
    phase = match.players.length > 1 ? _Phase.ready : _Phase.preview;
    if (phase == _Phase.preview) startPreview();
    setState(() {});
  }

  void startPreview() {
    timer?.cancel();
    setState(() {
      remaining = player.previewSeconds;
      phase = _Phase.preview;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) {
        t.cancel();
        setState(() {
          phase = _Phase.recall;
          clock.reset();
          clock.start();
        });
        if (player.computer) {
          timer = Timer(const Duration(milliseconds: 1400), computerTurn);
        }
      }
    });
  }

  void computerTurn() {
    if (!mounted || phase != _Phase.recall) return;
    final rng = Random(puzzle.seed ^ 0x5a17);
    final chance = (0.92 - (player.level - 1) * .025).clamp(.45, .92);
    final wrong = List.generate(puzzle.config.cells, (i) => i)
      ..removeWhere(puzzle.targets.contains)
      ..shuffle(rng);
    for (final target in puzzle.targets) {
      selected.add(
        rng.nextDouble() < chance || wrong.isEmpty
            ? target
            : wrong.removeLast(),
      );
    }
    submit();
  }

  void toggle(int i) {
    if (phase != _Phase.recall || player.computer || committing) return;
    setState(() {
      if (!selected.remove(i) && selected.length < puzzle.config.targets) {
        selected.add(i);
      }
    });
  }

  Future<void> submit() async {
    if (phase != _Phase.recall ||
        committing ||
        selected.length != puzzle.config.targets) {
      return;
    }
    setState(() => committing = true);
    clock.stop();
    final r = puzzle.evaluate(selected);
    final s = gameScore(
      accuracy: r.accuracy,
      timed: !widget.store.untimedFor('visual_memory'),
      hints: 0,
      targetMs: 8000 + puzzle.config.targets * 1500,
      actualMs: clock.elapsedMilliseconds,
    );
    final xp = xpForScore(
      s,
      firstCompletion: widget.store.completedRounds == 0 || r.perfect,
    );
    if (match.players.length == 1) {
      final updated = SkillState.fromJson(skill.toJson());
      if (activeTierOverride == null) {
        updated.record(RoundRecord(accuracy: r.accuracy, success: r.perfect));
      }
      try {
        await widget.store.commitRound(
          roundId: roundId,
          score: s,
          xp: xp,
          skill: updated,
        );
        skill = updated;
      } catch (_) {
        if (!mounted) return;
        setState(() => committing = false);
        clock.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please submit again.')),
        );
        return;
      }
    }
    match.record(score: s, perfect: r.perfect);
    if (!mounted) return;
    setState(() {
      result = r;
      score = s;
      xpAwarded = match.players.length == 1 ? xp : 0;
      phase = _Phase.result;
      committing = false;
    });
  }

  Future<void> openSettings() async {
    if (committing) return;
    timer?.cancel();
    clock.stop();
    final previousPhase = phase;
    final action = await Navigator.of(context).push<GameSettingsAction>(
      MaterialPageRoute(
        builder: (_) =>
            GameSettingsScreen(kind: GameKind.echoGrid, store: widget.store),
      ),
    );
    if (!mounted) return;
    if (action != null) {
      activeTierOverride = widget.store.practiceTierFor('visual_memory');
    }
    if (action == GameSettingsAction.matchSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EchoSetupScreen(
            store: widget.store,
            tierOverride: activeTierOverride,
          ),
        ),
      );
      return;
    }
    if (match.players.length == 1) {
      player.previewSeconds = widget.store.echoPreviewSeconds(0);
    }
    if (previousPhase == _Phase.result || previousPhase == _Phase.finished) {
      setState(() {});
    } else {
      newRound();
    }
  }

  void advance() {
    if (match.finished) {
      setState(() => phase = _Phase.finished);
    } else {
      newRound();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool get sharedBoard => match.players.length > 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.tutorial ? 'First Gate' : 'Echo Grid'),
      toolbarHeight: 48,
      backgroundColor: Colors.transparent,
      actions: [
        if (!widget.tutorial)
          IconButton(
            key: const Key('game-settings'),
            tooltip: 'Settings',
            onPressed: committing ? null : openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sharedBoard)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      phase == _Phase.finished
                          ? 'FINAL STANDINGS'
                          : 'ROUND $playedRound / ${match.roundLimit ?? "∞"}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: NovaColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  scoreboard(),
                const SizedBox(height: 12),
                if (phase == _Phase.finished)
                  finalPanel()
                else ...[
                  if (sharedBoard) ...[
                    seatRow(top: true),
                    const SizedBox(height: 10),
                  ],
                  if (phase == _Phase.ready)
                    boardSurface(readyPanel())
                  else
                    ...turnBoard(),
                  if (sharedBoard) ...[
                    const SizedBox(height: 10),
                    seatRow(top: false),
                  ],
                  const SizedBox(height: 12),
                  if (phase == _Phase.recall)
                    if (player.computer)
                      const Center(child: Text('Computer is recalling…'))
                    else
                      FilledButton(
                        onPressed:
                            !committing &&
                                selected.length == puzzle.config.targets
                            ? submit
                            : null,
                        child: Text(
                          'Submit (${selected.length}/${puzzle.config.targets})',
                        ),
                      ),
                  if (phase == _Phase.result) resultPanel(),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  double boardSide(double width) => min(
    width,
    max(196.0, MediaQuery.sizeOf(context).height - (sharedBoard ? 500 : 370)),
  );

  Widget boardSurface(Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      final side = boardSide(constraints.maxWidth);
      return Center(
        child: SizedBox(
          key: const Key('echo-board'),
          width: side,
          height: side,
          child: child,
        ),
      );
    },
  );

  List<Widget> turnBoard() => [
    Text(
      instruction(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: sharedBoard ? 16 : 19,
        color: NovaColors.textSecondary,
      ),
    ),
    const SizedBox(height: 6),
    Text(
      phase == _Phase.preview
          ? 'Memorize · ${remaining}s remaining'
          : '${puzzle.config.size} × ${puzzle.config.size} · ${puzzle.config.targets} tiles',
      textAlign: TextAlign.center,
      style: const TextStyle(color: NovaColors.gold, fontSize: 13),
    ),
    const SizedBox(height: 10),
    if (phase == _Phase.preview) ...[
      LinearProgressIndicator(
        value: remaining / player.previewSeconds,
        color: sharedBoard
            ? seatColor(match.players.indexOf(player))
            : NovaColors.gold,
      ),
      const SizedBox(height: 10),
    ],
    boardSurface(
      GridView.count(
        crossAxisCount: puzzle.config.size,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (var i = 0; i < puzzle.config.cells; i++) cell(i)],
      ),
    ),
  ];

  Color seatColor(int index) => const [
    Color(0xFFFF8E91),
    Color(0xFF83B6FF),
    NovaColors.gold,
    NovaColors.emerald,
  ][index];

  Widget seatRow({required bool top}) {
    // Seat 1 stays nearest the device owner. Other seats keep their positions
    // throughout the match, including handoffs and result reveals.
    if (match.players.length == 2) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: playerSeat(top ? 1 : 0),
        ),
      );
    }
    final left = top ? 1 : 0;
    final right = top
        ? 2
        : match.players.length == 4
        ? 3
        : null;
    return Row(
      children: [
        Expanded(child: playerSeat(left)),
        const SizedBox(width: 12),
        Expanded(child: right == null ? const SizedBox() : playerSeat(right)),
      ],
    );
  }

  Widget playerSeat(int index) {
    final seat = match.players[index];
    final active = identical(seat, player) && phase != _Phase.finished;
    final color = seatColor(index);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${seat.name}, level ${seat.level}, ${seat.points} points${active ? ", current turn" : ""}',
      child: AnimatedContainer(
        key: Key('player-seat-$index'),
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .13) : NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withValues(alpha: .18),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: color.withValues(alpha: .16),
                  child: seat.computer
                      ? Icon(Icons.smart_toy_rounded, size: 12, color: color)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Tooltip(
                    message: seat.name,
                    child: Text(
                      seat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (active)
                  Icon(Icons.play_arrow_rounded, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${seat.points} pts',
                    key: Key('points-$index'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Lv ${seat.level}',
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget scoreboard() => Column(
    children: [
      GameScoreBar(store: widget.store, skillKey: 'visual_memory'),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Round $playedRound${match.roundLimit == null ? " · Continuous" : " / ${match.roundLimit}"}',
            style: const TextStyle(
              color: NovaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            'Lv ${player.level}',
            style: const TextStyle(color: NovaColors.emerald, fontSize: 12),
          ),
        ],
      ),
    ],
  );

  Widget readyPanel() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            player.computer
                ? Icons.smart_toy_rounded
                : Icons.screen_rotation_rounded,
            size: 30,
            color: seatColor(match.players.indexOf(player)),
          ),
          const SizedBox(height: 8),
          Text(
            '${player.name}’s turn',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Level ${player.level} · ${player.previewSeconds}s to remember',
            style: const TextStyle(
              fontSize: 12,
              color: NovaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Other players, look away.',
            style: TextStyle(fontSize: 12, color: NovaColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: startPreview,
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 44),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(player.computer ? 'Run computer turn' : 'I’m ready'),
          ),
        ],
      ),
    ),
  );

  Widget finalPanel() => Column(
    children: [
      const Icon(Icons.emoji_events_rounded, size: 64, color: NovaColors.gold),
      const SizedBox(height: 12),
      Text(
        match.players.length == 1
            ? 'Great run, ${match.winners.first.name}!'
            : '${match.winners.map((p) => p.name).join(" & ")} ${match.winners.length == 1 ? "wins!" : "tie!"}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      for (final p in match.standings)
        ListTile(
          title: Text(p.name),
          subtitle: Text(
            'Highest completed level ${p.reachedLevel} · ${p.rounds} rounds',
          ),
          trailing: Text(
            '${p.points} pts',
            style: const TextStyle(
              color: NovaColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to setup'),
      ),
    ],
  );

  String instruction() => switch (phase) {
    _Phase.ready => 'Ready?',
    _Phase.finished => 'Match complete',
    _Phase.preview =>
      widget.tutorial
          ? 'Watch the glowing tiles…'
          : 'Remember the glowing tiles',
    _Phase.recall =>
      widget.tutorial
          ? 'Now tap the tiles that glowed'
          : 'Tap the tiles that glowed',
    _Phase.result =>
      result!.perfect
          ? 'The gate opens!'
          : 'Good try — ${result!.hits}/${puzzle.config.targets} correct',
  };

  Widget cell(int i) {
    final target = puzzle.targets.contains(i), chosen = selected.contains(i);
    Color color = NovaColors.surface;
    IconData? icon;
    String label = 'Tile ${i + 1}';
    if (phase == _Phase.preview && target) {
      color = NovaColors.gold;
      icon = Icons.star;
      label += ', glowing';
    } else if (phase == _Phase.recall && chosen) {
      color = NovaColors.blue;
      icon = Icons.check;
      label += ', selected';
    } else if (phase == _Phase.result) {
      if (target && chosen) {
        color = NovaColors.emerald;
        icon = Icons.check;
      } else if (target) {
        color = NovaColors.gold;
        icon = Icons.star;
      } else if (chosen) {
        color = NovaColors.danger;
        icon = Icons.close;
      }
    }
    return Semantics(
      key: Key('tile-$i'),
      button: true,
      label: label,
      selected: chosen,
      enabled: phase == _Phase.recall && !player.computer,
      child: InkWell(
        onTap: phase == _Phase.recall && !player.computer
            ? () => toggle(i)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.blue.withValues(alpha: .25)),
          ),
          child: icon == null
              ? null
              : Icon(icon, color: NovaColors.background, size: 26),
        ),
      ),
    );
  }

  Widget resultPanel() => Column(
    children: [
      Text(
        'Score $score${xpAwarded > 0 ? "  •  +$xpAwarded XP" : ""}',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: NovaColors.gold,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          FilledButton(
            onPressed: widget.tutorial
                ? () => Navigator.of(context).pop(true)
                : advance,
            child: Text(
              widget.tutorial
                  ? 'Continue'
                  : match.finished
                  ? 'View results'
                  : match.players.length > 1
                  ? 'Next player'
                  : 'Next round',
            ),
          ),
          if (!widget.tutorial && match.roundLimit == null && match.canEnd)
            OutlinedButton(
              onPressed: () {
                match.end();
                setState(() => phase = _Phase.finished);
              },
              child: const Text('Finish run'),
            ),
        ],
      ),
    ],
  );
}
