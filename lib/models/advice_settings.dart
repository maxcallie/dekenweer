import 'dart:math' as math;

import 'horse.dart';

/// Instelbare getallen achter het dekenadvies.
class AdviceSettings {
  const AdviceSettings({
    this.unclipped = defaultUnclipped,
    this.partial = defaultPartial,
    this.full = defaultFull,
    this.windModerate = 2,
    this.windStrong = 4,
    this.wet = 3,
    this.stable = 5,
  });

  // Ondergrenzen (°C, effectieve temperatuur) voor resp. geen deken,
  // regendeken, licht, middel en zwaar. Daaronder: extra zwaar.
  static const defaultUnclipped = <double>[8, 3, -3, -10, -18];
  static const defaultPartial = <double>[15, 10, 5, 0, -7];
  static const defaultFull = <double>[18, 14, 9, 3, -3];

  final List<double> unclipped;
  final List<double> partial;
  final List<double> full;

  /// Hoeveel graden het kouder voelt bij wind vanaf 20 km/u.
  final double windModerate;

  /// … en bij harde wind vanaf 35 km/u.
  final double windStrong;

  /// … bij regen of sneeuw.
  final double wet;

  /// Hoeveel warmer het 's nachts op stal is.
  final double stable;

  static const defaults = AdviceSettings();

  bool get isDefault =>
      _eq(unclipped, defaultUnclipped) &&
      _eq(partial, defaultPartial) &&
      _eq(full, defaultFull) &&
      windModerate == 2 &&
      windStrong == 4 &&
      wet == 3 &&
      stable == 5;

  static bool _eq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<double> thresholdsFor(ClipType clip) => switch (clip) {
        ClipType.none => unclipped,
        ClipType.partial => partial,
        ClipType.full => full,
      };

  /// Past één grens aan en houdt de rij aflopend (minstens 1 °C verschil).
  AdviceSettings withThreshold(ClipType clip, int index, double value) {
    final t = List<double>.of(thresholdsFor(clip));
    t[index] = value.clamp(-40.0, 40.0);
    for (var j = index + 1; j < t.length; j++) {
      t[j] = math.min(t[j], t[j - 1] - 1);
    }
    for (var j = index - 1; j >= 0; j--) {
      t[j] = math.max(t[j], t[j + 1] + 1);
    }
    return copyWith(
      unclipped: clip == ClipType.none ? t : null,
      partial: clip == ClipType.partial ? t : null,
      full: clip == ClipType.full ? t : null,
    );
  }

  AdviceSettings copyWith({
    List<double>? unclipped,
    List<double>? partial,
    List<double>? full,
    double? windModerate,
    double? windStrong,
    double? wet,
    double? stable,
  }) =>
      AdviceSettings(
        unclipped: unclipped ?? this.unclipped,
        partial: partial ?? this.partial,
        full: full ?? this.full,
        windModerate: windModerate ?? this.windModerate,
        windStrong: windStrong ?? this.windStrong,
        wet: wet ?? this.wet,
        stable: stable ?? this.stable,
      );

  Map<String, dynamic> toJson() => {
        'unclipped': unclipped,
        'partial': partial,
        'full': full,
        'windModerate': windModerate,
        'windStrong': windStrong,
        'wet': wet,
        'stable': stable,
      };

  factory AdviceSettings.fromJson(Map<String, dynamic> j) {
    List<double> list(Object? v, List<double> fallback) {
      if (v is! List || v.length != 5) return fallback;
      return [for (final x in v) (x as num).toDouble()];
    }

    double num_(Object? v, double fallback) => (v as num?)?.toDouble() ?? fallback;

    return AdviceSettings(
      unclipped: list(j['unclipped'], defaultUnclipped),
      partial: list(j['partial'], defaultPartial),
      full: list(j['full'], defaultFull),
      windModerate: num_(j['windModerate'], 2),
      windStrong: num_(j['windStrong'], 4),
      wet: num_(j['wet'], 3),
      stable: num_(j['stable'], 5),
    );
  }
}
