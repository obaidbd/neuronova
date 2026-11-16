import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A stable 2 × 2 choice layout with generous, consistent touch targets.
class AnswerCards extends StatelessWidget {
  const AnswerCards({
    super.key,
    required this.count,
    required this.accent,
    required this.onPick,
    required this.itemBuilder,
    this.labelBuilder,
    this.itemHeight = 88,
  });
  final int count;
  final Color accent;
  final ValueChanged<int> onPick;
  final Widget Function(int index) itemBuilder;
  final String Function(int index)? labelBuilder;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: width,
              height: itemHeight,
              child: Semantics(
                button: true,
                label: labelBuilder?.call(i),
                excludeSemantics: labelBuilder != null,
                onTap: () => onPick(i),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: NovaColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: .22)),
                    ),
                    child: InkWell(
                      key: Key('option-$i'),
                      onTap: () => onPick(i),
                      borderRadius: BorderRadius.circular(18),
                      child: Center(child: itemBuilder(i)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
