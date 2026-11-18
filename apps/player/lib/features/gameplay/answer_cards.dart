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
    this.pickedIndex,
    this.correctIndex,
  });
  final int count;
  final Color accent;
  final ValueChanged<int> onPick;
  final Widget Function(int index) itemBuilder;
  final String Function(int index)? labelBuilder;
  final double itemHeight;

  /// After an answer: the card the player chose, and the right card. The
  /// chosen card is marked right or wrong; a missed right card is revealed.
  final int? pickedIndex, correctIndex;

  /// Highlight colour for a card once an answer exists, else null.
  Color? _mark(int i) {
    if (pickedIndex == null) return null;
    if (i == correctIndex) return accent;
    if (i == pickedIndex) return NovaColors.danger;
    return null;
  }

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
                      color: _mark(i) == null
                          ? NovaColors.surface
                          : _mark(i)!.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _mark(i) ?? accent.withValues(alpha: .22),
                        width: _mark(i) == null ? 1 : 2,
                      ),
                    ),
                    child: InkWell(
                      key: Key('option-$i'),
                      onTap: () => onPick(i),
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(child: itemBuilder(i)),
                          if (_mark(i) != null)
                            Positioned(
                              top: 6,
                              right: 8,
                              child: Icon(
                                i == correctIndex
                                    ? Icons.check_circle_rounded
                                    : Icons.close_rounded,
                                size: 18,
                                color: _mark(i),
                              ),
                            ),
                        ],
                      ),
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
