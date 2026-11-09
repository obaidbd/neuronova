import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/progress_store.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/echo_grid.dart';
import '../../game/rules/scoring.dart';

enum _Phase { preview, recall, result }

class EchoGridScreen extends StatefulWidget {
  const EchoGridScreen({
    super.key,
    required this.store,
    this.tutorial = false,
    this.seed,
    this.tierOverride,
  });
  final ProgressStore store;
  final bool tutorial;
  final int? seed;
  final int? tierOverride;

  @override
  State<EchoGridScreen> createState() => _EchoGridScreenState();
}

class _EchoGridScreenState extends State<EchoGridScreen> {
  late EchoGridPuzzle puzzle;
  late SkillState skill;
  final Set<int> selected = {};
  _Phase phase = _Phase.preview;
  Timer? _timer;
  late Stopwatch _clock;
  EchoGridResult? result;
  int score = 0;
  int xpAwarded = 0;
  bool committing = false;
  late String roundId;

  @override
  void initState() {
    super.initState();
    skill = widget.store.memorySkill;
    _newRound();
  }

  void _newRound() {
    _timer?.cancel();
    final seed = widget.seed ?? Random().nextInt(1 << 30);
    final tier = widget.tutorial ? 1 : (widget.tierOverride ?? skill.tier);
    puzzle = EchoGridPuzzle.generate(tier: tier, seed: seed);
    roundId = '${DateTime.now().microsecondsSinceEpoch}-$seed';
    selected.clear();
    result = null;
    phase = _Phase.preview;
    _timer = Timer(Duration(milliseconds: puzzle.config.previewMs), () {
      if (!mounted) return;
      setState(() {
        phase = _Phase.recall;
        _clock = Stopwatch()..start();
      });
    });
    setState(() {});
  }

  void _toggle(int i) {
    if (phase != _Phase.recall) return;
    setState(() {
      if (selected.contains(i)) {
        selected.remove(i);
      } else if (selected.length < puzzle.config.targets) {
        selected.add(i);
      }
    });
  }

  Future<void> _submit() async {
    if (committing || selected.length != puzzle.config.targets) return;
    committing = true;
    _clock.stop();
    final r = puzzle.evaluate(selected);
    final untimed = widget.store.untimedMode;
    final s = gameScore(
      accuracy: r.accuracy,
      timed: !untimed,
      hints: 0,
      targetMs: 8000 + puzzle.config.targets * 1500,
      actualMs: _clock.elapsedMilliseconds,
    );
    final first = widget.store.completedRounds == 0;
    final xp = xpForScore(s, firstCompletion: first || r.perfect);
    skill.record(RoundRecord(accuracy: r.accuracy, success: r.perfect));
    await widget.store.commitRound(
        roundId: roundId, score: s, xp: xp, skill: skill);
    if (!mounted) return;
    setState(() {
      result = r;
      score = s;
      xpAwarded = xp;
      phase = _Phase.result;
      committing = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = puzzle.config.size;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tutorial ? 'First Gate' : 'Echo Grid'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_instruction(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, color: NovaColors.textSecondary)),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 1,
                    child: GridView.count(
                      crossAxisCount: size,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [for (var i = 0; i < size * size; i++) _cell(i)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (phase == _Phase.recall)
                    FilledButton(
                      onPressed: selected.length == puzzle.config.targets
                          ? _submit
                          : null,
                      child: Text(
                          'Submit (${selected.length}/${puzzle.config.targets})'),
                    ),
                  if (phase == _Phase.result) _resultPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _instruction() => switch (phase) {
        _Phase.preview => widget.tutorial
            ? 'Watch the glowing tiles…'
            : 'Remember the glowing tiles',
        _Phase.recall => widget.tutorial
            ? 'Now tap the tiles that glowed'
            : 'Tap the tiles that glowed',
        _Phase.result => result!.perfect
            ? 'The gate opens!'
            : 'Good try — ${result!.hits}/${puzzle.config.targets} correct',
      };

  Widget _cell(int i) {
    final isTarget = puzzle.targets.contains(i);
    final isSel = selected.contains(i);
    Color color = NovaColors.surface;
    IconData? icon;
    String label = 'Tile ${i + 1}';
    if (phase == _Phase.preview && isTarget) {
      color = NovaColors.gold;
      icon = Icons.star;
      label += ', glowing';
    } else if (phase == _Phase.recall && isSel) {
      color = NovaColors.blue;
      icon = Icons.check;
      label += ', selected';
    } else if (phase == _Phase.result) {
      if (isTarget && isSel) {
        color = NovaColors.emerald;
        icon = Icons.check;
      } else if (isTarget) {
        color = NovaColors.gold;
        icon = Icons.star;
      } else if (isSel) {
        color = NovaColors.danger;
        icon = Icons.close;
      }
    }
    // Colour-independent cue: every state also has an icon.
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => _toggle(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.blue.withValues(alpha: 0.25)),
          ),
          child: icon == null
              ? null
              : Icon(icon, color: NovaColors.background, size: 28),
        ),
      ),
    );
  }

  Widget _resultPanel() => Column(children: [
        Text('Score $score  •  +$xpAwarded XP',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: NovaColors.gold)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
          FilledButton(
            onPressed: widget.tutorial
                ? () => Navigator.of(context).pop(true)
                : _newRound,
            child: Text(widget.tutorial ? 'Continue' : 'Next round'),
          ),
          if (!widget.tutorial)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Home'),
            ),
        ]),
      ]);
}
