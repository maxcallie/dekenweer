import 'package:flutter/material.dart';

import '../models/advice_settings.dart';
import '../models/horse.dart';
import '../models/weather.dart';

enum BlanketLevel {
  none('Geen deken', '—', Color(0xFF6E9B5A)),
  rainSheet('Regendeken', '0 g', Color(0xFF5B9BC8)),
  light('Lichte deken', '50–100 g', Color(0xFFD8B33F)),
  medium('Middelzware deken', '150–200 g', Color(0xFFE08A3C)),
  heavy('Zware deken', '250–300 g', Color(0xFFC8553D)),
  extraHeavy('Extra zware deken', '350 g+', Color(0xFF7D4A9E));

  const BlanketLevel(this.label, this.grams, this.color);
  final String label;
  final String grams;
  final Color color;

  bool get wearsBlanket => this != BlanketLevel.none;
}

class BlanketAdvice {
  const BlanketAdvice({
    required this.level,
    required this.effectiveTemp,
    required this.baseTemp,
    required this.neckCover,
    required this.waterproof,
    required this.reasons,
    required this.notes,
    this.inside = false,
    this.userChoice = false,
    this.advisedLevel,
    this.choiceBlanketId,
  });

  final BlanketLevel level;

  /// Staat het paard in deze periode op stal?
  final bool inside;

  /// Is [level] jouw vaste keuze voor op stal (in plaats van het advies)?
  final bool userChoice;

  /// Wat het advies zelf was (alleen gezet bij [userChoice]).
  final BlanketLevel? advisedLevel;

  /// De gekozen deken uit de dekenkast (bij [userChoice]; null = geen deken).
  final String? choiceBlanketId;

  /// Vervangt het advies door jouw vaste keuze voor op stal.
  BlanketAdvice withStableChoice({
    required BlanketLevel level,
    required bool neckCover,
    String? blanketId,
    required String description,
  }) =>
      BlanketAdvice(
        level: level,
        effectiveTemp: effectiveTemp,
        baseTemp: baseTemp,
        neckCover: neckCover,
        waterproof: false,
        reasons: reasons,
        notes: [
          'Dit is je vaste keuze voor op stal: $description. Het advies zou zijn: '
              '${this.level.label.toLowerCase()}'
              '${this.level.wearsBlanket ? ' (${this.level.grams})' : ''}.',
          ...notes,
        ],
        inside: true,
        userChoice: true,
        advisedLevel: this.level,
        choiceBlanketId: blanketId,
      );

  /// "Gevoelstemperatuur" voor dit paard na alle correcties.
  final double effectiveTemp;

  /// De temperatuur waar de berekening mee begon.
  final double baseTemp;
  final bool neckCover;
  final bool waterproof;

  /// Waarom het advies zo uitvalt (korte labels).
  final List<String> reasons;

  /// Extra aandachtspunten.
  final List<String> notes;

  String get title {
    if (!level.wearsBlanket) return level.label;
    final extras = [
      if (neckCover) 'met halsstuk',
    ];
    return extras.isEmpty ? level.label : '${level.label} ${extras.join(' ')}';
  }

  String get subtitle {
    if (!level.wearsBlanket) return 'Je paard redt zich prima met zijn eigen vacht';
    final parts = [
      level.grams,
      if (waterproof) 'waterdicht' else 'staldeken mag ook',
    ];
    return parts.join(' · ');
  }
}

/// Bepaalt welk dekengewicht past bij het weer en dit specifieke paard.
///
/// Uitgangspunt is de temperatuur in de periode (koudste moment 's nachts,
/// gemiddelde overdag). Daarop corrigeren we voor wind, nat weer en de
/// eigenschappen van het paard. De uitkomst ("effectieve temperatuur")
/// zoeken we op in een tabel die afhangt van hoe het paard geschoren is.
class BlanketAdvisor {
  const BlanketAdvisor([this.settings = AdviceSettings.defaults]);

  final AdviceSettings settings;

  /// [inside]: staat het paard in deze periode op stal (volgens het
  /// stalschema)? Dan telt de stal als warmer en spelen wind en regen geen rol.
  BlanketAdvice advise(Horse horse, PeriodWeather w,
      {bool inside = false, DateTime? now}) {
    final reasons = <String>[];
    final notes = <String>[];

    final stabled = inside;
    final shelter = !inside && horse.housing == Housing.shelter;

    final base = w.isNight ? w.minTemp : (w.minTemp + w.avgTemp) / 2;
    var eff = base;

    // --- Weer ---------------------------------------------------------
    var wetPenalty = 0.0;
    var windPenalty = 0.0;
    if (!stabled) {
      if (w.maxWind >= 35) {
        windPenalty = settings.windStrong;
      } else if (w.maxWind >= 20) {
        windPenalty = settings.windModerate;
      }
      if (w.isWet) wetPenalty = settings.wet;
      if (shelter) {
        windPenalty /= 2;
        wetPenalty /= 2;
      }
    }
    if (windPenalty > 0) {
      eff -= windPenalty;
      reasons.add('Wind ${w.maxWind.round()} km/u');
    }
    if (wetPenalty > 0) {
      eff -= wetPenalty;
      reasons.add(w.kind == WeatherKind.snow ? 'Sneeuw' : 'Nat weer');
    }
    if (stabled) {
      eff += settings.stable;
      reasons.add('Op stal');
    } else if (shelter && (windPenalty > 0 || wetPenalty > 0)) {
      reasons.add('Schuilstal');
    }

    // --- Paard --------------------------------------------------------
    switch (horse.type) {
      case HorseType.pony:
      case HorseType.coldblood:
        eff += 3;
        reasons.add(horse.type.label);
      case HorseType.hotblood:
        eff -= 2;
        reasons.add(horse.type.label);
      case HorseType.warmblood:
      case HorseType.baroque:
        break;
    }
    if (horse.age >= 20) {
      eff -= 2;
      reasons.add('Senior');
    } else if (horse.age <= 2) {
      eff -= 1;
      reasons.add('Jong paard');
    }
    switch (horse.condition) {
      case BodyCondition.thin:
        eff -= 2;
        reasons.add('Mager');
      case BodyCondition.heavy:
        eff += 1;
      case BodyCondition.normal:
        break;
    }
    switch (horse.sensitivity) {
      case Sensitivity.cold:
        eff -= 3;
        reasons.add('Koukleum');
      case Sensitivity.warm:
        eff += 3;
        reasons.add('Heeft het snel warm');
      case Sensitivity.normal:
        break;
    }
    if (horse.clip != ClipType.none) reasons.add(horse.clip.label);

    var level = levelFor(horse.clip, eff);
    final outsideWet = !stabled && w.isWet;

    // Een ongeschoren paard heeft bij droog weer geen regendeken nodig.
    if (level == BlanketLevel.rainSheet &&
        horse.clip == ClipType.none &&
        !outsideWet) {
      level = BlanketLevel.none;
    }

    // Een geschoren paard dat buiten in de regen staat: altijd iets waterdichts.
    if (level == BlanketLevel.none &&
        outsideWet &&
        horse.clip != ClipType.none &&
        base < 16) {
      level = BlanketLevel.rainSheet;
    }

    final neck = !stabled &&
        (level.index >= BlanketLevel.heavy.index ||
            (outsideWet && level.index >= BlanketLevel.medium.index && eff < 2));

    // --- Aandachtspunten ---------------------------------------------
    if (!w.isNight && w.maxTemp - w.minTemp >= 9 && level.wearsBlanket) {
      final warmLevel = levelFor(horse.clip, eff + (w.maxTemp - base));
      if (warmLevel.index < level.index) {
        notes.add(
            'Het wordt overdag ${w.maxTemp.round()}°C. Kun je wisselen, dan is '
            '${warmLevel == BlanketLevel.none ? 'geen deken' : 'een ${warmLevel.label.toLowerCase()}'} '
            'rond het middaguur genoeg.');
      }
    }
    if (level.wearsBlanket) {
      notes.add('Voel met je hand onder de deken bij de schoft: '
          'warm en droog is goed, zweterig is te warm.');
    }
    if (stabled && level.wearsBlanket) {
      notes.add('Op stal volstaat een staldeken; waterdicht is niet nodig.');
    }
    if (horse.clip == ClipType.none &&
        level.index >= BlanketLevel.light.index &&
        !outsideWet &&
        horse.sensitivity != Sensitivity.cold) {
      notes.add('Een gezond, ongeschoren paard met wintervacht kan vaak meer '
          'hebben dan je denkt. Twijfel je, kies dan de lichtere deken.');
    }
    final month = (now ?? DateTime.now()).month;
    if (!level.wearsBlanket &&
        !w.isNight &&
        w.maxTemp >= 18 &&
        month >= 5 &&
        month <= 9) {
      notes.add('Warm weer: een vliegendeken houdt insecten op afstand.');
    }
    if (w.kind == WeatherKind.storm && !stabled) {
      notes.add('Onweer verwacht. Zorg dat je paard kan schuilen.');
    }

    return BlanketAdvice(
      level: level,
      effectiveTemp: eff,
      baseTemp: base,
      neckCover: neck,
      waterproof: !stabled,
      reasons: reasons,
      notes: notes,
      inside: stabled,
    );
  }

  /// Opzoektabel: effectieve temperatuur → dekengewicht, per scheertype.
  /// De grenzen komen uit de [AdviceSettings] (instelbaar in de app).
  BlanketLevel levelFor(ClipType clip, double eff) {
    // Ondergrenzen (°C) voor resp. none, rainSheet, light, medium, heavy.
    // Lager dan de laatste grens = extraHeavy.
    final t = settings.thresholdsFor(clip);
    if (eff >= t[0]) return BlanketLevel.none;
    if (eff >= t[1]) return BlanketLevel.rainSheet;
    if (eff >= t[2]) return BlanketLevel.light;
    if (eff >= t[3]) return BlanketLevel.medium;
    if (eff >= t[4]) return BlanketLevel.heavy;
    return BlanketLevel.extraHeavy;
  }
}
