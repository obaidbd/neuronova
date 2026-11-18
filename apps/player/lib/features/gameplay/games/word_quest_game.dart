import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/word_quest.dart';
import '../round_shell.dart';
import '../answer_cards.dart';
import '../../../core/game_kind.dart';
import '../../catalog/game_presentation.dart';

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
  int? picked;

  void _pick(int i) {
    if (done) return;
    done = true;
    setState(() => picked = i);
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
        const SizedBox(height: 12),
        Text(
          switch (p.lang) {
            'bn' => 'বাংলা',
            'ar' => 'العربية',
            _ => 'ENGLISH',
          },
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: GameKind.wordQuest.accent,
          ),
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
        AnswerCards(
          count: p.options.length,
          accent: GameKind.wordQuest.accent,
          onPick: _pick,
          pickedIndex: picked,
          correctIndex: p.options.indexWhere((it) => it.id == p.item.id),
          labelBuilder: (i) => 'Picture option ${i + 1}',
          itemBuilder: (i) =>
              Text(p.options[i].emoji, style: const TextStyle(fontSize: 44)),
        ),
      ],
    );
  }
}
