import 'dart:math' as math;

import 'horse.dart';

/// Instelbare getallen achter het dekenadvies.
///
/// Per scheerstatus (niet / deels / volledig geschoren) is er een rij
/// ondergrenzen, van warm naar koud:
///
///   geen deken  ≥ t[0]
///   vliegendeken met regenstuk  ≥ [flyFrom]  (tussen regendeken en geen deken)
///   regendeken  ≥ t[1]
///   lichte deken ≥ t[2], middel ≥ t[3], zwaar ≥ t[4], daaronder extra zwaar.
///
/// 's Nachts gelden daarboven nog twee eigen grenzen: [nightNone] en
/// [nightFly]. Onder [nightFly] gelden de normale grenzen.
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
    this.flyFrom = defaultFlyFrom,
    this.flyOnlyWet = defaultFlyOnlyWet,
    this.nightNone = defaultNightNone,
    this.nightFly = defaultNightFly,
    this.blanketChanges = 1,
    this.dayStart = 9,
    this.dayEnd = 18,
  });

  // ---- Standaardwaarden -------------------------------------------------

  // Ondergrenzen (°C) voor resp. geen deken, regendeken, licht, middel en
  // zwaar. Daaronder: extra zwaar.
  static const defaultUnclipped = <double>[20, 10, 5, 0, -7];
  static const defaultPartial = <double>[20, 10, 5, 0, -7];
  static const defaultFull = <double>[22, 14, 9, 3, -3];

  /// Vliegendeken met regenstuk vanaf (per scheerstatus).
  static const defaultFlyFrom = <double>[15, 15, 18];

  /// Vliegendeken alleen bij regen?
  static const defaultFlyOnlyWet = <bool>[false, true, true];

  /// Regendeken alleen bij nat weer?
  static const defaultRainOnlyWet = <bool>[false, false, false];

  /// 's Nachts: geen deken vanaf …
  static const defaultNightNone = <double>[15, 10, 10];

  /// … en vliegendeken met regenstuk vanaf.
  static const defaultNightFly = <double>[10, 10, 10];

  // ---- Velden -------------------------------------------------------------

  final List<double> unclipped;
  final List<double> partial;
  final List<double> full;

  /// Hoeveel graden er af gaat bij wind vanaf 20 km/u.
  final double windModerate;

  /// … en bij harde wind vanaf 35 km/u.
  final double windStrong;

  /// … bij regen of sneeuw.
  final double wet;

  /// Hoeveel warmer het op stal is.
  final double stable;

  /// Hoeveel er overdag bij komt bij zon (deels zonnig) …
  final double sunny;

  /// … en bij volle zon.
  final double fullSun;

  final List<bool> rainOnlyWet;

  /// Vliegendeken met regenstuk meenemen in het advies?
  final bool flyRain;
  final List<double> flyFrom;
  final List<bool> flyOnlyWet;

  final List<double> nightNone;
  final List<double> nightFly;

  /// Dekenwissels per dag: 0 = één deken voor het hele etmaal, 1 = een
  /// dagdeken en een nachtdeken.
  final int blanketChanges;

  /// Wisseltijden (uur): de dagdeken van [dayStart] tot [dayEnd], daarna de
  /// nachtdeken tot [dayStart] de volgende dag.
  final int dayStart;
  final int dayEnd;

  static const defaults = AdviceSettings();

  List<double> thresholdsFor(ClipType clip) => switch (clip) {
        ClipType.none => unclipped,
        ClipType.partial => partial,
        ClipType.full => full,
      };

  bool rainOnlyWetFor(ClipType clip) => rainOnlyWet[clip.index];
  double flyFromFor(ClipType clip) => flyFrom[clip.index];
  bool flyOnlyWetFor(ClipType clip) => flyOnlyWet[clip.index];
  double nightNoneFor(ClipType clip) => nightNone[clip.index];
  double nightFlyFor(ClipType clip) => nightFly[clip.index];

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
      _eq(flyFrom, defaultFlyFrom) &&
      _eqB(flyOnlyWet, defaultFlyOnlyWet) &&
      _eqB(rainOnlyWet, defaultRainOnlyWet) &&
      _eq(nightNone, defaultNightNone) &&
      _eq(nightFly, defaultNightFly) &&
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

  // ---- Aanpassen ------------------------------------------------------------

  /// Past één grens aan en houdt de rij aflopend (minstens 1 °C verschil).
  /// De ondergrens van de vliegendeken blijft tussen regendeken en geen deken.
  AdviceSettings withThreshold(ClipType clip, int index, double value) {
    final t = List<double>.of(thresholdsFor(clip));
    t[index] = value.clamp(-40.0, 45.0);
    for (var j = index + 1; j < t.length; j++) {
      t[j] = math.min(t[j], t[j - 1] - 1);
    }
    for (var j = index - 1; j >= 0; j--) {
      t[j] = math.max(t[j], t[j + 1] + 1);
    }
    final f = List<double>.of(flyFrom);
    f[clip.index] = f[clip.index].clamp(t[1], t[0]);
    return copyWith(
      unclipped: clip == ClipType.none ? t : null,
      partial: clip == ClipType.partial ? t : null,
      full: clip == ClipType.full ? t : null,
      flyFrom: f,
    );
  }

  /// 'Vliegendeken vanaf'. Duwt zo nodig 'Geen deken' omhoog of 'Regendeken'
  /// omlaag, zodat de volgorde klopt.
  AdviceSettings withFlyFrom(ClipType clip, double value) {
    final v = value.clamp(-38.0, 44.0);
    var s = this;
    final t = thresholdsFor(clip);
    if (v > t[0]) s = s.withThreshold(clip, 0, v);
    if (v < s.thresholdsFor(clip)[1]) s = s.withThreshold(clip, 1, v);
    final f = List<double>.of(s.flyFrom);
    f[clip.index] = v;
    return s.copyWith(flyFrom: f);
  }

  AdviceSettings withFlyOnlyWet(ClipType clip, bool value) {
    final r = List<bool>.of(flyOnlyWet);
    r[clip.index] = value;
    return copyWith(flyOnlyWet: r);
  }

  AdviceSettings withRainOnlyWet(ClipType clip, bool value) {
    final r = List<bool>.of(rainOnlyWet);
    r[clip.index] = value;
    return copyWith(rainOnlyWet: r);
  }

  /// 's Nachts geen deken vanaf; de nachtgrens voor de vliegendeken blijft
  /// er op of onder.
  AdviceSettings withNightNone(ClipType clip, double value) {
    final n = List<double>.of(nightNone);
    final f = List<double>.of(nightFly);
    n[clip.index] = value.clamp(-40.0, 40.0);
    f[clip.index] = math.min(f[clip.index], n[clip.index]);
    return copyWith(nightNone: n, nightFly: f);
  }

  /// 's Nachts vliegendeken vanaf; 'geen deken 's nachts' blijft er op of boven.
  AdviceSettings withNightFly(ClipType clip, double value) {
    final n = List<double>.of(nightNone);
    final f = List<double>.of(nightFly);
    f[clip.index] = value.clamp(-40.0, 40.0);
    n[clip.index] = math.max(n[clip.index], f[clip.index]);
    return copyWith(nightNone: n, nightFly: f);
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
    List<double>? flyFrom,
    List<bool>? flyOnlyWet,
    List<double>? nightNone,
    List<double>? nightFly,
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
        flyFrom: flyFrom ?? this.flyFrom,
        flyOnlyWet: flyOnlyWet ?? this.flyOnlyWet,
        nightNone: nightNone ?? this.nightNone,
        nightFly: nightFly ?? this.nightFly,
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

  // ---- Opslaan ------------------------------------------------------------

  /// Versie van het opslagformaat. 2: vliegendeken als eigen laag onder
  /// 'Geen deken', met eigen nachtgrenzen.
  static const version = 2;

  Map<String, dynamic> toJson() => {
        'v': version,
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
        'flyFrom': flyFrom,
        'flyOnlyWet': flyOnlyWet,
        'nightNone': nightNone,
        'nightFly': nightFly,
        'blanketChanges': blanketChanges,
        'dayStart': dayStart,
        'dayEnd': dayEnd,
      };

  // Oude standaardwaarden (opslagformaat 1), om te herkennen of iemand ze
  // nooit had aangepast.
  static const _oldDefaults = [
    <double>[8, 3, -3, -10, -18],
    <double>[15, 10, 5, 0, -7],
    <double>[18, 14, 9, 3, -3],
  ];
  static const _oldFlyUpTo = <double>[20, 20, 22];
  static const _oldRainOnlyWet = <bool>[true, false, false];

  factory AdviceSettings.fromJson(Map<String, dynamic> j) {
    List<double>? listOrNull(Object? v, int length) {
      if (v is! List || v.length != length || v.any((x) => x is! num)) return null;
      return [for (final x in v) (x as num).toDouble()];
    }

    List<double> list(Object? v, List<double> fallback) =>
        listOrNull(v, fallback.length) ?? fallback;

    List<bool>? boolsOrNull(Object? v) {
      if (v is! List || v.length != 3 || v.any((x) => x is! bool)) return null;
      return v.cast<bool>().toList();
    }

    double num_(Object? v, double fallback) => (v as num?)?.toDouble() ?? fallback;

    final common = AdviceSettings(
      windModerate: num_(j['windModerate'], 2),
      windStrong: num_(j['windStrong'], 4),
      wet: num_(j['wet'], 3),
      stable: num_(j['stable'], 5),
      sunny: num_(j['sunny'], 2),
      fullSun: num_(j['fullSun'], 4),
      flyRain: j['flyRain'] is bool ? j['flyRain'] as bool : true,
      blanketChanges: (j['blanketChanges'] as num?)?.toInt().clamp(0, 1) ?? 1,
      dayStart: (j['dayStart'] as num?)?.toInt().clamp(4, 12) ?? 9,
      dayEnd: (j['dayEnd'] as num?)?.toInt().clamp(14, 22) ?? 18,
    );

    if ((j['v'] as num?) != null && (j['v'] as num) >= 2) {
      return common.copyWith(
        unclipped: list(j['unclipped'], defaultUnclipped),
        partial: list(j['partial'], defaultPartial),
        full: list(j['full'], defaultFull),
        rainOnlyWet: boolsOrNull(j['rainOnlyWet']) ?? defaultRainOnlyWet,
        flyFrom: list(j['flyFrom'], defaultFlyFrom),
        flyOnlyWet: boolsOrNull(j['flyOnlyWet']) ?? defaultFlyOnlyWet,
        nightNone: list(j['nightNone'], defaultNightNone),
        nightFly: list(j['nightFly'], defaultNightFly),
      );
    }

    // Oud formaat: de vliegendeken (alleen bij regen) lag tussen 'Geen deken'
    // en een eigen bovengrens. Zet dat om naar de nieuwe rij, zodat het advies
    // hetzelfde blijft. Wie de standaard nooit had aangepast, krijgt de nieuwe
    // standaard.
    final oldT = [
      list(j['unclipped'], _oldDefaults[0]),
      list(j['partial'], _oldDefaults[1]),
      list(j['full'], _oldDefaults[2]),
    ];
    final oldUp = list(j['flyRainUpTo'], _oldFlyUpTo);
    final oldRain = boolsOrNull(j['rainOnlyWet']) ?? _oldRainOnlyWet;
    final oldNight = list(j['nightNone'], const [10, 10, 10]);

    final t = <List<double>>[];
    final flyFrom = <double>[];
    final flyOnly = <bool>[];
    final rainOnly = <bool>[];
    final nNone = <double>[];
    final nFly = <double>[];
    for (final c in ClipType.values) {
      final i = c.index;
      final untouched = _eq(oldT[i], _oldDefaults[i]) &&
          oldUp[i] == _oldFlyUpTo[i] &&
          oldRain[i] == _oldRainOnlyWet[i] &&
          oldNight[i] == 10;
      if (untouched) {
        t.add(switch (c) {
          ClipType.none => defaultUnclipped,
          ClipType.partial => defaultPartial,
          ClipType.full => defaultFull,
        });
        flyFrom.add(defaultFlyFrom[i]);
        flyOnly.add(defaultFlyOnlyWet[i]);
        rainOnly.add(defaultRainOnlyWet[i]);
        nNone.add(defaultNightNone[i]);
        nFly.add(defaultNightFly[i]);
      } else {
        final up = math.max(oldUp[i], oldT[i][0] + 1);
        t.add([up, ...oldT[i].skip(1)]);
        flyFrom.add(oldT[i][0]);
        flyOnly.add(true);
        rainOnly.add(oldRain[i]);
        nNone.add(oldNight[i]);
        nFly.add(oldNight[i]);
      }
    }
    return common.copyWith(
      unclipped: t[0],
      partial: t[1],
      full: t[2],
      flyFrom: flyFrom,
      flyOnlyWet: flyOnly,
      rainOnlyWet: rainOnly,
      nightNone: nNone,
      nightFly: nFly,
    );
  }
}
