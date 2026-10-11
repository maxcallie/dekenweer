import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/blanket.dart';
import '../models/horse.dart';
import 'blanket_advisor.dart';

/// De deken (eventueel met onderdeken) uit je eigen dekenkast die het
/// best past bij het advies.
class BlanketPick {
  const BlanketPick({
    required this.main,
    this.under,
    required this.level,
    this.fit = 0,
    this.warning,
    this.rangeNote,
  });

  /// Bij een deken met eigen bereik die niet past, bijv.
  /// 'buiten ingesteld bereik (max 10 °C)'.
  final String? rangeNote;

  final Blanket main;
  final Blanket? under;
  final BlanketLevel level;

  /// −1 = te licht, 0 = past, +1 = te zwaar.
  final int fit;

  /// Waarschuwing, bijv. als de deken niet waterdicht is terwijl dat wel moet.
  final String? warning;

  int get grams => main.grams + (under?.grams ?? 0);
  bool get neck => main.neck || (under?.neck ?? false);
  Color get color => main.color;

  String get label => under == null ? main.name : '${main.name} + ${under!.name}';

  /// Past de deken bij het advies?
  bool get matches => fit == 0;

  /// Te licht (negatief) of te zwaar (positief) t.o.v. het advies.
  int get offset => fit;

  /// Korte melding als de deken niet precies past.
  String? get fitNote => rangeNote ?? switch (fit) {
        < 0 => under == null
            ? 'iets te licht, overweeg een fleece of onderdeken eronder'
            : 'iets te licht',
        > 0 => 'iets te zwaar, voel of je paard niet gaat zweten',
        _ => null,
      };
}

class BlanketPicker {
  const BlanketPicker._();

  /// Midden van het geadviseerde bereik in gram.
  static int targetGrams(BlanketLevel l) => switch (l) {
        BlanketLevel.none => 0,
        BlanketLevel.flyRain => 0,
        BlanketLevel.rainSheet => 0,
        BlanketLevel.light => 75,
        BlanketLevel.medium => 175,
        BlanketLevel.heavy => 275,
        BlanketLevel.extraHeavy => 375,
      };

  /// Bij welk dekengewicht hoort deze vulling?
  static BlanketLevel levelForGrams(int g) {
    if (g <= 0) return BlanketLevel.rainSheet;
    if (g <= 125) return BlanketLevel.light;
    if (g <= 225) return BlanketLevel.medium;
    if (g < 350) return BlanketLevel.heavy;
    return BlanketLevel.extraHeavy;
  }

  static int distance(BlanketLevel l, int grams) {
    if (l == BlanketLevel.extraHeavy) return grams >= 350 ? 0 : 350 - grams;
    return (grams - targetGrams(l)).abs();
  }

  /// Ongeveer hoeveel gram vulling één graad warmte is.
  static const gramsPerDegree = 17.0;

  /// Kiest de best passende deken of combinatie voor dit paard.
  /// Geeft `null` als er geen deken nodig is of geen enkele deken past.
  ///
  /// Dekens met een eigen temperatuurbereik worden vergeleken met de
  /// gevoelstemperatuur van het advies; de andere op hun vulling.
  static BlanketPick? pick(Horse horse, BlanketAdvice advice, List<Blanket> all) {
    if (!advice.level.wearsBlanket) return null;
    final mine = all.where((b) => b.fits(horse.id)).toList();
    if (advice.level == BlanketLevel.flyRain) {
      // Hiervoor telt alleen een vliegendeken (met regenstuk).
      final fly = mine.where((b) => b.kind == BlanketKind.fly).toList();
      if (fly.isEmpty) return null;
      int rank(Blanket b) => (b.waterproof ? 2 : 0) + (advice.sunnyWarm && b.sunProtect ? 1 : 0);
      fly.sort((a, b) => rank(b).compareTo(rank(a)));
      return BlanketPick(main: fly.first, level: advice.level);
    }
    var mains = mine.where((b) => b.kind.isMain).toList();
    if (mains.isEmpty) return null;
    // Buiten alleen waterdichte dekens, behalve als je die niet hebt.
    var notWaterproof = false;
    if (advice.waterproof) {
      final dry = mains.where((b) => b.waterproof).toList();
      if (dry.isEmpty) {
        notWaterproof = true;
      } else {
        mains = dry;
      }
    }
    final unders = mine.where((b) => b.kind == BlanketKind.under).toList();
    final eff = advice.effectiveTemp;

    // (fit, afstand): een deken met eigen bereik past alleen als de
    // temperatuur van het dagdeel binnen dat bereik ligt (grenzen tellen
    // mee); een deken zonder eigen bereik past als zijn warmteklasse gelijk
    // is aan het advies.
    (int, double) measure(Blanket m, Blanket? u) {
      if (m.hasOwnRange) {
        final extra = (u?.grams ?? 0) / gramsPerDegree;
        final lo = m.minTemp! - extra, hi = m.maxTemp! - extra;
        if (eff < lo) return (-1, (lo - eff) * gramsPerDegree);
        if (eff > hi) return (1, (eff - hi) * gramsPerDegree);
        return (0, 0);
      }
      final g = m.grams + (u?.grams ?? 0);
      final d = distance(advice.level, g).toDouble();
      final cls = levelForGrams(g);
      if (cls == advice.level) return (0, d);
      return (cls.index > advice.level.index ? 1 : -1, math.max(d, 1));
    }

    final options = <(Blanket, Blanket?)>[
      for (final m in mains) (m, null),
      if (advice.level.index >= BlanketLevel.light.index)
        for (final m in mains)
          for (final u in unders) (m, u),
    ];

    double score((Blanket, Blanket?) o) {
      final (m, u) = o;
      var s = measure(m, u).$2;
      final neck = m.neck || (u?.neck ?? false);
      if (advice.neckCover && !neck) s += 30;
      if (!advice.neckCover && neck) s += 5;
      if (u != null) s += 20; // liever één deken dan twee lagen
      if (!advice.waterproof && m.kind != BlanketKind.stable) s += 10;
      // Zon en warm: een zonwerende deken gaat voor.
      if (advice.sunnyWarm && m.sunProtect) s -= 25;
      return s;
    }

    // Eerst alleen dekens die passen; past er geen, dan de dichtstbijzijnde.
    final fitting = options.where((o) => measure(o.$1, o.$2).$1 == 0).toList();
    final pool = fitting.isNotEmpty ? fitting : options;
    pool.sort((a, b) => score(a).compareTo(score(b)));
    final (m, u) = pool.first;
    final fit = measure(m, u).$1;
    return BlanketPick(
      main: m,
      under: u,
      level: advice.level,
      fit: fit,
      rangeNote: m.hasOwnRange && fit != 0
          ? 'buiten ingesteld bereik '
              '(${fit > 0 ? 'max ${m.maxTemp!.round()}' : 'min ${m.minTemp!.round()}'} °C)'
          : null,
      warning: notWaterproof
          ? advice.wet
              ? 'Let op: het regent en je hebt geen waterdichte deken. '
                  '${m.name} is niet waterdicht.'
              : 'Let op: ${m.name} is niet waterdicht. Buiten is een waterdichte '
                  'deken beter.'
          : null,
    );
  }
}
