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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NovaColors.emerald.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: NovaColors.emerald,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'NeuroNova',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: NovaColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Guest',
                          style: TextStyle(
                            fontSize: 12,
                            color: NovaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF214B55),
                      Color(0xFF193344),
                      Color(0xFF1C304D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: NovaColors.emerald.withValues(alpha: .22),
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      right: -28,
                      top: 18,
                      child: Icon(
                        Icons.psychology_alt_rounded,
                        size: 178,
                        color: Color(0x124FE3C2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A LITTLE PLAY. A BRIGHTER MIND.',
                            style: TextStyle(
                              color: NovaColors.emerald,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Play. Think.\nDiscover.',
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.08,
                              letterSpacing: -.7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Six small adventures for your curious mind.',
                            style: TextStyle(
                              color: NovaColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: play,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 21,
                            ),
                            label: Text(
                              widget.store.tutorialDone
                                  ? 'Continue'
                                  : 'Play Now',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: NovaColors.surface.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    stat(
                      Icons.bolt_rounded,
                      NovaColors.emerald,
                      '${widget.store.novaEnergy}',
                      'Energy',
                    ),
                    stat(
                      Icons.auto_awesome,
                      NovaColors.gold,
                      '${widget.store.xp}',
                      'Total XP',
                    ),
                    stat(
                      Icons.flag_outlined,
                      NovaColors.blue,
                      '${widget.store.completedRounds}',
                      'Rounds',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Find your next challenge',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  Text(
                    '6 GAMES',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: NovaColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a game. Make it yours.',
                style: TextStyle(color: NovaColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scaled =
                      MediaQuery.textScalerOf(context).scale(16) > 20;
                  final columns = constraints.maxWidth >= 760
                      ? 3
                      : constraints.maxWidth >= 330 && !scaled
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final game in GameKind.values)
                        SizedBox(width: width, child: gameCard(game)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Small moments of play. A little better every day.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NovaColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget stat(IconData icon, Color color, String value, String label) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget gameCard(GameKind game) => Semantics(
    button: true,
    onTap: () => open(game),
    label: '${game.title}, ${game.blurb}. View details and settings.',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('game-${game.name}'),
        onTap: () => open(game),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [game.accent.withValues(alpha: .16), NovaColors.surface],
            ),
            border: Border.all(color: game.accent.withValues(alpha: .23)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: game.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(game.icon, size: 27, color: game.accent),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 17,
                      color: game.accent.withValues(alpha: .7),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  game.category,
                  style: TextStyle(
                    color: game.accent,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Text(
                    game.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Text(
                    game.blurb,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NovaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 14,
                      color: game.accent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Best ${widget.store.bestFor(game.skillKey)}',
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Icon(Icons.tune_rounded, size: 15, color: game.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
