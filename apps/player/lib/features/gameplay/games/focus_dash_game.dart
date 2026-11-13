import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../game/rules/focus_dash.dart';
import '../round_shell.dart';
import '../match_board.dart';
import '../shapes.dart';

class FocusDashGame extends StatefulWidget {
  const FocusDashGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<FocusDashGame> createState() => _S();
}

class _S extends State<FocusDashGame> {
  late final FocusPuzzle p = FocusPuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  final Set<int> selected = {};

  void _submit() {
    final r = p.evaluate(selected);
    widget.onFinished(
      RoundOutcome(
        accuracy: r.accuracy,
        perfect: r.perfect,
        message: '${r.hits}/${p.targets.length} found, ${r.wrong} wrong taps',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Tap every ${colorNames[p.targetColor]} ${shapeNames[p.targetShape]}  ',
              style: const TextStyle(
                fontSize: 20,
                color: NovaColors.textSecondary,
              ),
            ),
            ShapeChip(p.targetShape, p.targetColor, size: 28, showName: false),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: p.cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < p.items.length; i++)
              InkWell(
                key: Key('item-$i'),
                onTap: () => setState(
                  () => selected.contains(i)
                      ? selected.remove(i)
                      : selected.add(i),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: NovaColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected.contains(i)
                          ? NovaColors.text
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ShapeChip(p.items[i].shape, p.items[i].color, size: 34),
                      if (selected.contains(i))
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.check_circle, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TurnActionButton(
          key: const Key('submit'),
          onPressed: selected.isEmpty ? null : _submit,
          label: 'Submit (${selected.length})',
        ),
      ],
    );
  }
}
