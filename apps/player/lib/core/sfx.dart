import 'sfx_base.dart';
import 'sfx_stub.dart' if (dart.library.js_interop) 'sfx_web.dart' as platform;

export 'sfx_base.dart';

/// Web builds synthesize sounds with the Web Audio API (no audio files);
/// every other platform gets a silent implementation.
Sfx createSfx() => platform.createPlatformSfx();
