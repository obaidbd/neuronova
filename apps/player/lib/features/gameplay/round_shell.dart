import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';
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
        toolbarHeight: 52,
        title: Text(
          widget.kind.title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
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
    final accent = o.perfect ? widget.kind.accent : NovaColors.gold;
    final accuracy = (o.accuracy.clamp(0.0, 1.0) * 100).round();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.withValues(alpha: .10), NovaColors.surface],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: .22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: .12),
                      border: Border.all(color: accent.withValues(alpha: .25)),
                    ),
                    child: Icon(
                      o.perfect ? Icons.check_rounded : Icons.refresh_rounded,
                      size: 38,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    o.perfect ? 'Gate opened!' : 'Good try!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  if (o.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        o.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  Semantics(
                    label: 'Score $score out of 100',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Text(
                          '$score',
                          key: const Key('result-score'),
                          style: TextStyle(
                            color: accent,
                            fontSize: 68,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'POINTS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: NovaColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.background.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$accuracy%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Accuracy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NovaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: NovaColors.textSecondary.withValues(
                            alpha: .15,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '+$xp XP',
                                style: const TextStyle(
                                  color: NovaColors.gold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Earned',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NovaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: widget.kind.accent,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Next round'),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
