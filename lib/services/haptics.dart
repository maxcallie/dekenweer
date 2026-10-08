import 'package:flutter/services.dart';

import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart' as impl;

/// Een licht tikje voelbaar bij het kiezen van iets.
///
/// In Safari op de iPhone kan een website niet zomaar trillen; de web-app
/// gebruikt daarvoor een truc die vanaf iOS 18 werkt (zie web/index.html).
/// Werkt het niet, dan gebeurt er gewoon niets.
class Haptics {
  Haptics._();

  static void select() {
    impl.haptic();
    HapticFeedback.selectionClick();
  }
}
