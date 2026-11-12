import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../../core/game_kind.dart';
import '../catalog/game_details_screen.dart';
import '../catalog/game_presentation.dart';
import '../gameplay/echo_grid_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> open(GameKind game) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameDetailsScreen(kind: game, store: widget.store),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> play() async {
    if (widget.store.tutorialDone) {
      await open(GameKind.echoGrid);
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EchoGridScreen(store: widget.store, tutorial: true),
      ),
    );
    if (ok == true) await widget.store.setTutorialDone();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: NovaColors.emerald,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'NeuroNova',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Total XP',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: NovaColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.store.xp} XP',
                        style: const TextStyle(
                          fontSize: 12,
                          color: NovaColors.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Games',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: play,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      widget.store.tutorialDone ? 'Continue' : 'Play Now',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 580 ? 6 : 3;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final game in GameKind.values)
                        SizedBox(
                          width: width,
                          height: 92,
                          child: Semantics(
                            button: true,
                            onTap: () => open(game),
                            label:
                                '${game.title}, ${game.blurb}. View details and settings.',
                            excludeSemantics: true,
                            child: Tooltip(
                              message: game.title,
                              child: Material(
                                color: NovaColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  key: Key('game-${game.name}'),
                                  onTap: () => open(game),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Center(
                                    child: Icon(
                                      game.icon,
                                      color: game.accent,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
