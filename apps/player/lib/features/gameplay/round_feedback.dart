import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';

/// Small pill shown above the puzzle right after an answer. It replaces the
/// old full-screen result card: points, round and level update in the header
/// while this says only whether the answer was right or wrong.
class RoundFeedback extends StatelessWidget {
  const RoundFeedback({
    super.key,
    required this.kind,
    required this.perfect,
    required this.score,
    this.message = '',
    this.checkpointLevel,
    this.streak = 0,
    this.onTap,
  });
  final GameKind kind;
  final bool perfect;
  final int score;
  final String message;

  /// Set when this round reached a five-level checkpoint.
  final int? checkpointLevel;
  final VoidCallback? onTap;

  /// Correct answers in a row (shown from two). A miss only resets it.
  final int streak;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final milestone = perfect && checkpointLevel != null;
    final color = milestone
        ? NovaColors.gold
        : perfect
        ? kind.accent
        : NovaColors.danger;
    final icon = milestone
        ? Icons.emoji_events_rounded
        : perfect
        ? Icons.check_circle_rounded
        : Icons.close_rounded;
    final label = milestone
        ? 'Checkpoint · Lv$checkpointLevel'
        : perfect
        ? 'Correct'
        : 'Not quite';
    final spoken = [
      label,
      if (score > 0) '$score points',
      if (perfect && streak >= 2) '$streak in a row',
      if (message.isNotEmpty) message,
    ].join('. ');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -8),
          child: child,
        ),
      ),
      child: Semantics(
        liveRegion: true,
        label: spoken,
        excludeSemantics: true,
        child: Center(
          child: Material(
            color: color.withValues(alpha: .12),
            shape: StadiumBorder(
              side: BorderSide(color: color.withValues(alpha: .38)),
            ),
            child: InkWell(
              key: const Key('round-feedback'),
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 7),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        if (perfect && streak >= 2) ...[
                          const SizedBox(width: 9),
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: NovaColors.gold,
                          ),
                          Text(
                            '$streak',
                            key: const Key('streak-count'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: NovaColors.gold,
                            ),
                          ),
                        ],
                        if (score > 0) ...[
                          const SizedBox(width: 9),
                          Text(
                            '+$score',
                            key: const Key('result-score'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: NovaColors.gold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: NovaColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
