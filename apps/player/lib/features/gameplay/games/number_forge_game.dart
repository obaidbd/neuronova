import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/number_forge.dart';
import '../round_shell.dart';
import '../answer_cards.dart';
import '../../../core/game_kind.dart';
import '../../catalog/game_presentation.dart';

class NumberForgeGame extends StatefulWidget {
  const NumberForgeGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<NumberForgeGame> createState() => _S();
}

class _S extends State<NumberForgeGame> {
  late final NumberForgePuzzle p = NumberForgePuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  bool done = false;

  void _pick(int i) {
    if (done) return;
    done = true;
    final ok = p.isCorrect(i);
    final fixed = p.options.firstWhere(p.fits);
    widget.onFinished(
      RoundOutcome(
        accuracy: ok ? 1 : 0,
        perfect: ok,
        message: ok ? '' : 'The answer was $fixed.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Repair the bridge',
          style: TextStyle(fontSize: 20, color: NovaColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: p.display.replaceAll('?', 'blank'),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              p.display,
              key: const Key('equation'),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: NovaColors.gold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnswerCards(
          count: p.options.length,
          accent: GameKind.numberForge.accent,
          onPick: _pick,
          itemHeight: 72,
          labelBuilder: (i) => p.options[i],
          itemBuilder: (i) => Text(
            p.options[i],
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: GameKind.numberForge.accent,
            ),
          ),
        ),
      ],
    );
  }
}
