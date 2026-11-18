import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/rules/flip_match.dart';

// Colours of the plastic board game: green board, purple token backs. Shared
// by every game that uses the tactile board look.
const novaBoardLight = Color(0xFF4FD18B);
const novaBoardDark = Color(0xFF1E9E63);
const novaRecess = Color(0xFF137A4C);
const _tokenLight = Color(0xFFA97CFF);
const _tokenDark = Color(0xFF5B34B8);
const _cream = Color(0xFFFFF8E7);

/// The rounded green plastic board with a soft 3D shadow.
class NovaBoardFrame extends StatelessWidget {
  const NovaBoardFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.radius = 26,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [novaBoardLight, novaBoardDark],
      ),
      border: Border.all(color: const Color(0xFF8CF0BC), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 14,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// The recessed round hole a token sits in.
class NovaSlot extends StatelessWidget {
  const NovaSlot({super.key, required this.size, this.child});
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF1B9560), novaRecess],
              stops: [.55, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x55FFFFFF),
                blurRadius: 1,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          child: SizedBox.expand(),
        ),
        ?child,
      ],
    ),
  );
}

/// A round token: purple "?" back, cartoon front, 3D flip, tap bounce, and a
/// shrink-away when its pair is taken off the board.
class NovaToken extends StatefulWidget {
  const NovaToken({
    super.key,
    required this.faceUp,
    required this.removed,
    required this.symbol,
    required this.size,
    required this.label,
    required this.onTap,
    this.matched = false,
  });
  final bool faceUp, removed;

  /// A found pair that stays on the board: gets an accent ring and a tick.
  final bool matched;
  final FlipSymbol symbol;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  State<NovaToken> createState() => _NovaTokenState();
}

class _NovaTokenState extends State<NovaToken>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.faceUp ? 1 : 0,
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(NovaToken old) {
    super.didUpdateWidget(old);
    if (widget.faceUp != old.faceUp) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _flip.value = widget.faceUp ? 1 : 0;
      } else {
        widget.faceUp ? _flip.forward() : _flip.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Widget _back() => _disc(
    gradient: const RadialGradient(
      center: Alignment(-.3, -.4),
      colors: [_tokenLight, _tokenDark],
    ),
    ring: const Color(0xFFC9AEFF),
    child: Text(
      '?',
      style: TextStyle(
        fontSize: widget.size * .52,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1,
      ),
    ),
  );

  Widget _front() => _disc(
    gradient: const RadialGradient(
      center: Alignment(-.3, -.4),
      colors: [Colors.white, _cream],
    ),
    ring: widget.matched ? const Color(0xFF2BD98B) : const Color(0xFFFFD27A),
    child: Text(
      widget.symbol.emoji,
      style: TextStyle(fontSize: widget.size * .55, height: 1),
    ),
  );

  Widget _disc({
    required Gradient gradient,
    required Color ring,
    required Widget child,
  }) => Container(
    width: widget.size * .9,
    height: widget.size * .9,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: gradient,
      border: Border.all(color: ring, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 4,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: widget.removed,
      child: AnimatedScale(
        scale: widget.removed ? 0 : (_pressed ? .9 : 1),
        duration: Duration(
          milliseconds: reduce ? 0 : (widget.removed ? 260 : 90),
        ),
        curve: widget.removed ? Curves.easeInBack : Curves.easeOut,
        child: Semantics(
          button: true,
          label: widget.faceUp
              ? '${widget.label}: ${widget.symbol.name}'
              : '${widget.label}, face down',
          excludeSemantics: true,
          onTap: widget.onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            // The whole slot is the tap target; the disc is a little smaller.
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) {
                    final v = _flip.value;
                    final showFront = v > .5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015) // perspective
                        ..rotateY(pi * v),
                      child: showFront
                          // Mirror the front so it reads correctly after the turn.
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: _front(),
                            )
                          : _back(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short burst of coloured dots from each matched tile.
class NovaBurst extends StatefulWidget {
  const NovaBurst({
    super.key,
    required this.centers,
    required this.radius,
    required this.onDone,
  });
  final List<Offset> centers;
  final double radius;
  final VoidCallback onDone;

  @override
  State<NovaBurst> createState() => _NovaBurstState();
}

class _NovaBurstState extends State<NovaBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _NovaBurstPainter(widget.centers, widget.radius, _c.value),
      ),
    );
  }
}

class _NovaBurstPainter extends CustomPainter {
  _NovaBurstPainter(this.centers, this.radius, this.t);
  final List<Offset> centers;
  final double radius, t;
  static const _colors = [
    Color(0xFFFFD27A),
    Color(0xFFFF8D9B),
    Color(0xFF7AA9FF),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    for (final c in centers) {
      for (var k = 0; k < 10; k++) {
        final a = k * 2 * pi / 10;
        final p = c + Offset(cos(a), sin(a)) * (radius * ease);
        canvas.drawCircle(
          p,
          (1 - t) * 4 + .5,
          Paint()..color = _colors[k % _colors.length].withValues(alpha: 1 - t),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NovaBurstPainter old) => old.t != t;
}
