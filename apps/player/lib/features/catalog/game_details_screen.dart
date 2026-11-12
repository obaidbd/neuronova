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
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: NovaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(game.icon, color: game.accent, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        game.blurb,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Best ${widget.store.bestFor(game.skillKey)}',
                      style: TextStyle(color: game.accent, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<int>(
                  key: const Key('game-difficulty'),
                  initialValue: tier ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Adaptive')),
                    for (var i = 1; i <= 10; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('Practice · level $i'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => tier = value == 0 ? null : value),
                ),
                if (tier != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Practice keeps your saved skill unchanged.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    key: const Key('game-untimed'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Relaxed scoring'),
                    subtitle: const Text('No speed bonus'),
                    value: untimed,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => untimed = value),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: const Text(
                    'How to play',
                    style: TextStyle(fontSize: 15),
                  ),
                  children: [
                    for (var i = 0; i < game.instructions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: TextStyle(color: game.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                game.instructions[i],
                                style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('play-game'),
                  onPressed: busy ? null : start,
                  style: FilledButton.styleFrom(backgroundColor: game.accent),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(game == GameKind.echoGrid ? 'Continue' : 'Play'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
