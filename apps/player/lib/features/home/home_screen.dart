import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../../core/game_kind.dart';
import '../gameplay/round_shell.dart';
import '../catalog/game_presentation.dart';
import '../gameplay/echo_grid_screen.dart';

/// Stable card positions; only the subtle daily suggestion changes.
GameKind dailyGame(DateTime date) =>
    GameKind.values[DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(2026)).inDays %
        GameKind.values.length];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameKind get resumeGame => GameKind.values.firstWhere(
    (g) => g.name == widget.store.lastPlayedGame,
    orElse: () => GameKind.echoGrid,
  );

  Future<void> open(GameKind game) async {
    await widget.store.setLastPlayedGame(game.name);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => game == GameKind.echoGrid
            ? EchoGridScreen(
                store: widget.store,
                tierOverride: widget.store.practiceTierFor(game.skillKey),
              )
            : RoundShell(kind: game, store: widget.store),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> play() async {
    if (widget.store.tutorialDone || widget.store.lastPlayedGame != null) {
      await open(resumeGame);
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EchoGridScreen(store: widget.store, tutorial: true),
      ),
    );
    if (ok == true) {
      await widget.store.setTutorialDone();
      await widget.store.setLastPlayedGame(GameKind.echoGrid.name);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pick = dailyGame(DateTime.now());
    final returning =
        widget.store.tutorialDone || widget.store.lastPlayedGame != null;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.6, -.8),
            radius: 1.4,
            colors: [
              NovaColors.emerald.withValues(alpha: .09),
              NovaColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: NovaColors.emerald.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: NovaColors.emerald,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NeuroNova',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.6,
                                ),
                              ),
                              Text(
                                'A little play. A new discovery.',
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
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _suggestion(pick),
                                const SizedBox(height: 24),
                                const Text(
                                  'Choose your spark',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width =
                                        (constraints.maxWidth - 24) / 3;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        for (final game in GameKind.values)
                                          SizedBox(
                                            width: width,
                                            height: 96,
                                            child: _gameTile(game, pick),
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
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('home-continue'),
                        onPressed: play,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(returning ? 'Continue' : 'Play Now'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestion(GameKind pick) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: pick.accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: pick.accent.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Icon(Icons.explore_rounded, color: pick.accent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today’s pick',
                style: TextStyle(fontSize: 11, color: NovaColors.textSecondary),
              ),
              Text(
                pick.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('daily-pick'),
          tooltip: 'Play today’s pick: ${pick.title}',
          onPressed: () => open(pick),
          icon: Icon(Icons.arrow_forward_rounded, color: pick.accent),
        ),
      ],
    ),
  );

  Widget _gameTile(GameKind game, GameKind pick) => Semantics(
    button: true,
    onTap: () => open(game),
    label: '${game.title}, ${game.blurb}. Play game.',
    excludeSemantics: true,
    child: Tooltip(
      message: game.title,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [game.accent.withValues(alpha: .13), NovaColors.surface],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: game.accent.withValues(alpha: game == pick ? .5 : .18),
            ),
          ),
          child: InkWell(
            key: Key('game-${game.name}'),
            onTap: () => open(game),
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: game.accent.withValues(alpha: .08),
                  ),
                  child: Icon(game.icon, color: game.accent, size: 30),
                ),
                if (game == pick)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: game.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
