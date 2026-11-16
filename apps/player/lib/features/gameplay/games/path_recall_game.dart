import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/path_recall.dart';
import '../round_shell.dart';
import '../match_board.dart';

class PathRecallGame extends StatefulWidget {
  const PathRecallGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
    this.previewSeconds,
    this.onRecallStarted,
  });
  final int tier, seed;
  final int? previewSeconds;
  final VoidCallback? onRecallStarted;
  final OutcomeCallback onFinished;
  @override
  State<PathRecallGame> createState() => _S();
}

class _S extends State<PathRecallGame> {
  late final PathPuzzle p = PathPuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  bool previewing = true, done = false;
  final List<int> moves = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    if (widget.previewSeconds != 0) {
      timer = Timer(
        Duration(
          milliseconds: widget.previewSeconds == null
              ? p.previewMs
              : widget.previewSeconds! * 1000,
        ),
        startRecall,
      );
    }
  }

  void startRecall() {
    if (!mounted || !previewing) return;
    timer?.cancel();
    setState(() => previewing = false);
    widget.onRecallStarted?.call();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  List<int> get visited => [p.start, ...moves];

  void tapCell(int cell) {
    if (previewing ||
        done ||
        moves.length >= p.expected.length - 1 ||
        !p.isLegalMove(visited, cell)) {
      return;
    }
    setState(() => moves.add(cell));
  }

  void submit() {
    if (previewing || done || moves.isEmpty) return;
    done = true;
    final result = p.evaluate(moves);
    widget.onFinished(
      RoundOutcome(
        accuracy: result.accuracy,
        perfect: result.perfect,
        message: result.perfect
            ? ''
            : '${result.correct}/${p.expected.length - 1} steps correct',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final show = previewing ? p.expected : visited;
      final availableHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : 600.0;
      final side = min(
        constraints.maxWidth,
        max(p.size * 32.0, availableHeight - 205),
      );
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              previewing
                  ? 'Memorise the route${p.reverse ? ' (walk it backwards)' : ''}'
                  : p.reverse
                  ? 'Walk the route in reverse'
                  : 'Walk the route',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: NovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              previewing
                  ? '${p.expected.length - 1} steps · ${p.size} × ${p.size}'
                  : '${moves.length}/${p.expected.length - 1} steps',
              style: const TextStyle(fontSize: 12, color: NovaColors.gold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: previewing
                      ? 1
                      : moves.length / (p.expected.length - 1),
                  minHeight: 3,
                  color: NovaColors.blue,
                  backgroundColor: NovaColors.surface,
                  semanticsLabel: previewing
                      ? 'Route preview'
                      : 'Route steps selected',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: side,
                height: side,
                child: GridView.count(
                  crossAxisCount: p.size,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < p.cells; i++) cell(i, show.indexOf(i)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (previewing)
              if (widget.previewSeconds == 0)
                TurnActionButton(
                  key: const Key('preview-start'),
                  onPressed: startRecall,
                  label: 'Start',
                )
              else
                const SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'Watch the route…',
                      style: TextStyle(color: NovaColors.textSecondary),
                    ),
                  ),
                )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const Key('undo'),
                    onPressed: moves.isEmpty || done
                        ? null
                        : () => setState(moves.removeLast),
                    child: const Text('Undo'),
                  ),
                  TurnActionButton(
                    key: const Key('submit'),
                    onPressed: moves.isEmpty || done ? null : submit,
                    label: 'Submit (${moves.length}/${p.expected.length - 1})',
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );

  Widget cell(int i, int order) {
    final onPath = order >= 0, isStart = i == p.start;
    return Semantics(
      key: Key('cell-$i'),
      onTap: !previewing && !done ? () => tapCell(i) : null,
      button: true,
      enabled: !previewing && !done,
      label:
          'Cell ${i + 1}${isStart ? ", start" : ""}${previewing && onPath ? ", step $order" : ""}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => tapCell(i),
        borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }
}
