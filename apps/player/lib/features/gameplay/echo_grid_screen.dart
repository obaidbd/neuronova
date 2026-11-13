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
import 'game_header.dart';
import 'match_board.dart';
import '../../game/rules/difficulty.dart';

enum _Phase { waiting, preview, recall, result, finished }

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
  int remaining = 4, playedRound = 1, score = 0;
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
          tutorial: widget.tutorial,
          players: [
            EchoPlayer(
              'Player 1',
              previewSeconds: widget.store.echoPreviewSeconds(0),
              level: widget.store.levelFor('visual_memory'),
            ),
          ],
        );
    newRound();
  }

  void newRound() {
    timer?.cancel();
    player = match.current;
    playedRound = match.players.length == 1 && !widget.tutorial
        ? widget.store.roundsFor('visual_memory') + 1
        : match.round;
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
    score = 0;
    committing = false;
    if (sharedBoard) {
      phase = _Phase.waiting;
    } else {
      startPreview();
    }
    setState(() {});
  }

  void startPreview() {
    timer?.cancel();
    setState(() {
      remaining = player.previewSeconds;
      phase = _Phase.preview;
    });
    if (remaining == 0) {
      if (player.computer) {
        timer = Timer(const Duration(milliseconds: 1400), beginRecall);
      }
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) beginRecall();
    });
  }

  void beginRecall() {
    if (phase != _Phase.preview) return;
    timer?.cancel();
    setState(() {
      phase = _Phase.recall;
      clock.reset();
      clock.start();
    });
    if (player.computer) {
      timer = Timer(const Duration(milliseconds: 1400), computerTurn);
    }
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
    if (match.players.length == 1) {
      final updated = SkillState.fromJson(skill.toJson());
      if (activeTierOverride == null) {
        updated.record(RoundRecord(accuracy: r.accuracy, success: r.perfect));
      }
      try {
        await widget.store.commitRound(
          roundId: roundId,
          score: s,
          xp: 0,
          levelUp: r.perfect,
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
    appBar: GameHeader(
      kind: GameKind.echoGrid,
      title: widget.tutorial ? 'First Gate' : null,
      points: sharedBoard
          ? player.points
          : widget.store.pointsFor('visual_memory'),
      round: playedRound,
      roundLimit: sharedBoard ? match.roundLimit : null,
      level: player.level,
      difficulty: difficultyName(activeTierOverride),
      showSettings: !widget.tutorial,
      onSettings: committing ? null : openSettings,
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: phase == _Phase.finished
                ? MatchResults(match: match)
                : sharedBoard
                ? MatchBoard(
                    match: match,
                    player: player,
                    child: _turnContent(),
                  )
                : _turnContent(),
          ),
        ),
      ),
    ),
  );

  Widget _turnContent() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phase == _Phase.waiting) ...[
          boardSurface(
            Center(
              child: Text(
                '${player.name}’s turn',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  color: NovaColors.textSecondary,
                ),
              ),
            ),
          ),
          TurnActionButton(label: 'Start', onPressed: startPreview),
        ] else
          ...turnBoard(),
        if (phase == _Phase.recall)
          if (player.computer)
            const Center(child: Text('Computer is recalling…'))
          else
            TurnActionButton(
              onPressed: !committing && selected.length == puzzle.config.targets
                  ? submit
                  : null,
              label: 'Submit (${selected.length}/${puzzle.config.targets})',
            ),
        if (phase == _Phase.result) resultPanel(),
      ],
    ),
  );

  double boardSide(double width) => min(
    width,
    max(196.0, MediaQuery.sizeOf(context).height - (sharedBoard ? 480 : 340)),
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
          ? (player.previewSeconds == 0
                ? 'Take your time · Press Start when ready'
                : 'Memorize · ${remaining}s remaining')
          : '${puzzle.config.size} × ${puzzle.config.size} · ${puzzle.config.targets} tiles',
      textAlign: TextAlign.center,
      style: const TextStyle(color: NovaColors.gold, fontSize: 13),
    ),
    const SizedBox(height: 10),
    if (phase == _Phase.preview && player.previewSeconds > 0) ...[
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
    if (phase == _Phase.preview && player.previewSeconds == 0) ...[
      const SizedBox(height: 12),
      TurnActionButton(
        key: const Key('preview-start'),
        onPressed: player.computer ? null : beginRecall,
        label: 'Start',
      ),
    ],
  ];

  Color seatColor(int index) => const [
    Color(0xFFFF8E91),
    Color(0xFF83B6FF),
    NovaColors.gold,
    NovaColors.emerald,
  ][index];

  String instruction() => switch (phase) {
    _Phase.waiting => 'Start your turn',
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
        '$score',
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
          TurnActionButton(
            onPressed: widget.tutorial
                ? () => Navigator.of(context).pop(true)
                : advance,
            label: widget.tutorial
                ? 'Continue'
                : match.finished
                ? 'View results'
                : match.players.length > 1
                ? 'Next player'
                : 'Next round',
          ),
        ],
      ),
    ],
  );
}
