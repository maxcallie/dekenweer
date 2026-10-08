import 'dart:math' as math;

import '../models/horse.dart';
import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart' as impl;

/// Geluidjes in de app. Werkt in de web-app (iPhone/iPad via Safari); in
/// tests en andere omgevingen gebeurt er niets.
class HorseSounds {
  HorseSounds._();

  static final _rand = math.Random();

  /// Laat [horse] snuiven of hinniken (willekeurig). Geeft `true` terug als
  /// het een hinnik was. Pony's klinken iets hoger, koudbloeden iets lager.
  static bool greet(Horse horse) {
    final whinny = _rand.nextDouble() < 0.4;
    final rate = switch (horse.type) {
      HorseType.pony => 1.12,
      HorseType.coldblood => 0.92,
      HorseType.hotblood => 1.04,
      _ => 1.0,
    };
    // kleine variatie per paard, zodat ze niet allemaal hetzelfde klinken
    final jitter = (horse.id.hashCode % 5 - 2) * 0.015;
    impl.playSound(whinny ? 'sounds/hinnik.mp3' : 'sounds/snuif.mp3',
        rate: rate + jitter);
    return whinny;
  }
}
