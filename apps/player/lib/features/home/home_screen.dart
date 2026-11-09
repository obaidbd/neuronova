import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../../core/game_kind.dart';
import '../gameplay/echo_grid_screen.dart';
import '../gameplay/round_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? testTier; // null = adaptive

  Future<void> _open(GameKind k) async {
    final s = widget.store;
    final route = MaterialPageRoute<void>(
      builder: (_) => k == GameKind.echoGrid
          ? EchoGridScreen(store: s, tierOverride: testTier)
          : RoundShell(kind: k, store: s, tierOverride: testTier),
    );
    await Navigator.of(context).push(route);
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    final s = widget.store;
    if (!s.tutorialDone) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EchoGridScreen(store: s, tutorial: true),
        ),
      );
      if (ok == true) await s.setTutorialDone();
    } else {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => EchoGridScreen(store: s)));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'NeuroNova',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: NovaColors.emerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Play. Think. Discover.',
                    style: TextStyle(
                      fontSize: 18,
                      color: NovaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: _play,
                    child: Text(s.tutorialDone ? 'Continue' : 'Play Now'),
                  ),
                  const SizedBox(height: 32),
                  if (s.completedRounds > 0)
                    Text(
                      'Nova Energy ${s.novaEnergy}  •  XP ${s.xp}  •  Best ${s.bestScore}',
                      style: const TextStyle(color: NovaColors.gold),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'All games',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final k in GameKind.values)
                        ActionChip(
                          key: Key('game-${k.name}'),
                          avatar: Icon(k.icon, size: 18),
                          label: Text('${k.title} · ${k.blurb}'),
                          onPressed: () => _open(k),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Text('Difficulty: '),
                      DropdownButton<int?>(
                        key: const Key('tier-select'),
                        value: testTier,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Adaptive'),
                          ),
                          for (var t = 1; t <= 10; t++)
                            DropdownMenuItem(
                              value: t,
                              child: Text('Test tier $t'),
                            ),
                        ],
                        onChanged: (v) => setState(() => testTier = v),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Untimed accessible mode'),
                    value: s.untimedMode,
                    onChanged: (v) async {
                      await s.setUntimed(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
