import 'package:flutter/material.dart';

import '../models/blanket.dart';
import '../models/horse.dart';
import 'blanket_advisor.dart';

/// De deken (eventueel met onderdeken) uit je eigen dekenkast die het
/// best past bij het advies.
class BlanketPick {
  const BlanketPick({required this.main, this.under, required this.level});

  final Blanket main;
  final Blanket? under;
  final BlanketLevel level;

  int get grams => main.grams + (under?.grams ?? 0);
  bool get neck => main.neck || (under?.neck ?? false);
  Color get color => main.color;

  String get label => under == null ? main.name : '${main.name} + ${under!.name}';

  /// Valt het totale gewicht binnen het geadviseerde bereik?
  bool get matches => BlanketPicker.distance(level, grams) <= 50;

  /// Te licht (negatief) of te zwaar (positief) t.o.v. het advies.
  int get offset {
    final target = BlanketPicker.targetGrams(level);
    if (level == BlanketLevel.extraHeavy && grams >= 350) return 0;
    return grams - target;
  }
}

class BlanketPicker {
  const BlanketPicker._();

  /// Midden van het geadviseerde bereik in gram.
  static int targetGrams(BlanketLevel l) => switch (l) {
        BlanketLevel.none => 0,
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

  /// Kiest de best passende deken of combinatie voor dit paard.
  /// Geeft `null` als er geen deken nodig is of geen enkele deken past.
  static BlanketPick? pick(Horse horse, BlanketAdvice advice, List<Blanket> all) {
    if (!advice.level.wearsBlanket) return null;
    final mine = all.where((b) => b.fits(horse.id)).toList();
    var mains = mine.where((b) => b.kind.isMain).toList();
    if (advice.waterproof) {
      mains = mains.where((b) => b.waterproof).toList();
    }
    if (mains.isEmpty) return null;
    final unders = mine.where((b) => b.kind == BlanketKind.under).toList();

    final options = <BlanketPick>[
      for (final m in mains) BlanketPick(main: m, level: advice.level),
      if (advice.level.index >= BlanketLevel.light.index)
        for (final m in mains)
          for (final u in unders)
            BlanketPick(main: m, under: u, level: advice.level),
    ];

    double score(BlanketPick p) {
      var s = distance(advice.level, p.grams).toDouble();
      if (advice.neckCover && !p.neck) s += 30;
      if (!advice.neckCover && p.neck) s += 5;
      if (p.under != null) s += 20; // liever één deken dan twee lagen
      if (!advice.waterproof && p.main.kind != BlanketKind.stable) s += 10;
      return s;
    }

    options.sort((a, b) => score(a).compareTo(score(b)));
    return options.first;
  }
}
