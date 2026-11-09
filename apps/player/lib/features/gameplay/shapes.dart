import 'package:flutter/material.dart';

import '../../app/theme.dart';

const shapeIcons = [
  Icons.circle,
  Icons.change_history,
  Icons.square,
  Icons.star,
];
const shapeNames = ['circle', 'triangle', 'square', 'star'];
const shapeColors = [
  NovaColors.blue,
  NovaColors.emerald,
  NovaColors.gold,
  NovaColors.danger,
];
const colorNames = ['blue', 'green', 'gold', 'red'];

/// Colour is never the only cue: the colour name is printed under the shape.
class ShapeChip extends StatelessWidget {
  const ShapeChip(
    this.shape,
    this.color, {
    super.key,
    this.size = 36,
    this.showName = true,
  });
  final int shape, color;
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${colorNames[color]} ${shapeNames[shape]}',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(shapeIcons[shape], color: shapeColors[color], size: size),
          if (showName)
            Text(
              colorNames[color],
              style: const TextStyle(
                fontSize: 10,
                color: NovaColors.textSecondary,
              ),
            ),
        ],
      ),
    ),
  );
}
