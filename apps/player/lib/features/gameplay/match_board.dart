import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/rules/echo_match.dart';

/// Keeps seats and the current player's controls fixed around the shared board.
class MatchBoard extends StatefulWidget {
  const MatchBoard({
    super.key,
    required this.match,
    required this.player,
    required this.child,
  });
  final EchoMatch match;
  final EchoPlayer player;
  final Widget child;

  @override
  State<MatchBoard> createState() => _MatchBoardState();
}

class _MatchBoardState extends State<MatchBoard> {
  final controls = _TurnControls();

  @override
  void dispose() {
    controls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TurnScope(
    controls: controls,
    child: Column(
      children: [
        _seats(top: true),
        const SizedBox(height: 8),
        Expanded(child: widget.child),
        const SizedBox(height: 8),
        _seats(top: false),
      ],
    ),
  );

  Widget _seats({required bool top}) {
    if (widget.match.players.length == 2) {
      return Center(child: SizedBox(width: 210, child: _seat(top ? 1 : 0)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _seat(top ? 1 : 0)),
        const SizedBox(width: 10),
        Expanded(
          child: top
              ? _seat(2)
              : widget.match.players.length == 4
              ? _seat(3)
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _seat(int index) {
    final seat = widget.match.players[index];
    final active = identical(seat, widget.player);
    final color = const [
      Color(0xFFFF8E91),
      Color(0xFF83B6FF),
      NovaColors.gold,
      NovaColors.emerald,
    ][index];
    return AnimatedContainer(
      key: Key('player-seat-$index'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: .13) : NovaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? color : color.withValues(alpha: .18),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                '${seat.name}, level ${seat.level}, ${seat.points} points${active ? ", current turn" : ""}',
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      seat.computer
                          ? Icons.smart_toy_rounded
                          : Icons.person_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Tooltip(
                        message: seat.name,
                        child: Text(
                          seat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (active)
                      Icon(Icons.play_arrow_rounded, size: 15, color: color),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${seat.points}',
                        key: Key('points-$index'),
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Lv ${seat.level}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reserve the same space at every seat so controls never move the board.
          SizedBox(
            height: 40,
            child: active
                ? ValueListenableBuilder<_SeatAction?>(
                    valueListenable: controls,
                    builder: (context, action, _) => action == null
                        ? Center(
                            child: Text(
                              seat.computer ? 'Thinking…' : 'Your turn',
                              style: TextStyle(fontSize: 11, color: color),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: Key('seat-action-$index'),
                              onPressed: action.onPressed,
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 36),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(action.label),
                              ),
                            ),
                          ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _SeatAction {
  const _SeatAction(this.owner, this.label, this.onPressed);
  final Object owner;
  final String label;
  final VoidCallback? onPressed;
}

class _TurnControls extends ValueNotifier<_SeatAction?> {
  _TurnControls() : super(null);
  bool alive = true;
  @override
  void dispose() {
    alive = false;
    super.dispose();
  }
}

class _TurnScope extends InheritedWidget {
  const _TurnScope({required this.controls, required super.child});
  final _TurnControls controls;
  @override
  bool updateShouldNotify(_TurnScope oldWidget) =>
      oldWidget.controls != controls;
}

/// A normal solo button, or a control beside the active player's name.
class TurnActionButton extends StatefulWidget {
  const TurnActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  State<TurnActionButton> createState() => _TurnActionButtonState();
}

class _TurnActionButtonState extends State<TurnActionButton> {
  _TurnControls? controls;
  @override
  Widget build(BuildContext context) {
    controls = context
        .dependOnInheritedWidgetOfExactType<_TurnScope>()
        ?.controls;
    final target = controls;
    if (target == null) {
      return FilledButton(
        onPressed: widget.onPressed,
        child: Text(widget.label),
      );
    }
    final action = _SeatAction(this, widget.label, widget.onPressed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && target.alive) target.value = action;
    });
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    final target = controls;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target != null &&
          target.alive &&
          identical(target.value?.owner, this)) {
        target.value = null;
      }
    });
    super.dispose();
  }
}

class MatchResults extends StatelessWidget {
  const MatchResults({super.key, required this.match});
  final EchoMatch match;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 20),
    children: [
      const Icon(Icons.emoji_events_rounded, size: 64, color: NovaColors.gold),
      const SizedBox(height: 12),
      Text(
        '${match.winners.map((p) => p.name).join(" & ")} ${match.winners.length == 1 ? "wins!" : "tie!"}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      for (final p in match.standings)
        ListTile(
          title: Text(p.name),
          subtitle: Text(
            'Highest completed level ${p.reachedLevel} · ${p.rounds} rounds',
          ),
          trailing: Text(
            '${p.points}',
            style: const TextStyle(
              color: NovaColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to setup'),
      ),
    ],
  );
}
