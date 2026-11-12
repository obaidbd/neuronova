import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';

class GameScoreBar extends StatelessWidget {
  const GameScoreBar({super.key, required this.store, required this.skillKey});
  final ProgressStore store;
  final String skillKey;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('game-score-bar'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: NovaColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 6,
      children: [
        Text(
          'Score ${store.pointsFor(skillKey)}',
          key: const Key('game-total-score'),
          style: const TextStyle(
            color: NovaColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Best ${store.bestFor(skillKey)}',
          style: const TextStyle(color: NovaColors.textSecondary),
        ),
        Text(
          '${store.xpFor(skillKey)} XP',
          style: const TextStyle(color: NovaColors.emerald),
        ),
      ],
    ),
  );
}
