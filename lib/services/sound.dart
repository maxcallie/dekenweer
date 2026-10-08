import '../models/horse.dart';
import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart' as impl;

/// Geluidjes in de app. Werkt in de web-app (iPhone/iPad via Safari); in
/// tests en andere omgevingen gebeurt er niets.
class HorseSounds {
  HorseSounds._();

  /// Laat [horse] zacht snuiven. Pony's klinken hoger, koudbloeden lager.
  static void snort(Horse horse) {
    final rate = switch (horse.type) {
      HorseType.pony => 1.25,
      HorseType.coldblood => 0.85,
      HorseType.hotblood => 1.08,
      _ => 1.0,
    };
    // kleine variatie per paard, zodat ze niet allemaal hetzelfde klinken
    final jitter = (horse.id.hashCode % 7 - 3) * 0.02;
    impl.playSound('sounds/snuif.mp3', rate: rate + jitter);
  }
}
