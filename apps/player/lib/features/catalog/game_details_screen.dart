import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../core/progress_store.dart';
import '../gameplay/echo_setup_screen.dart';
import '../gameplay/round_shell.dart';
import 'game_presentation.dart';

class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({super.key, required this.kind, required this.store});
  final GameKind kind;
  final ProgressStore store;
  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  late int? tier = widget.store.practiceTierFor(widget.kind.skillKey);
  late bool untimed = widget.store.untimedFor(widget.kind.skillKey);
  bool busy = false;

  Future<void> start() async {
    setState(() => busy = true);
    try {
      await widget.store.setPracticeTierFor(widget.kind.skillKey, tier);
      await widget.store.setUntimedFor(widget.kind.skillKey, untimed);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.kind == GameKind.echoGrid
              ? EchoSetupScreen(store: widget.store, tierOverride: tier)
              : RoundShell(
                  kind: widget.kind,
                  store: widget.store,
                  tierOverride: tier,
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.kind;
    return Scaffold(
      appBar: AppBar(
        title: Text(game.title),
        backgroundColor: NovaColors.background,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        game.accent.withValues(alpha: .20),
                        NovaColors.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: game.accent.withValues(alpha: .3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(game.icon, color: game.accent, size: 42),
                          const Spacer(),
                          Text(
                            game.category,
                            style: TextStyle(
                              color: game.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        game.title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.description,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Best ${widget.store.bestFor(game.skillKey)} pts',
                            style: TextStyle(
                              color: game.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Skill level ${widget.store.skillFor(game.skillKey).tier}',
                            style: const TextStyle(
                              color: NovaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'How to play',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < game.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: game.accent.withValues(alpha: .12),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: game.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            game.instructions[i],
                            style: const TextStyle(
                              height: 1.45,
                              color: NovaColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: NovaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Game settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        key: const Key('game-difficulty'),
                        initialValue: tier ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('Adaptive progression'),
                          ),
                          for (var i = 1; i <= 10; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('Practice · level $i'),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(
                                () => tier = value == 0 ? null : value,
                              ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tier == null
                            ? 'Difficulty grows as your skills improve.'
                            : 'Practice stays at this level and keeps your saved skill unchanged.',
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      Material(
                        color: NovaColors.surface,
                        child: SwitchListTile(
                          key: const Key('game-untimed'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Relaxed scoring'),
                          subtitle: const Text(
                            'No speed bonus. Take your time answering.',
                          ),
                          value: untimed,
                          onChanged: busy
                              ? null
                              : (value) => setState(() => untimed = value),
                        ),
                      ),
                      const Text(
                        'Settings are saved for this game when you start.',
                        style: TextStyle(
                          fontSize: 12,
                          color: NovaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (game == GameKind.echoGrid)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Next: choose preview time, players and number of rounds.',
                      style: TextStyle(color: NovaColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('play-game'),
                  onPressed: busy ? null : start,
                  style: FilledButton.styleFrom(backgroundColor: game.accent),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    game == GameKind.echoGrid
                        ? 'Choose players & rounds'
                        : 'Play ${game.title}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
