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
    this.gain,
    this.gainKey,
    this.extraActions = const [],
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

  /// Points just earned; floats up beside the total once. [gainKey] must
  /// differ for every round so the pop plays again.
  final int? gain;
  final Object? gainKey;

  /// Extra icon buttons shown before the settings button (e.g. sound).
  final List<Widget> extraActions;

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
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _CountUp(
                              animate: animate,
                              value: points,
                              textKey: const Key('game-total-score'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: NovaColors.gold,
                              ),
                            ),
                            if (animate && gain != null && gain! > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: _GainPop(
                                  key: ValueKey(gainKey),
                                  gain: gain!,
                                ),
                              ),
                          ],
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
                      child: _Pulse(
                        value: level,
                        enabled: animate,
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
      ...extraActions,
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

/// "+N" that rises and fades once beside the points total.
class _GainPop extends StatelessWidget {
  const _GainPop({super.key, required this.gain});
  final int gain;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, t, child) => Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -18 * t),
              child: child,
            ),
          ),
          child: Text(
            '+$gain',
            key: const Key('header-gain'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: NovaColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Briefly scales [child] up whenever [value] changes (not on first build).
class _Pulse extends StatefulWidget {
  const _Pulse({
    required this.value,
    required this.enabled,
    required this.child,
  });
  final int value;
  final bool enabled;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (widget.enabled &&
        widget.value != old.value &&
        !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.scale(
      scale:
          1 +
          .45 *
              Curves.easeOutBack.transform(1 - _c.value) *
              (_c.isAnimating ? 1 : 0),
      child: child,
    ),
    child: widget.child,
  );
}
