import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/word_quest.dart';
import '../round_shell.dart';

class WordQuestGame extends StatefulWidget {
  const WordQuestGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<WordQuestGame> createState() => _S();
}

class _S extends State<WordQuestGame> {
  late final WordPuzzle p = WordPuzzle.generate(
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
        message: '${p.prompt} = ${p.item.emoji} ${p.item.en}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Open the door: pick the matching picture',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: NovaColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Directionality(
          textDirection: p.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            p.prompt,
            key: const Key('prompt'),
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: NovaColors.gold,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < p.options.length; i++)
              Semantics(
                button: true,
                label: 'Picture option ${i + 1}',
                child: InkWell(
                  key: Key('option-$i'),
                  onTap: () => _pick(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NovaColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      p.options[i].emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
