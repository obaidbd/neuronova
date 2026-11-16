import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';

int nextCheckpoint(int level) => (level ~/ 5 + 1) * 5;

String roundTip(GameKind kind, int round) {
  final tips = switch (kind) {
    GameKind.echoGrid => [
      'Group nearby glowing tiles into small shapes.',
      'Remember a row at a time.',
      'Notice the empty spaces between the glowing tiles.',
    ],
    GameKind.patternPortal => [
      'Check shape and colour as separate patterns.',
      'Look for the part of the sequence that repeats.',
      'Compare the last cycle with the first one.',
    ],
    GameKind.focusDash => [
      'Scan one row at a time.',
      'Match both the shape and its colour.',
      'Check your selection before submitting.',
    ],
    GameKind.numberForge => [
      'Read the whole equation before choosing.',
      'Put your answer back into the equation to check it.',
      'Look carefully at the operation sign.',
    ],
    GameKind.wordQuest => [
      'Say the word to yourself, then find its picture.',
      'Notice the language shown above the word.',
      'Connect the word with an object you know.',
    ],
    GameKind.pathRecall => [
      'Remember each turn as well as each step.',
      'Break the route into short sections.',
      'Check the direction: some routes run backwards.',
    ],
  };
  return tips[round % tips.length];
}

/// Small, repeatable goals without another currency or a level cap.
class RoundJourney extends StatelessWidget {
  const RoundJourney({
    super.key,
    required this.kind,
    required this.level,
    required this.round,
    required this.perfect,
  });
  final GameKind kind;
  final int level, round;
  final bool perfect;

  @override
  Widget build(BuildContext context) {
    final checkpoint = nextCheckpoint(level);
    final milestone = perfect && level % 5 == 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: MediaQuery.disableAnimationsOf(context) ? 1 : .96,
        end: 1,
      ),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: Container(
        key: ValueKey('$level-$round-$perfect'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kind.accent.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kind.accent.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  milestone
                      ? Icons.emoji_events_rounded
                      : perfect
                      ? Icons.trending_up_rounded
                      : Icons.explore_rounded,
                  color: milestone ? NovaColors.gold : kind.accent,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    milestone
                        ? 'Checkpoint reached · Lv$level'
                        : perfect
                        ? 'Level up · Lv$level'
                        : 'Keep exploring · Lv$level',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Level $level. Next checkpoint level $checkpoint.',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: i < level % 5
                                ? kind.accent
                                : kind.accent.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Next checkpoint · Lv$checkpoint',
              style: const TextStyle(
                fontSize: 11,
                color: NovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              roundTip(kind, round),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: NovaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
