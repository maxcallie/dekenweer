import 'dart:js_interop';

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external _Audio(String src);
  external set volume(double v);
  external set playbackRate(double v);
  external set preservesPitch(bool v);
  external JSPromise<JSAny?> play();
}

/// Speelt een geluidsbestand af (pad relatief aan de web-app).
void playSound(String src, {double rate = 1}) {
  try {
    final a = _Audio(src)
      ..volume = 0.7
      ..preservesPitch = false
      ..playbackRate = rate;
    a.play().toDart.then((_) {}, onError: (_) {});
  } catch (_) {
    // geen geluid is geen ramp
  }
}

@JS('dekenweerHaptic')
external void _haptic();

/// Licht tikje (iOS 18+ via een verborgen schakelaar, Android via vibrate).
void haptic() {
  try {
    _haptic();
  } catch (_) {}
}
