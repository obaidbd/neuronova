import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../core/progress_store.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/scoring.dart';
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
  });
  final GameKind kind;
  final ProgressStore store;
  final int? tierOverride;

  @override
  State<RoundShell> createState() => _RoundShellState();
}

class _RoundShellState extends State<RoundShell> {
  late SkillState skill;
  late int tier, seed;
  late String roundId;
  late Stopwatch clock;
  RoundOutcome? outcome;
  int score = 0, xp = 0;

  @override
  void initState() {
    super.initState();
    skill = widget.store.skillFor(widget.kind.skillKey);
    _next();
  }

  void _next() {
    tier = widget.tierOverride ?? skill.tier;
    seed = Random().nextInt(1 << 30);
    roundId = '${DateTime.now().microsecondsSinceEpoch}-$seed';
    clock = Stopwatch()..start();
    setState(() => outcome = null);
  }

  Future<void> _finish(RoundOutcome o) async {
    if (outcome != null) return; // ignore duplicate completion events
    clock.stop();
    final untimed = widget.store.untimedFor(widget.kind.skillKey);
    final s = gameScore(
      accuracy: o.accuracy,
      timed: !untimed,
      hints: 0,
      targetMs: widget.kind.targetMs(tier),
      actualMs: clock.elapsedMilliseconds,
    );
    final x = xpForScore(s, firstCompletion: o.perfect);
    // Manual tier override is test mode: it never changes the real skill.
    if (widget.tierOverride == null) {
      skill.record(RoundRecord(accuracy: o.accuracy, success: o.perfect));
    }
    await widget.store.commitRound(
      roundId: roundId,
      score: s,
      xp: x,
      skill: skill,
      skillKey: widget.kind.skillKey,
    );
    if (!mounted) return;
    setState(() {
      outcome = o;
      score = s;
      xp = x;
    });
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
      appBar: AppBar(
        title: Text(widget.kind.title),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Tier $tier${widget.tierOverride != null ? ' (test)' : ''}',
                key: const Key('tier-label'),
                style: const TextStyle(color: NovaColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: outcome == null ? _game() : _result(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result() {
    final o = outcome!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          o.perfect ? Icons.lock_open : Icons.lock_outline,
          size: 64,
          color: o.perfect ? NovaColors.emerald : NovaColors.gold,
        ),
        const SizedBox(height: 12),
        Text(
          o.perfect ? 'Gate opened!' : 'Good try!',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        if (o.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              o.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Score $score  •  +$xp XP',
          key: const Key('result-score'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: NovaColors.gold,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(onPressed: _next, child: const Text('Next round')),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Home'),
            ),
          ],
        ),
      ],
    );
  }
}
