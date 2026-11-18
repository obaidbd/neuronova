import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../catalog/game_presentation.dart';
import 'round_journey.dart';

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
    this.animate = false,
  });
  final GameKind kind;
  final int points, round, level;
  final int? roundLimit;
  final VoidCallback? onSettings;
  final String difficulty;
  final String? title;
  final bool showSettings;

  /// Count points up and slide the level bar instead of jumping. Used for solo
  /// play; shared-device matches switch between players, so they stay static.
  final bool animate;

  @override
  Size get preferredSize => const Size.fromHeight(57);

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
                        child: _CountUp(
                          animate: animate,
                          value: points,
                          textKey: const Key('game-total-score'),
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
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(3),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: level % 5 / 5),
        duration: animate && !MediaQuery.disableAnimationsOf(context)
            ? const Duration(milliseconds: 450)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 3,
          color: kind.accent.withValues(alpha: .75),
          backgroundColor: NovaColors.surface,
          semanticsLabel:
              'Level $level. Next checkpoint level ${nextCheckpoint(level)}',
        ),
      ),
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

/// Animates a whole number up (or down) to [value] when it changes.
class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.style,
    required this.animate,
    this.textKey,
  });
  final int value;
  final bool animate;
  final TextStyle style;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: value.toDouble()),
    duration: animate && !MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 500)
        : Duration.zero,
    curve: Curves.easeOutCubic,
    builder: (context, v, _) =>
        Text('${v.round()}', key: textKey, style: style),
  );
}
