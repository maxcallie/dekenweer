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
    this.sunny = 2,
    this.fullSun = 4,
    this.rainOnlyWet = defaultRainOnlyWet,
    this.flyRain = true,
    this.flyRainUpTo = defaultFlyRainUpTo,
    this.nightNone = defaultNightNone,
    this.blanketChanges = 1,
    this.dayStart = 9,
    this.dayEnd = 18,
  });

  /// Dekenwissels per dag: 0 = één deken voor het hele etmaal, 1 = een
  /// dagdeken en een nachtdeken.
  final int blanketChanges;

  /// Wisseltijden (uur): de dagdeken van [dayStart] tot [dayEnd], daarna de
  /// nachtdeken tot [dayStart] de volgende dag.
  final int dayStart;
  final int dayEnd;

  /// Per scheerstatus: 's nachts geen deken vanaf deze (gecorrigeerde)
  /// temperatuur. Daaronder gelden de normale grenzen.
  static const defaultNightNone = <double>[10, 10, 10];

  /// Per scheerstatus (niet / deels / volledig geschoren): regendeken alleen
  /// adviseren bij nat weer? Standaard alleen bij een ongeschoren paard, zoals
  /// het advies altijd werkte.
  static const defaultRainOnlyWet = <bool>[true, false, false];

  /// Per scheerstatus: tot welke (effectieve) temperatuur een vliegendeken
  /// met regenstuk wordt geadviseerd bij regen. De ondergrens is die van
  /// 'Geen deken'.
  static const defaultFlyRainUpTo = <double>[20, 20, 22];

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

  /// Hoeveel warmer het overdag voelt bij zon (deels zonnig) …
  final double sunny;

  /// … en bij volle zon.
  final double fullSun;

  final List<bool> rainOnlyWet;

  /// Vliegendeken met regenstuk meenemen in het advies?
  final bool flyRain;
  final List<double> flyRainUpTo;
  final List<double> nightNone;

  double nightNoneFor(ClipType clip) => nightNone[clip.index];

  AdviceSettings withNightNone(ClipType clip, double value) {
    final n = List<double>.of(nightNone);
    n[clip.index] = value.clamp(-40.0, 40.0);
    return copyWith(nightNone: n);
  }

  bool rainOnlyWetFor(ClipType clip) => rainOnlyWet[clip.index];
  double flyRainUpToFor(ClipType clip) => flyRainUpTo[clip.index];

  static const defaults = AdviceSettings();

  bool get isDefault =>
      _eq(unclipped, defaultUnclipped) &&
      _eq(partial, defaultPartial) &&
      _eq(full, defaultFull) &&
      windModerate == 2 &&
      windStrong == 4 &&
      wet == 3 &&
      stable == 5 &&
      sunny == 2 &&
      fullSun == 4 &&
      flyRain &&
      _eq(flyRainUpTo, defaultFlyRainUpTo) &&
      _eqB(rainOnlyWet, defaultRainOnlyWet) &&
      _eq(nightNone, defaultNightNone) &&
      blanketChanges == 1 &&
      dayStart == 9 &&
      dayEnd == 18;

  static bool _eqB(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
    // De bovengrens van de vliegendeken met regenstuk blijft boven 'Geen deken'.
    final up = List<double>.of(flyRainUpTo);
    up[clip.index] = math.max(up[clip.index], t[0] + 1);
    return copyWith(
      unclipped: clip == ClipType.none ? t : null,
      partial: clip == ClipType.partial ? t : null,
      full: clip == ClipType.full ? t : null,
      flyRainUpTo: up,
    );
  }

  /// Zet de bovengrens van de vliegendeken met regenstuk (minstens 1 °C
  /// boven 'Geen deken').
  AdviceSettings withFlyRainUpTo(ClipType clip, double value) {
    final up = List<double>.of(flyRainUpTo);
    up[clip.index] = math.max(math.min(value, 45.0), thresholdsFor(clip)[0] + 1);
    return copyWith(flyRainUpTo: up);
  }

  AdviceSettings withRainOnlyWet(ClipType clip, bool value) {
    final r = List<bool>.of(rainOnlyWet);
    r[clip.index] = value;
    return copyWith(rainOnlyWet: r);
  }

  AdviceSettings copyWith({
    List<double>? unclipped,
    List<double>? partial,
    List<double>? full,
    double? windModerate,
    double? windStrong,
    double? wet,
    double? stable,
    double? sunny,
    double? fullSun,
    List<bool>? rainOnlyWet,
    bool? flyRain,
    List<double>? flyRainUpTo,
    List<double>? nightNone,
    int? blanketChanges,
    int? dayStart,
    int? dayEnd,
  }) =>
      AdviceSettings(
        unclipped: unclipped ?? this.unclipped,
        partial: partial ?? this.partial,
        full: full ?? this.full,
        windModerate: windModerate ?? this.windModerate,
        windStrong: windStrong ?? this.windStrong,
        wet: wet ?? this.wet,
        stable: stable ?? this.stable,
        sunny: sunny ?? this.sunny,
        fullSun: fullSun ?? this.fullSun,
        rainOnlyWet: rainOnlyWet ?? this.rainOnlyWet,
        flyRain: flyRain ?? this.flyRain,
        flyRainUpTo: flyRainUpTo ?? this.flyRainUpTo,
        nightNone: nightNone ?? this.nightNone,
        blanketChanges: blanketChanges ?? this.blanketChanges,
        dayStart: dayStart ?? this.dayStart,
        dayEnd: dayEnd ?? this.dayEnd,
      );

  /// Wisseltijden aanpassen: dag begint tussen 4 en 12 uur, eindigt tussen
  /// 14 en 22 uur.
  AdviceSettings withDayTimes({int? start, int? end}) => copyWith(
        dayStart: (start ?? dayStart).clamp(4, 12),
        dayEnd: (end ?? dayEnd).clamp(14, 22),
      );

  Map<String, dynamic> toJson() => {
        'unclipped': unclipped,
        'partial': partial,
        'full': full,
        'windModerate': windModerate,
        'windStrong': windStrong,
        'wet': wet,
        'stable': stable,
        'sunny': sunny,
        'fullSun': fullSun,
        'rainOnlyWet': rainOnlyWet,
        'flyRain': flyRain,
        'flyRainUpTo': flyRainUpTo,
        'nightNone': nightNone,
        'blanketChanges': blanketChanges,
        'dayStart': dayStart,
        'dayEnd': dayEnd,
      };

  factory AdviceSettings.fromJson(Map<String, dynamic> j) {
    List<double> list(Object? v, List<double> fallback) {
      if (v is! List || v.length != fallback.length || v.any((x) => x is! num)) {
        return fallback;
      }
      return [for (final x in v) (x as num).toDouble()];
    }

    List<bool> bools(Object? v, List<bool> fallback) {
      if (v is! List || v.length != fallback.length || v.any((x) => x is! bool)) {
        return fallback;
      }
      return v.cast<bool>().toList();
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
      sunny: num_(j['sunny'], 2),
      fullSun: num_(j['fullSun'], 4),
    ).copyWith(
      // Nieuwe velden: oude opgeslagen instellingen krijgen de standaard.
      rainOnlyWet: bools(j['rainOnlyWet'], defaultRainOnlyWet),
      flyRain: j['flyRain'] is bool ? j['flyRain'] as bool : true,
      nightNone: list(j['nightNone'], defaultNightNone),
      blanketChanges: (j['blanketChanges'] as num?)?.toInt().clamp(0, 1) ?? 1,
      dayStart: (j['dayStart'] as num?)?.toInt().clamp(4, 12) ?? 9,
      dayEnd: (j['dayEnd'] as num?)?.toInt().clamp(14, 22) ?? 18,
    ).withFlyRainUpToList(list(j['flyRainUpTo'], defaultFlyRainUpTo));
  }

  /// Bovengrenzen overnemen, maar nooit onder 'Geen deken' + 1.
  AdviceSettings withFlyRainUpToList(List<double> up) {
    var s = this;
    for (final c in ClipType.values) {
      s = s.withFlyRainUpTo(c, up[c.index]);
    }
    return s;
  }
}
