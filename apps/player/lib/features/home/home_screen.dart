import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../gameplay/echo_grid_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _play() async {
    final s = widget.store;
    if (!s.tutorialDone) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => EchoGridScreen(store: s, tutorial: true)));
      if (ok == true) await s.setTutorialDone();
    } else {
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EchoGridScreen(store: s)));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('NeuroNova',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: NovaColors.emerald)),
                const SizedBox(height: 4),
                const Text('Play. Think. Discover.',
                    style: TextStyle(
                        fontSize: 18, color: NovaColors.textSecondary)),
                const SizedBox(height: 40),
                FilledButton(
                    onPressed: _play,
                    child: Text(s.tutorialDone ? 'Continue' : 'Play Now')),
                const SizedBox(height: 32),
                if (s.completedRounds > 0)
                  Text(
                      'Nova Energy ${s.novaEnergy}  •  XP ${s.xp}  •  Best ${s.bestScore}',
                      style: const TextStyle(color: NovaColors.gold)),
                const SizedBox(height: 16),
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
    );
  }
}
