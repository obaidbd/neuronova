import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';
import '../catalog/game_settings_screen.dart';
import 'game_header.dart';
import 'round_feedback.dart';
import 'match_board.dart';
import 'echo_setup_screen.dart';
import '../../game/rules/echo_match.dart';
import '../../game/rules/pattern_portal.dart';
import '../../game/rules/number_forge.dart';
import '../../game/rules/word_quest.dart';
import '../../game/rules/focus_dash.dart';
import '../../game/rules/path_recall.dart';
import '../../core/progress_store.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/scoring.dart';
import '../../game/rules/difficulty.dart';
import 'games/focus_dash_game.dart';
import 'games/number_forge_game.dart';
import 'games/path_recall_game.dart';
import 'games/pattern_portal_game.dart';
import 'games/word_quest_game.dart';

class RoundOutcome {
  const RoundOutcome({
    required this.accuracy,
    required this.perfect,
    this.message = '',
  });
  final double accuracy;
  final bool perfect;
  final String message;
}

typedef OutcomeCallback = void Function(RoundOutcome outcome);

/// Runs rounds of one minigame: generates a seed, hosts the game widget,
/// scores the outcome, commits it once, and shows the result.
class RoundShell extends StatefulWidget {
  const RoundShell({
    super.key,
    required this.kind,
    required this.store,
    this.tierOverride,
    this.match,
  });
  final GameKind kind;
  final ProgressStore store;
  final int? tierOverride;
  final EchoMatch? match;

  @override
  State<RoundShell> createState() => _RoundShellState();
}

class _RoundShellState extends State<RoundShell> {
  late SkillState skill;
  late int tier, seed;
  late String roundId;
  late Stopwatch clock;
  RoundOutcome? outcome;
  int score = 0;
  late int playerLevel;
  int roundNumber = 1;
  int? activeTierOverride;
  bool settingsOpen = false;
  bool finishing = false;
  bool waiting = false, finished = false;
  EchoPlayer? player;
  Timer? computerTimer;
  Timer? handoffTimer;
  Timer? soloTimer;
  bool get sharedBoard => (widget.match?.players.length ?? 1) > 1;

  @override
  void dispose() {
    soloTimer?.cancel();
    handoffTimer?.cancel();
    computerTimer?.cancel();
    super.dispose();
  }

  void _startTurn() {
    if (!waiting) return;
    setState(() => waiting = false);
    if (widget.kind != GameKind.pathRecall || player?.computer == true) {
      clock.start();
    }
    if (player?.computer == true) {
      final preview = widget.kind == GameKind.pathRecall
          ? max(1, player!.previewSeconds) * 1000
          : 0;
      computerTimer = Timer(Duration(milliseconds: preview + 1400), () {
        if (mounted && !settingsOpen) _finish(_computerOutcome());
      });
    }
  }

  RoundOutcome _computerOutcome() {
    final rng = Random(seed ^ 0x5a17);
    final succeeds =
        rng.nextDouble() < (0.92 - (playerLevel - 1) * .025).clamp(.45, .92);
    bool correct;
    switch (widget.kind) {
      case GameKind.patternPortal:
        final p = PatternPuzzle.generate(tier: tier, seed: seed);
        correct = p.isCorrect(
          succeeds ? p.answerIndex : (p.answerIndex + 1) % p.options.length,
        );
      case GameKind.numberForge:
        final p = NumberForgePuzzle.generate(tier: tier, seed: seed);
        final answer = p.options.indexWhere(p.fits);
        correct = p.isCorrect(
          succeeds ? answer : (answer + 1) % p.options.length,
        );
      case GameKind.wordQuest:
        final p = WordPuzzle.generate(tier: tier, seed: seed);
        final answer = p.options.indexWhere((it) => it.id == p.item.id);
        correct = p.isCorrect(
          succeeds ? answer : (answer + 1) % p.options.length,
        );
      case GameKind.focusDash:
        final p = FocusPuzzle.generate(tier: tier, seed: seed);
        final result = p.evaluate(succeeds ? p.targets : <int>{});
        return RoundOutcome(accuracy: result.accuracy, perfect: result.perfect);
      case GameKind.pathRecall:
        final p = PathPuzzle.generate(tier: tier, seed: seed);
        final result = p.evaluate(succeeds ? p.expected.sublist(1) : <int>[]);
        return RoundOutcome(accuracy: result.accuracy, perfect: result.perfect);
      case GameKind.echoGrid:
        throw StateError('Echo Grid has its own screen');
    }
    return RoundOutcome(accuracy: correct ? 1 : 0, perfect: correct);
  }

  @override
  void initState() {
    super.initState();
    skill = widget.store.skillFor(widget.kind.skillKey);
    activeTierOverride =
        widget.tierOverride ??
        widget.store.practiceTierFor(widget.kind.skillKey);
    _next();
  }

  void _next() {
    soloTimer?.cancel();
    handoffTimer?.cancel();
    computerTimer?.cancel();
    if (sharedBoard && widget.match!.finished) {
      setState(() => finished = true);
      return;
    }
    player = widget.match?.current;
    tier = activeTierOverride ?? (sharedBoard ? player!.level : skill.tier);
    playerLevel = sharedBoard
        ? player!.level
        : widget.store.levelFor(widget.kind.skillKey);
    settingsOpen = false;
    seed = Random().nextInt(1 << 30);
    roundId = '${DateTime.now().microsecondsSinceEpoch}-$seed';
    roundNumber = sharedBoard
        ? widget.match!.round
        : widget.store.roundsFor(widget.kind.skillKey) + 1;
    clock = Stopwatch();
    waiting = sharedBoard;
    if (!waiting && widget.kind != GameKind.pathRecall) clock.start();
    setState(() => outcome = null);
  }

  Future<void> _finish(RoundOutcome o) async {
    if (outcome != null || finishing || waiting || finished || settingsOpen) {
      return;
    }
    setState(() => finishing = true); // ignore duplicate completion events
    clock.stop();
    final untimed = widget.store.untimedFor(widget.kind.skillKey);
    final s = gameScore(
      accuracy: o.accuracy,
      timed: !untimed,
      hints: 0,
      targetMs: widget.kind.targetMs(tier),
      actualMs: clock.elapsedMilliseconds,
    );
    if (sharedBoard) {
      widget.match!.record(score: s, perfect: o.perfect);
    } else {
      // Manual tier override is test mode: it never changes the real skill.
      if (activeTierOverride == null) {
        skill.record(RoundRecord(accuracy: o.accuracy, success: o.perfect));
      }
      await widget.store.commitRound(
        roundId: roundId,
        score: s,
        xp: 0,
        levelUp: o.perfect,
        skill: skill,
        skillKey: widget.kind.skillKey,
      );
    }
    if (!mounted) return;
    setState(() {
      finishing = false;
      outcome = o;
      score = s;
      playerLevel = sharedBoard
          ? player!.level
          : widget.store.levelFor(widget.kind.skillKey);
    });
    if (sharedBoard) {
      _scheduleHandoff();
    } else {
      o.perfect
          ? HapticFeedback.lightImpact()
          : HapticFeedback.selectionClick();
      _scheduleSoloAdvance();
    }
  }

  /// Solo rounds flow straight into the next one; the header already shows the
  /// new points and level. Relaxed (untimed) mode waits for a tap instead.
  void _scheduleSoloAdvance() {
    soloTimer?.cancel();
    final o = outcome;
    if (sharedBoard ||
        o == null ||
        settingsOpen ||
        widget.store.untimedFor(widget.kind.skillKey)) {
      return;
    }
    final ms = o.perfect ? 1000 : (o.message.isNotEmpty ? 2200 : 1500);
    soloTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted && !settingsOpen && outcome != null) _next();
    });
  }

  void _scheduleHandoff() {
    handoffTimer?.cancel();
    if (!sharedBoard ||
        !widget.store.autoHandoffFor(widget.kind.skillKey) ||
        outcome == null ||
        finished ||
        settingsOpen) {
      return;
    }
    handoffTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !settingsOpen && outcome != null) _next();
    });
  }

  Future<void> openSettings() async {
    if (finishing) return;
    soloTimer?.cancel();
    handoffTimer?.cancel();
    clock.stop();
    computerTimer?.cancel();
    setState(() => settingsOpen = true);
    final action = await Navigator.of(context).push<GameSettingsAction>(
      MaterialPageRoute(
        builder: (_) =>
            GameSettingsScreen(kind: widget.kind, store: widget.store),
      ),
    );
    if (!mounted) return;
    if (action != null) {
      activeTierOverride = widget.store.practiceTierFor(widget.kind.skillKey);
    }
    if (action == GameSettingsAction.matchSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EchoSetupScreen(
            store: widget.store,
            kind: widget.kind,
            tierOverride: activeTierOverride,
          ),
        ),
      );
      return;
    }
    if (outcome == null || !sharedBoard) {
      _next();
    } else {
      setState(() => settingsOpen = false);
      _scheduleHandoff();
    }
  }

  Widget _game() {
    final key = ValueKey(roundId);
    switch (widget.kind) {
      case GameKind.patternPortal:
        return PatternPortalGame(
          key: key,
          tier: tier,
          seed: seed,
          onFinished: _finish,
        );
      case GameKind.focusDash:
        return FocusDashGame(
          key: key,
          tier: tier,
          seed: seed,
          onFinished: _finish,
        );
      case GameKind.numberForge:
        return NumberForgeGame(
          key: key,
          tier: tier,
          seed: seed,
          onFinished: _finish,
        );
      case GameKind.wordQuest:
        return WordQuestGame(
          key: key,
          tier: tier,
          seed: seed,
          onFinished: _finish,
        );
      case GameKind.pathRecall:
        return PathRecallGame(
          previewSeconds: sharedBoard
              ? (player!.computer
                    ? max(1, player!.previewSeconds)
                    : player!.previewSeconds)
              : widget.store.previewSecondsFor(widget.kind.skillKey),
          onRecallStarted: () {
            clock.reset();
            clock.start();
          },
          key: key,
          tier: tier,
          seed: seed,
          onFinished: _finish,
        );
      case GameKind.echoGrid:
        throw StateError('Echo Grid has its own screen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameHeader(
        kind: widget.kind,
        points: sharedBoard
            ? player!.points
            : widget.store.pointsFor(widget.kind.skillKey),
        round: roundNumber,
        roundLimit: sharedBoard ? widget.match!.roundLimit : null,
        level: playerLevel,
        difficulty: difficultyName(activeTierOverride),
        animate: !sharedBoard,
        onSettings: finishing ? null : openSettings,
      ),
      bottomNavigationBar:
          !sharedBoard &&
              outcome != null &&
              widget.store.untimedFor(widget.kind.skillKey)
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.kind.accent,
                  minimumSize: const Size(0, 54),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Next round'),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: finished
                  ? MatchResults(match: widget.match!)
                  : sharedBoard
                  ? MatchBoard(
                      match: widget.match!,
                      player: player!,
                      status: outcome == null ? null : 'Turn complete',
                      child: _turnContent(),
                    )
                  : _soloContent(),
            ),
          ),
        ),
      ),
    );
  }

  /// Solo layout: a fixed slot for the answer feedback above the puzzle, so
  /// the puzzle never jumps when the feedback appears.
  Widget _soloContent() {
    final o = outcome;
    final level = playerLevel;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: o == null || settingsOpen
              ? null
              : RoundFeedback(
                  key: ValueKey(roundId),
                  kind: widget.kind,
                  perfect: o.perfect,
                  score: score,
                  message: o.message,
                  checkpointLevel: o.perfect && level % 5 == 0 ? level : null,
                  onTap: _next,
                ),
        ),
        Expanded(child: _turnContent()),
      ],
    );
  }

  Widget _turnContent() {
    if (settingsOpen) return const SizedBox();
    if (waiting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${player!.name}’s turn',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              color: NovaColors.textSecondary,
            ),
          ),
          TurnActionButton(label: 'Start', onPressed: _startTurn),
        ],
      );
    }
    if (outcome != null && sharedBoard) return _result();
    final game = IgnorePointer(
      ignoring: player?.computer == true || outcome != null,
      child: _game(),
    );
    // Seats remain visible while tall puzzles can scroll between them.
    if (widget.kind == GameKind.pathRecall) return game;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: game,
        ),
      ),
    );
  }

  Widget _result() {
    final o = outcome!;
    final accent = o.perfect ? widget.kind.accent : NovaColors.gold;
    if (sharedBoard) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                o.perfect ? Icons.check_circle_rounded : Icons.refresh_rounded,
                size: 40,
                color: accent,
              ),
              const SizedBox(height: 8),
              Text(
                o.perfect ? 'Gate opened!' : 'Good try!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (o.message.isNotEmpty)
                Text(
                  o.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NovaColors.textSecondary,
                  ),
                ),
              Text(
                '$score',
                key: const Key('result-score'),
                style: TextStyle(
                  fontSize: 32,
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!widget.store.autoHandoffFor(widget.kind.skillKey))
                TurnActionButton(
                  label: widget.match!.finished
                      ? 'View results'
                      : 'Next player',
                  onPressed: _next,
                )
              else
                Text(
                  widget.match!.finished ? 'Match complete' : 'Next player…',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NovaColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }
}
