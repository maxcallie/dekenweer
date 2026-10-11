import 'package:flutter/material.dart';

import '../models/advice_settings.dart';
import '../models/horse.dart';
import '../models/weather.dart';

enum BlanketLevel {
  none('Geen deken', '—', Color(0xFF6E9B5A)),
  flyRain('Vliegendeken met regenstuk', '0 g', Color(0xFF3FAFA0)),
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

/// Eén correctie op de temperatuur, bijv. ('Wind 25 km/u', −2).
class Correction {
  const Correction(this.label, this.delta, {this.rain = false});
  final String label;
  final double delta;

  /// Is dit de correctie voor regen of sneeuw?
  final bool rain;
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
    this.wet = false,
    this.sunnyWarm = false,
    this.corrections = const [],
    this.baseLabel = 'Temperatuur',
    this.dryTemp,
    this.flyRainRange,
  });

  /// Alle correcties op de temperatuur, met hun graden.
  final List<Correction> corrections;

  /// Wat [baseTemp] is (bijv. 'Laagste temperatuur').
  final String baseLabel;

  /// Gevoelstemperatuur zonder de regencorrectie.
  final double? dryTemp;

  /// Bij de vliegendeken met regenstuk: het bereik (van, tot) dat gold.
  final (double, double)? flyRainRange;

  /// Staat het paard buiten in de regen of sneeuw?
  final bool wet;

  /// Zon en warm weer (dan gaat een zonwerende deken voor).
  final bool sunnyWarm;

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
        // De overige tips gingen over het advies zelf; bij een vaste keuze
        // houden we alleen wat over jouw keuze klopt.
        notes: [
          'Dit is je vaste keuze voor op stal: $description. Het advies zou zijn: '
              '${this.level.label.toLowerCase()}'
              '${this.level.wearsBlanket ? ' (${this.level.grams})' : ''}.',
          if (level.wearsBlanket) feelNote,
        ],
        inside: true,
        userChoice: true,
        corrections: corrections,
        baseLabel: baseLabel,
        dryTemp: dryTemp,
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

  static const feelNote = 'Voel met je hand onder de deken bij de schoft: '
      'warm en droog is goed, zweterig is te warm.';

  String get subtitle {
    if (userChoice) {
      return 'Jouw vaste keuze voor op stal'
          '${level.wearsBlanket ? ' · ${level.grams}' : ''}';
    }
    if (!level.wearsBlanket) return 'Je paard redt zich prima met zijn eigen vacht';
    if (level == BlanketLevel.flyRain) {
      return 'Warm en nat · houdt de rug droog';
    }
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

  /// Deel van de lichte uren met zon vanaf wanneer het 'zonnig' telt …
  static const sunnyFrom = 0.4;

  /// … en 'volle zon'.
  static const fullSunFrom = 0.75;

  /// Vanaf deze maximumtemperatuur telt zonnig weer als 'warm'.
  static const sunnyWarmFrom = 15.0;

  /// [inside]: staat het paard in deze periode op stal (volgens het
  /// stalschema)? Dan telt de stal als warmer en spelen wind en regen geen rol.
  BlanketAdvice advise(Horse horse, PeriodWeather w,
      {bool inside = false, DateTime? now}) {
    final reasons = <String>[];
    final notes = <String>[];
    // Alle correcties met hun graden, voor de uitleg bij het advies.
    final corr = <Correction>[];

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
      corr.add(Correction('Wind ${w.maxWind.round()} km/u${shelter ? ' (schuilstal, half)' : ''}',
          -windPenalty));
    }
    if (wetPenalty > 0) {
      eff -= wetPenalty;
      reasons.add(w.kind == WeatherKind.snow ? 'Sneeuw' : 'Nat weer');
      corr.add(Correction(
          '${w.kind == WeatherKind.snow ? 'Sneeuw' : 'Regen'}${shelter ? ' (schuilstal, half)' : ''}',
          -wetPenalty,
          rain: true));
    }
    // Zon: alleen overdag en buiten.
    var sunBonus = 0.0;
    final sun = w.sunFraction;
    if (!stabled && !w.isNight && sun != null) {
      if (sun >= fullSunFrom) {
        sunBonus = settings.fullSun;
        if (sunBonus > 0) {
          reasons.add('Volle zon +${sunBonus.round()}°');
          corr.add(Correction('Volle zon', sunBonus));
        }
      } else if (sun >= sunnyFrom) {
        sunBonus = settings.sunny;
        if (sunBonus > 0) {
          reasons.add('Zonnig +${sunBonus.round()}°');
          corr.add(Correction('Zonnig', sunBonus));
        }
      }
      eff += sunBonus;
    }
    if (stabled) {
      eff += settings.stable;
      reasons.add('Op stal');
      corr.add(Correction('Op stal', settings.stable));
    } else if (shelter && (windPenalty > 0 || wetPenalty > 0)) {
      reasons.add('Schuilstal');
    }

    // --- Paard --------------------------------------------------------
    switch (horse.type) {
      case HorseType.pony:
      case HorseType.coldblood:
        eff += 3;
        reasons.add(horse.type.label);
        corr.add(Correction(horse.type.label, 3));
      case HorseType.hotblood:
        eff -= 2;
        reasons.add(horse.type.label);
        corr.add(Correction(horse.type.label, -2));
      case HorseType.warmblood:
      case HorseType.baroque:
        break;
    }
    if (horse.age >= 20) {
      eff -= 2;
      reasons.add('Senior');
      corr.add(const Correction('Senior', -2));
    } else if (horse.age <= 2) {
      eff -= 1;
      reasons.add('Jong paard');
      corr.add(const Correction('Jong paard', -1));
    }
    switch (horse.condition) {
      case BodyCondition.thin:
        eff -= 2;
        reasons.add('Mager');
        corr.add(const Correction('Mager', -2));
      case BodyCondition.heavy:
        eff += 1;
        corr.add(const Correction('Goed in het vlees', 1));
      case BodyCondition.normal:
        break;
    }
    switch (horse.sensitivity) {
      case Sensitivity.cold:
        eff -= 3;
        reasons.add('Koukleum');
        corr.add(const Correction('Koukleum', -3));
      case Sensitivity.warm:
        eff += 3;
        reasons.add('Heeft het snel warm');
        corr.add(const Correction('Heeft het snel warm', 3));
      case Sensitivity.normal:
        break;
    }
    if (horse.clip != ClipType.none) reasons.add(horse.clip.label);

    final outsideWet = !stabled && w.isWet;
    // Zonder de regencorrectie: het regenstuk van een vliegendeken houdt de
    // regen juist tegen.
    final dryEff = eff + wetPenalty;
    final level = levelForWeather(horse.clip, eff,
        wet: outsideWet, base: base, dryEff: dryEff);

    final neck = !stabled &&
        (level.index >= BlanketLevel.heavy.index ||
            (outsideWet && level.index >= BlanketLevel.medium.index && eff < 2));

    // --- Aandachtspunten ---------------------------------------------
    if (!w.isNight && w.maxTemp - w.minTemp >= 9 && level.wearsBlanket) {
      var warmLevel = levelForWeather(horse.clip, eff + (w.maxTemp - base),
          wet: outsideWet, dryEff: dryEff + (w.maxTemp - base));
      // Op stal nooit een regendeken.
      if (warmLevel == BlanketLevel.rainSheet && stabled) {
        warmLevel = BlanketLevel.none;
      }
      if (warmLevel.index < level.index) {
        notes.add(
            'Het wordt overdag ${w.maxTemp.round()}°C. Kun je wisselen, dan is '
            '${warmLevel == BlanketLevel.none ? 'geen deken' : 'een ${warmLevel.label.toLowerCase()}'} '
            'rond het middaguur genoeg.');
      }
    }
    if (level == BlanketLevel.flyRain) {
      notes.add('Warm en nat: een vliegendeken met regenstuk houdt rug en '
          'lendenen droog zonder dat je paard het te warm krijgt.');
    } else if (level.wearsBlanket) {
      notes.add(BlanketAdvice.feelNote);
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
      wet: outsideWet,
      sunnyWarm: sunBonus > 0 && w.maxTemp >= sunnyWarmFrom,
      corrections: corr,
      baseLabel: w.isNight ? 'Laagste temperatuur' : 'Temperatuur overdag',
      dryTemp: dryEff,
      flyRainRange: level == BlanketLevel.flyRain
          ? (settings.thresholdsFor(horse.clip)[0], settings.flyRainUpToFor(horse.clip))
          : null,
    );
  }

  /// Het advies voor deze effectieve temperatuur, rekening houdend met het
  /// weer: een regendeken die alleen bij nat weer hoort, en de vliegendeken
  /// met regenstuk bij warm, nat weer. [wet]: staat het paard buiten in de
  /// regen of sneeuw?
  ///
  /// [base] is de temperatuur zonder correcties: een geschoren paard in de
  /// regen krijgt onder 16 °C altijd iets waterdichts.
  ///
  /// [dryEff] is dezelfde temperatuur maar zonder de regencorrectie; die
  /// bepaalt of de vliegendeken met regenstuk van toepassing is (het
  /// regenstuk beschermt tegen de regen). Zonder [dryEff] telt [eff].
  BlanketLevel levelForWeather(ClipType clip, double eff,
      {required bool wet, double? base, double? dryEff}) {
    // Warm en nat: vliegendeken met regenstuk, tussen 'Geen deken' en de
    // ingestelde bovengrens (temperatuur zonder regencorrectie).
    final dry = dryEff ?? eff;
    if (wet &&
        settings.flyRain &&
        dry >= settings.thresholdsFor(clip)[0] &&
        dry < settings.flyRainUpToFor(clip)) {
      return BlanketLevel.flyRain;
    }
    final level = levelFor(clip, eff);
    // Regendeken alleen bij nat weer (instelbaar per scheerstatus).
    if (level == BlanketLevel.rainSheet && !wet && settings.rainOnlyWetFor(clip)) {
      return BlanketLevel.none;
    }
    // Een geschoren paard dat buiten in de regen staat: altijd iets waterdichts.
    if (level == BlanketLevel.none &&
        wet &&
        clip != ClipType.none &&
        base != null &&
        base < 16) {
      return BlanketLevel.rainSheet;
    }
    return level;
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
