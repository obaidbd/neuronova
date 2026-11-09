import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/path_recall.dart';
import '../round_shell.dart';

class PathRecallGame extends StatefulWidget {
  const PathRecallGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<PathRecallGame> createState() => _S();
}

class _S extends State<PathRecallGame> {
  late final PathPuzzle p = PathPuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  bool previewing = true;
  final List<int> moves = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: p.previewMs), () {
      if (mounted) setState(() => previewing = false);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  List<int> get visited => [p.start, ...moves];

  void _tap(int cell) {
    if (previewing || moves.length >= p.expected.length - 1) return;
    if (!p.isLegalMove(visited, cell)) return; // walls/jumps rejected
    setState(() => moves.add(cell));
    if (moves.length == p.expected.length - 1) {
      final r = p.evaluate(moves);
      widget.onFinished(
        RoundOutcome(
          accuracy: r.accuracy,
          perfect: r.perfect,
          message: r.perfect
              ? ''
              : '${r.correct}/${p.expected.length - 1} steps correct',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = previewing ? p.expected : visited;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          previewing
              ? 'Memorise the route${p.reverse ? ' (you will walk it backwards)' : ''}'
              : (p.reverse ? 'Walk the route in reverse' : 'Walk the route'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, color: NovaColors.textSecondary),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.count(
            crossAxisCount: p.size,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < p.cells; i++) _cell(i, show.indexOf(i)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!previewing && moves.isNotEmpty)
          TextButton(
            key: const Key('undo'),
            onPressed: () => setState(moves.removeLast),
            child: const Text('Undo last step'),
          ),
      ],
    );
  }

  Widget _cell(int i, int order) {
    final onPath = order >= 0;
    final isStart = i == p.start;
    return GestureDetector(
      key: Key('cell-$i'),
      onTap: () => _tap(i),
      child: Container(
        decoration: BoxDecoration(
          color: isStart
              ? NovaColors.gold
              : onPath
              ? NovaColors.blue
              : NovaColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        // Step numbers keep the route readable without relying on colour.
        child: onPath
            ? Text(
                isStart ? 'S' : '$order',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: NovaColors.background,
                ),
              )
            : null,
      ),
    );
  }
}
