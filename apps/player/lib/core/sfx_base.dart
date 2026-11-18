/// Short synthesized sound effects. Implementations must never throw.
abstract class Sfx {
  void flip();
  void match();
  void miss();
  void win();
  void dispose() {}
}

/// Used where synthesized audio is not available (tests, mobile builds).
class SilentSfx extends Sfx {
  @override
  void flip() {}
  @override
  void match() {}
  @override
  void miss() {}
  @override
  void win() {}
}
