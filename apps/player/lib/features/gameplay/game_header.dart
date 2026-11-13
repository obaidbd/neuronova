import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';

/// A single compact header shared by every game. Full labels remain accessible.
class GameHeader extends StatelessWidget implements PreferredSizeWidget {
  const GameHeader({
    super.key,
    required this.kind,
    required this.points,
    required this.round,
    required this.level,
    required this.onSettings,
    this.roundLimit,
    this.difficulty = 'Auto',
    this.title,
    this.showSettings = true,
  });
  final GameKind kind;
  final int points, round, level;
  final int? roundLimit;
  final VoidCallback? onSettings;
  final String difficulty;
  final String? title;
  final bool showSettings;

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 54,
    leadingWidth: 44,
    titleSpacing: 4,
    backgroundColor: NovaColors.background,
    elevation: 0,
    title: Row(
      children: [
        Tooltip(
          message: title ?? kind.title,
          child: Icon(
            kind.icon,
            key: const Key('header-game-icon'),
            color: kind.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                key: const Key('game-score-bar'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Points',
                      child: Semantics(
                        label: '$points points',
                        excludeSemantics: true,
                        child: Text(
                          '$points',
                          key: const Key('game-total-score'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: NovaColors.gold,
                          ),
                        ),
                      ),
                    ),
                    separator(),
                    Tooltip(
                      message:
                          'Round $round${roundLimit == null ? '' : ' of $roundLimit'}',
                      child: Text(
                        'R$round${roundLimit == null ? '' : '/$roundLimit'}',
                        key: const Key('header-round'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.textSecondary,
                        ),
                      ),
                    ),
                    separator(),
                    Tooltip(
                      message: 'Level $level · $difficulty',
                      child: Text(
                        'Lv$level',
                        key: const Key('tier-label'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kind.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: [
      if (showSettings)
        SizedBox(
          width: 44,
          child: IconButton(
            key: const Key('game-settings'),
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 23),
          ),
        )
      else
        const SizedBox(width: 8),
      const SizedBox(width: 4),
    ],
  );

  Widget separator() => Container(
    width: 1,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: NovaColors.textSecondary.withValues(alpha: .22),
  );
}
