import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/pattern_portal.dart';
import '../round_shell.dart';
import '../answer_cards.dart';
import '../../../core/game_kind.dart';
import '../../catalog/game_presentation.dart';
import '../shapes.dart';

class PatternPortalGame extends StatefulWidget {
  const PatternPortalGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<PatternPortalGame> createState() => _S();
}

class _S extends State<PatternPortalGame> {
  late final PatternPuzzle p = PatternPuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  bool done = false;

  void _pick(int i) {
    if (done) return;
    done = true;
    final ok = p.isCorrect(i);
    widget.onFinished(
      RoundOutcome(
        accuracy: ok ? 1 : 0,
        perfect: ok,
        message: ok ? '' : 'The pattern repeats — look for the cycle.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Which item comes next?',
          style: TextStyle(fontSize: 20, color: NovaColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final it in p.visible) ShapeChip(it.shape, it.color),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: NovaColors.gold, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('?', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        AnswerCards(
          count: p.options.length,
          accent: GameKind.patternPortal.accent,
          onPick: _pick,
          itemBuilder: (i) =>
              ShapeChip(p.options[i].shape, p.options[i].color, size: 36),
          labelBuilder: (i) =>
              '${colorNames[p.options[i].color]} ${shapeNames[p.options[i].shape]}',
        ),
      ],
    );
  }
}
