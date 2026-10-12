import 'dart:math' as math;

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
  const Correction(this.label, this.delta,
      {this.rain = false, this.info = false, this.note});
  final String label;
  final double delta;

  /// Alleen ter informatie (een factor); telt niet apart op.
  final bool info;

  /// Extra uitleg onder de regel.
  final String? note;

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
    this.night = false,
    this.baseLabel = 'Temperatuur',
    this.dryTemp,
    this.why = '',
    this.wholeDay = false,
  });

  /// Eén advies voor het hele etmaal (geen dekenwissels)?
  final bool wholeDay;

  /// Kopie met een aangepaste tekst, waterdichtheid of etmaal-markering.
  BlanketAdvice copyWith({List<String>? notes, bool? waterproof, bool? wholeDay}) =>
      BlanketAdvice(
        level: level,
        effectiveTemp: effectiveTemp,
        baseTemp: baseTemp,
        neckCover: neckCover,
        waterproof: waterproof ?? this.waterproof,
        reasons: reasons,
        notes: notes ?? this.notes,
        inside: inside,
        userChoice: userChoice,
        advisedLevel: advisedLevel,
        choiceBlanketId: choiceBlanketId,
        wet: wet,
        sunnyWarm: sunnyWarm,
        corrections: corrections,
        night: night,
        baseLabel: baseLabel,
        dryTemp: dryTemp,
        why: why,
        wholeDay: wholeDay ?? this.wholeDay,
      );

  /// Advies voor de nacht?
  final bool night;

  /// Alle correcties op de temperatuur, met hun graden.
  final List<Correction> corrections;

  /// Wat [baseTemp] is (bijv. 'Laagste temperatuur').
  final String baseLabel;

  /// Gevoelstemperatuur zonder de regencorrectie.
  final double? dryTemp;

  /// Waarom dit niveau (welke grens gold).
  final String why;

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
        night: night,
        baseLabel: baseLabel,
        dryTemp: dryTemp,
        why: why,
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

  /// Grootste weercorrectie (°C), omhoog en omlaag.
  static const maxWeatherCorrection = 4.0;

  /// Telt dit uur als nat? Bij minstens 30% neerslagkans én minstens 0,2 mm
  /// verwachte neerslag.
  static bool isWetHour(HourWeather h) => h.precipProb >= 30 && h.precip >= 0.2;

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

    // Basis: de gewone luchttemperatuur (temperature_2m) van het dagdeel,
    // 's nachts het koudste uur, overdag het gemiddelde. De gevoels-
    // temperatuur van de weerdienst gebruiken we niet: daar zit wind al in.
    final base = w.isNight ? w.minTemp : w.avgTemp;
    var eff = base;

    // --- Weer (per uur) ------------------------------------------------
    // Per uur: van de verkoelende factoren (wind, regen) telt alleen de
    // grootste; regenen én waaien geeft hooguit 1 °C extra. Zon compenseert,
    // maar niet in een uur met regen. Per uur begrensd op −4 tot +4 °C.
    final hs = w.hours;
    var weatherCorr = 0.0;
    var weatherCorrDry = 0.0;
    var sunBonus = 0.0;
    if (!stabled && hs.isNotEmpty) {
      double windOf(HourWeather h) {
        final v = h.wind >= 35
            ? settings.windStrong
            : h.wind >= 20
                ? settings.windModerate
                : 0.0;
        return shelter ? v / 2 : v;
      }

      double wetOf(HourWeather h) =>
          isWetHour(h) ? (shelter ? settings.wet / 2 : settings.wet) : 0.0;

      double sunOf(HourWeather h) {
        if (w.isNight || isWetHour(h) || h.isDay == false) return 0;
        final f = h.sun;
        if (f == null) return 0;
        if (f >= fullSunFrom) return settings.fullSun;
        if (f >= sunnyFrom) return settings.sunny;
        return 0;
      }

      double hourCorr(HourWeather h, {required bool withRain}) {
        final wind = windOf(h);
        final wet = withRain ? wetOf(h) : 0.0;
        var cool = math.max(wind, wet);
        if (wind > 0 && wet > 0) cool += math.min(1.0, math.min(wind, wet));
        return (-cool + sunOf(h)).clamp(-maxWeatherCorrection, maxWeatherCorrection);
      }

      double combine(double Function(HourWeather) f) {
        if (w.isNight) {
          // 's nachts telt het koudste uur na correctie
          var lo = double.infinity;
          for (final h in hs) {
            lo = math.min(lo, h.temp + f(h));
          }
          return lo - base;
        }
        var sum = 0.0;
        for (final h in hs) {
          sum += f(h);
        }
        return sum / hs.length;
      }

      weatherCorr = combine((h) => hourCorr(h, withRain: true));
      weatherCorrDry = combine((h) => hourCorr(h, withRain: false));
      if (!w.isNight) {
        sunBonus = hs.fold<double>(0, (t, h) => t + sunOf(h)) / hs.length;
      }

      // Voor de uitleg: welke factoren speelden in hoeveel uur.
      final n = hs.length;
      final windy = hs.where((h) => windOf(h) > 0).toList();
      final wetHs = hs.where((h) => wetOf(h) > 0).length;
      final full = hs.where((h) => sunOf(h) > 0 && sunOf(h) == settings.fullSun).length;
      final sunny = hs.where((h) => sunOf(h) > 0 && sunOf(h) != settings.fullSun).length;
      final half = shelter ? ' (schuilstal: half)' : '';
      if (windy.isNotEmpty) {
        final maxW = windy.map((h) => h.wind).reduce(math.max);
        final strong = maxW >= 35;
        reasons.add('Wind ${maxW.round()} km/u');
        corr.add(Correction(
            '${strong ? 'Harde wind' : 'Wind'} (vanaf ${strong ? 35 : 20} km/u, max '
            '${maxW.round()} km/u) in ${windy.length} van $n uur$half',
            -(strong ? settings.windStrong : settings.windModerate) / (shelter ? 2 : 1),
            info: true));
      }
      if (wetHs > 0) {
        final snow = w.kind == WeatherKind.snow;
        reasons.add(snow ? 'Sneeuw' : 'Nat weer');
        corr.add(Correction('${snow ? 'Sneeuw' : 'Regen'} in $wetHs van $n uur$half',
            -settings.wet / (shelter ? 2 : 1),
            info: true, rain: true));
      }
      if (full > 0) {
        reasons.add('Volle zon +${settings.fullSun.round()}°');
        corr.add(Correction('Volle zon in $full van $n uur', settings.fullSun, info: true));
      }
      if (sunny > 0) {
        reasons.add('Zonnig +${settings.sunny.round()}°');
        corr.add(Correction('Zonnig in $sunny van $n uur', settings.sunny, info: true));
      }
      if (windy.isNotEmpty || wetHs > 0 || full > 0 || sunny > 0) {
        corr.add(Correction(
            w.isNight ? 'Weer samen (bij het koudste uur)' : 'Weer samen (gemiddeld over het dagdeel)',
            weatherCorr,
            note: 'Alleen de grootste koude-factor telt; bij regen én wind '
                'hooguit 1° extra; zon niet bij regen; per uur tussen −4° en +4°.'));
      }
      eff += weatherCorr;
    }
    // Hoeveel de regen meetelde (voor de vliegendeken met regenstuk).
    final wetPenalty = weatherCorrDry - weatherCorr;
    if (stabled) {
      eff += settings.stable;
      reasons.add('Op stal');
      corr.add(Correction('Op stal', settings.stable));
    } else if (shelter && weatherCorr < 0) {
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

    // Nat: het blok telt als nat als er minstens één uur nat is.
    final outsideWet = !stabled &&
        (w.hours.isEmpty ? w.isWet : w.hours.any(isWetHour));
    // Zonder de regencorrectie: het regenstuk van een vliegendeken houdt de
    // regen juist tegen.
    final dryEff = eff + wetPenalty;
    final (level, why) = decide(horse.clip, eff,
        wet: outsideWet, base: base, dryEff: dryEff, night: w.isNight);

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
      night: w.isNight,
      baseLabel: w.isNight ? 'koudste uur' : 'gemiddeld over het dagdeel',
      dryTemp: dryEff,
      why: why,
    );
  }

  /// Het advies voor deze temperatuur. Zie [decide].
  BlanketLevel levelForWeather(ClipType clip, double eff,
          {required bool wet, double? base, double? dryEff, bool night = false}) =>
      decide(clip, eff, wet: wet, base: base, dryEff: dryEff, night: night).$1;

  /// Bepaalt het niveau én de uitleg waarom.
  ///
  /// [eff] is de berekende temperatuur mét regencorrectie, [dryEff] dezelfde
  /// zonder regencorrectie (wind en zon tellen wel). De lagen die zelf tegen
  /// regen beschermen (vliegendeken met regenstuk, regendeken) en 'geen
  /// deken' kiezen we op [dryEff]; voor de lichte deken en zwaarder telt de
  /// regencorrectie wel mee.
  ///
  /// [base]: luchttemperatuur zonder correcties (een geschoren paard in de
  /// regen krijgt onder 16 °C altijd iets waterdichts).
  /// [night]: eerst de nachtgrenzen ('geen deken' en 'vliegendeken' 's
  /// nachts), daaronder de normale grenzen.
  (BlanketLevel, String) decide(ClipType clip, double eff,
      {required bool wet, double? base, double? dryEff, bool night = false}) {
    final dry = dryEff ?? eff;
    final noRain = wet ? ' (zonder regencorrectie: de deken houdt de regen tegen)' : '';
    if (night) {
      final nn = settings.nightNoneFor(clip);
      final nf = settings.nightFlyFor(clip);
      if (dry >= nn) {
        return (
          BlanketLevel.none,
          "'s Nachts geen deken vanaf ${fmtTemp(nn)}; het is ${fmtTemp(dry)}$noRain."
        );
      }
      if (dry >= nf) {
        if (settings.flyRain && (wet || !settings.flyOnlyWetFor(clip))) {
          return (
            BlanketLevel.flyRain,
            "'s Nachts vliegendeken met regenstuk van ${fmtTemp(nf)} tot ${fmtTemp(nn)}; "
                'het is ${fmtTemp(dry)}$noRain.'
          );
        }
        return (
          BlanketLevel.none,
          settings.flyRain
              ? "'s Nachts valt ${fmtTemp(dry)} bij de vliegendeken met regenstuk "
                  '(${fmtTemp(nf)} tot ${fmtTemp(nn)}), maar die is ingesteld als '
                  '"alleen bij regen" en het is droog → geen deken.'
              : "'s Nachts ${fmtTemp(dry)}: tussen ${fmtTemp(nf)} en ${fmtTemp(nn)}, en de "
                  'vliegendeken met regenstuk staat uit → geen deken.'
        );
      }
      final (l, why) = _decideDay(clip, eff, dry, wet: wet, base: base);
      return (l, "Onder ${fmtTemp(nf)} gelden 's nachts de normale grenzen. $why");
    }
    return _decideDay(clip, eff, dry, wet: wet, base: base);
  }

  (BlanketLevel, String) _decideDay(ClipType clip, double eff, double dry,
      {required bool wet, double? base}) {
    final t = settings.thresholdsFor(clip);
    final flyFrom = settings.flyFromFor(clip);
    final noRain = wet ? ' (zonder regencorrectie: de deken houdt de regen tegen)' : '';
    if (dry >= t[0]) {
      return (BlanketLevel.none, 'Vanaf ${fmtTemp(t[0])} geen deken; het is ${fmtTemp(dry)}$noRain.');
    }
    if (dry >= flyFrom) {
      if (settings.flyRain && (wet || !settings.flyOnlyWetFor(clip))) {
        return (
          BlanketLevel.flyRain,
          '${fmtTemp(dry)} ligt tussen ${fmtTemp(flyFrom)} en ${fmtTemp(t[0])} '
              '→ vliegendeken met regenstuk$noRain.'
        );
      }
      if (wet && clip != ClipType.none && base != null && base < 16) {
        return (
          BlanketLevel.rainSheet,
          'Een geschoren paard dat onder 16 °C buiten in de regen staat, krijgt '
              'altijd iets waterdichts → regendeken.'
        );
      }
      return (
        BlanketLevel.none,
        settings.flyRain
            ? '${fmtTemp(dry)} valt bij de vliegendeken met regenstuk (${fmtTemp(flyFrom)} '
                'tot ${fmtTemp(t[0])}), maar die is ingesteld als "alleen bij regen" en '
                'het is droog → geen deken.'
            : '${fmtTemp(dry)} ligt boven de regendeken (tot ${fmtTemp(flyFrom)}) en de '
                'vliegendeken met regenstuk staat uit → geen deken.'
      );
    }
    if (dry >= t[1]) {
      if (!wet && settings.rainOnlyWetFor(clip)) {
        return (
          BlanketLevel.none,
          '${fmtTemp(dry)} valt bij de regendeken (${fmtTemp(t[1])} tot ${fmtTemp(flyFrom)}), '
              'maar die is ingesteld als "alleen bij nat weer" en het is droog → geen deken.'
        );
      }
      return (
        BlanketLevel.rainSheet,
        '${fmtTemp(dry)} ligt tussen ${fmtTemp(t[1])} en ${fmtTemp(flyFrom)} → regendeken$noRain.'
      );
    }
    // Lichte deken en zwaarder: hier telt de regencorrectie wel mee.
    final (BlanketLevel l, String range) = eff >= t[2]
        ? (BlanketLevel.light, '${fmtTemp(t[2])} tot ${fmtTemp(t[1])}')
        : eff >= t[3]
            ? (BlanketLevel.medium, '${fmtTemp(t[3])} tot ${fmtTemp(t[2])}')
            : eff >= t[4]
                ? (BlanketLevel.heavy, '${fmtTemp(t[4])} tot ${fmtTemp(t[3])}')
                : (BlanketLevel.extraHeavy, 'onder ${fmtTemp(t[4])}');
    return (
      l,
      '${fmtTemp(eff)}${wet ? ' (met regencorrectie)' : ''} valt bij '
          '${l.label.toLowerCase()} ($range).'
    );
  }

  /// '12 °C' of '12,5 °C'.
  static String fmtTemp(double v) {
    final r = (v * 2).round() / 2;
    return r == r.roundToDouble()
        ? '${r.round()} °C'
        : '${r.toStringAsFixed(1).replaceAll('.', ',')} °C';
  }

  /// Bovengrens van een warmteklasse: vanaf deze temperatuur hoort er een
  /// lichtere deken bij. Null = geen bovengrens.
  double? classUpper(ClipType clip, BlanketLevel level) {
    final t = settings.thresholdsFor(clip);
    return switch (level) {
      BlanketLevel.none => null,
      BlanketLevel.flyRain => t[0],
      BlanketLevel.rainSheet => settings.flyRain ? settings.flyFromFor(clip) : t[0],
      BlanketLevel.light => t[1],
      BlanketLevel.medium => t[2],
      BlanketLevel.heavy => t[3],
      BlanketLevel.extraHeavy => t[4],
    };
  }

  /// Eén deken voor het hele etmaal (geen dekenwissels). In principe de
  /// zwaarste van dag en nacht (meestal de nachtdeken), tenzij die overdag te
  /// warm is: boven het eigen maximum van de gekozen deken ([nightMax]) of
  /// boven de grens van zijn klasse. Dan de lichtere dagdeken, met een melding.
  BlanketAdvice wholeDay(BlanketAdvice day, BlanketAdvice night, ClipType clip,
      {double? nightMax}) {
    String lbl(BlanketLevel l) =>
        l == BlanketLevel.none ? 'geen deken' : 'de ${l.label.toLowerCase()}';
    String t(double v) => '${v.round()} °C';
    final waterproof = day.waterproof || night.waterproof;
    if (day.level == night.level) {
      return night.copyWith(
        wholeDay: true,
        waterproof: waterproof,
        notes: [
          'Eén deken voor het hele etmaal: overdag ${t(day.effectiveTemp)}, '
              "'s nachts ${t(night.effectiveTemp)}; allebei ${lbl(night.level)}.",
          ...night.notes,
        ],
      );
    }
    if (day.level.index > night.level.index) {
      // Overdag is er meer nodig (bijv. regen): die deken kan 's nachts ook.
      return day.copyWith(
        wholeDay: true,
        waterproof: waterproof,
        notes: [
          'Eén deken voor het hele etmaal: overdag is ${lbl(day.level)} nodig '
              "(${t(day.effectiveTemp)}); 's nachts ${t(night.effectiveTemp)}, dat kan er ook mee.",
          ...day.notes,
        ],
      );
    }
    // De nachtdeken is zwaarder: past die overdag nog?
    final upper = nightMax ?? classUpper(clip, night.level);
    // Waterdichte lagen kiezen we op de temperatuur zonder regencorrectie.
    final dayTemp = night.level == BlanketLevel.flyRain || night.level == BlanketLevel.rainSheet
        ? (day.dryTemp ?? day.effectiveTemp)
        : day.effectiveTemp;
    final tooWarm = upper != null &&
        (nightMax != null ? dayTemp > upper : dayTemp >= upper);
    if (tooWarm) {
      return day.copyWith(
        wholeDay: true,
        waterproof: waterproof,
        notes: [
          'Overdag te warm voor ${lbl(night.level)} (${t(dayTemp)}). '
              "Kies ${lbl(day.level)}; 's nachts is het rond ${t(night.effectiveTemp)}.",
          ...day.notes,
        ],
      );
    }
    return night.copyWith(
      wholeDay: true,
      waterproof: waterproof,
      notes: [
        'Eén deken voor het hele etmaal: ${lbl(night.level)} voor de nacht '
            '(${t(night.effectiveTemp)}). Overdag ${t(dayTemp)}, dat kan ermee.',
        ...night.notes,
      ],
    );
  }

  /// Opzoektabel: effectieve temperatuur → dekengewicht, per scheertype.
  /// De grenzen komen uit de [AdviceSettings] (instelbaar in de app).
  BlanketLevel levelFor(ClipType clip, double eff) {
    // Ondergrenzen (°C) voor resp. none, rainSheet, light, medium, heavy.
    // Lager dan de laatste grens = extraHeavy.
    final t = settings.thresholdsFor(clip);
    if (eff >= t[0]) return BlanketLevel.none;
    if (settings.flyRain && eff >= settings.flyFromFor(clip)) return BlanketLevel.flyRain;
    if (eff >= t[1]) return BlanketLevel.rainSheet;
    if (eff >= t[2]) return BlanketLevel.light;
    if (eff >= t[3]) return BlanketLevel.medium;
    if (eff >= t[4]) return BlanketLevel.heavy;
    return BlanketLevel.extraHeavy;
  }
}
