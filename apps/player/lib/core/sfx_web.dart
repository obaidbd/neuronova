import 'dart:js_interop';

import 'sfx_base.dart';

// Minimal Web Audio bindings: just what the sound effects need.
@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external double get currentTime;
  external String get state;
  external _Node get destination;
  external _Osc createOscillator();
  external _Gain createGain();
  external JSPromise<JSAny?> resume();
}

extension type _Node._(JSObject _) implements JSObject {}

extension type _Param._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double v, double t);
  external void exponentialRampToValueAtTime(double v, double t);
}

extension type _Osc._(JSObject _) implements _Node {
  external set type(String t);
  external _Param get frequency;
  external void connect(_Node n);
  external void start(double t);
  external void stop(double t);
}

extension type _Gain._(JSObject _) implements _Node {
  external _Param get gain;
  external void connect(_Node n);
}

Sfx createPlatformSfx() => _WebSfx();

class _WebSfx extends Sfx {
  _Ctx? _ctx;

  /// Browsers only allow audio after a tap; the first sound is always played
  /// from a tap handler, so the context is created (and resumed) lazily here.
  _Ctx? _context() {
    try {
      final c = _ctx ??= _Ctx();
      if (c.state == 'suspended') c.resume();
      return c;
    } catch (_) {
      return null; // audio unsupported: stay silent
    }
  }

  /// One soft note: [freq] Hz for [dur] seconds starting [delay] seconds
  /// from now, with a quick attack and an exponential fade-out.
  void _note(
    double freq,
    double dur, {
    double delay = 0,
    String wave = 'sine',
    double volume = .18,
    double? slideTo,
  }) {
    final c = _context();
    if (c == null) return;
    try {
      final t = c.currentTime + delay;
      final osc = c.createOscillator()..type = wave;
      final gain = c.createGain();
      osc.frequency.setValueAtTime(freq, t);
      if (slideTo != null) {
        osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
      }
      gain.gain.setValueAtTime(.0001, t);
      gain.gain.exponentialRampToValueAtTime(volume, t + .015);
      gain.gain.exponentialRampToValueAtTime(.0001, t + dur);
      osc.connect(gain);
      gain.connect(c.destination);
      osc.start(t);
      osc.stop(t + dur + .02);
    } catch (_) {}
  }

  @override
  void flip() => _note(520, .09, wave: 'triangle', volume: .14, slideTo: 760);

  @override
  void match() {
    // Rising C-E-G arpeggio.
    _note(523.25, .16, wave: 'triangle');
    _note(659.25, .16, delay: .1, wave: 'triangle');
    _note(783.99, .28, delay: .2, wave: 'triangle');
  }

  @override
  void miss() {
    // Two soft, falling notes.
    _note(260, .18, wave: 'sine', slideTo: 200);
    _note(196, .28, delay: .16, wave: 'sine', slideTo: 150);
  }

  @override
  void win() {
    // Short fanfare: C-E-G-C and a held chord.
    const notes = [523.25, 659.25, 783.99, 1046.5];
    for (var i = 0; i < notes.length; i++) {
      _note(notes[i], .2, delay: i * .13, wave: 'triangle');
    }
    _note(523.25, .7, delay: .55, wave: 'triangle', volume: .12);
    _note(659.25, .7, delay: .55, wave: 'triangle', volume: .12);
    _note(783.99, .7, delay: .55, wave: 'triangle', volume: .12);
  }

  @override
  void dispose() {
    _ctx = null;
  }
}
