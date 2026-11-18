import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/game_kind.dart';
import '../../../game/rules/flip_match.dart';
import '../../catalog/game_presentation.dart';
import '../nova_board.dart';
import '../round_shell.dart';

/// Flip two cards at a time and match every fruit / animal pair.
class FlipMatchGame extends StatefulWidget {
  const FlipMatchGame({
    super.key,
    required this.tier,
    required this.seed,
    required this.onFinished,
  });
  final int tier, seed;
  final OutcomeCallback onFinished;
  @override
  State<FlipMatchGame> createState() => _S();
}

class _S extends State<FlipMatchGame> {
  late final FlipPuzzle p = FlipPuzzle.generate(
    tier: widget.tier,
    seed: widget.seed,
  );
  late final List<bool> matched = List.filled(p.cards.length, false);
  int? first, second;
  int mistakes = 0, foundPairs = 0;
  bool locked = false, done = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  bool _faceUp(int i) => matched[i] || i == first || i == second;

  void _flip(int i) {
    if (locked || done || matched[i] || i == first) return;
    if (first == null) {
      setState(() => first = i);
      return;
    }
    setState(() => second = i);
    if (p.isMatch(first!, i)) {
      matched[first!] = matched[i] = true;
      foundPairs++;
      setState(() {
        first = null;
        second = null;
      });
      if (foundPairs == p.pairs) _finish();
      return;
    }
    mistakes++;
    locked = true;
    _hide = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() {
        first = null;
        second = null;
        locked = false;
      });
    });
  }

  void _finish() {
    done = true;
    final r = p.evaluate(mistakes: mistakes);
    widget.onFinished(
      RoundOutcome(
        accuracy: r.accuracy,
        perfect: r.perfect,
        message: r.mistakes == 0
            ? 'All ${p.pairs} pairs with no misses!'
            : '${p.pairs} pairs, ${r.mistakes} missed '
                  '${r.mistakes == 1 ? 'try' : 'tries'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = GameKind.flipMatch.accent;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Find the matching pairs',
          style: const TextStyle(fontSize: 20, color: NovaColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$foundPairs / ${p.pairs} found',
          key: const Key('pairs-found'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0, pad = 10.0;
            final size =
                ((constraints.maxWidth - pad * 2 - gap * (p.cols - 1)) / p.cols)
                    .clamp(44.0, 92.0);
            // The same green board and round 3D tokens as Flip Duel.
            return NovaBoardFrame(
              padding: const EdgeInsets.all(pad),
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < p.cards.length; i++)
                    NovaSlot(
                      size: size,
                      child: NovaToken(
                        key: Key('card-$i'),
                        faceUp: _faceUp(i),
                        removed: false,
                        matched: matched[i],
                        symbol: flipSymbols[p.cards[i]],
                        size: size,
                        label: 'Card ${i + 1}',
                        onTap: () => _flip(i),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
