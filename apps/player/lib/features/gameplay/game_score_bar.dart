import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';

class GameScoreBar extends StatelessWidget {
  const GameScoreBar({super.key, required this.store, required this.skillKey});
  final ProgressStore store;
  final String skillKey;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${store.pointsFor(skillKey)} points',
    excludeSemantics: true,
    child: Container(
      key: const Key('game-score-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${store.pointsFor(skillKey)}',
        key: const Key('game-total-score'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: NovaColors.gold,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
