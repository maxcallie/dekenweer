import 'package:dekenweer/logic/blanket_advisor.dart';
import 'package:dekenweer/logic/blanket_picker.dart';
import 'package:dekenweer/models/advice_settings.dart';
import 'package:dekenweer/models/blanket.dart';
import 'package:dekenweer/models/day_phase.dart';
import 'package:dekenweer/models/horse.dart';
import 'package:dekenweer/models/season.dart';
import 'package:dekenweer/models/weather.dart';
import 'package:flutter_test/flutter_test.dart';

PeriodWeather period({
  required double temp,
  bool night = true,
  double wind = 5,
  double precip = 0,
  double? sun,
}) {
  final start = DateTime(2026, 11, 10, night ? 20 : 8);
  final hours = [
    for (var i = 0; i < 12; i++)
      HourWeather(
        time: start.add(Duration(hours: i)),
        temp: temp,
        feels: temp,
        precipProb: precip > 0 ? 80 : 0,
        precip: precip / 12,
        code: precip > 0 ? 63 : 2,
        wind: wind,
        humidity: 85,
        sunshine: sun,
        isDay: sun == null ? null : !night,
      ),
  ];
  return PeriodWeather.fromHours(hours,
      start: start,
      end: start.add(const Duration(hours: 12)),
      isNight: night,
      label: 'Test');
}

void main() {
  const advisor = BlanketAdvisor();

  test('ongeschoren warmbloed bij 10°C droog: geen deken', () {
    final h = Horse(id: '1', name: 'Bella');
    expect(advisor.advise(h, period(temp: 10)).level, BlanketLevel.none);
  });

  test('ongeschoren bij 5°C droog: geen deken, nat: regendeken', () {
    final h = Horse(id: '1', name: 'Bella');
    expect(advisor.advise(h, period(temp: 6)).level, BlanketLevel.none);
    expect(advisor.advise(h, period(temp: 9, precip: 6)).level,
        BlanketLevel.rainSheet);
  });

  test('volledig geschoren bij 2°C: zwaar met halsstuk', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
    final a = advisor.advise(h, period(temp: 2));
    expect(a.level, BlanketLevel.heavy);
    expect(a.neckCover, isTrue);
  });

  test('op stal is warmer en niet waterdicht nodig', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
    final a = advisor.advise(h, period(temp: 2, precip: 8, wind: 40), inside: true);
    expect(a.level, BlanketLevel.medium);
    expect(a.waterproof, isFalse);
  });

  test('pony heeft minder snel een deken nodig dan een volbloed', () {
    final pony = Horse(id: '1', name: 'Pip', type: HorseType.pony);
    final arab = Horse(id: '2', name: 'Zara', type: HorseType.hotblood);
    final w = period(temp: -4);
    expect(advisor.advise(pony, w).level.index,
        lessThan(advisor.advise(arab, w).level.index));
  });

  group('eigen instellingen', () {
    test('hogere grens geeft eerder een deken', () {
      final h = Horse(id: '1', name: 'Bella');
      final w = period(temp: 6);
      expect(advisor.advise(h, w).level, BlanketLevel.none);
      // "Lichte deken vanaf" van -3 naar 7 graden: dan wel een deken.
      final custom = AdviceSettings.defaults.withThreshold(ClipType.none, 2, 7);
      expect(BlanketAdvisor(custom).advise(h, w).level.index,
          greaterThanOrEqualTo(BlanketLevel.light.index));
    });

    test('grenzen blijven aflopend', () {
      final s = AdviceSettings.defaults.withThreshold(ClipType.full, 1, 25);
      final t = s.thresholdsFor(ClipType.full);
      for (var i = 1; i < t.length; i++) {
        expect(t[i], lessThan(t[i - 1]));
      }
    });

    test('opslaan en teruglezen', () {
      final s = AdviceSettings.defaults.copyWith(wet: 5);
      final back = AdviceSettings.fromJson(s.toJson());
      expect(back.wet, 5);
      expect(back.full, AdviceSettings.defaultFull);
    });
  });

  group('regendeken alleen bij nat weer', () {
    // Deels geschoren: geen deken vanaf 15 °C, regendeken vanaf 10 °C.
    const clip = ClipType.partial;
    final aan = AdviceSettings.defaults.withRainOnlyWet(clip, true);
    final uit = AdviceSettings.defaults.withRainOnlyWet(clip, false);

    test('12 °C droog, schakelaar uit: regendeken', () {
      expect(BlanketAdvisor(uit).levelForWeather(clip, 12, wet: false),
          BlanketLevel.rainSheet);
    });

    test('12 °C droog, schakelaar aan: geen deken', () {
      expect(BlanketAdvisor(aan).levelForWeather(clip, 12, wet: false),
          BlanketLevel.none);
    });

    test('standaard zoals vroeger: alleen ongeschoren is "alleen bij nat weer"', () {
      const s = AdviceSettings.defaults;
      expect(s.rainOnlyWetFor(ClipType.none), isTrue);
      expect(s.rainOnlyWetFor(ClipType.partial), isFalse);
      expect(s.rainOnlyWetFor(ClipType.full), isFalse);
      final h = Horse(id: '1', name: 'Bella');
      // ongeschoren, 6 °C droog: geen deken (zoals altijd)
      expect(advisor.advise(h, period(temp: 6)).level, BlanketLevel.none);
    });

    test('ongeschoren met schakelaar uit: regendeken ook droog', () {
      final h = Horse(id: '1', name: 'Bella');
      final s = AdviceSettings.defaults.withRainOnlyWet(ClipType.none, false);
      expect(BlanketAdvisor(s).advise(h, period(temp: 6)).level, BlanketLevel.rainSheet);
    });
  });

  group('vliegendeken met regenstuk', () {
    const clip = ClipType.partial; // geen deken vanaf 15 °C, tot 20 °C
    const a = BlanketAdvisor();

    test('17 °C met regen: vliegendeken met regenstuk', () {
      expect(a.levelForWeather(clip, 17, wet: true), BlanketLevel.flyRain);
    });

    test('17 °C droog: geen deken', () {
      expect(a.levelForWeather(clip, 17, wet: false), BlanketLevel.none);
    });

    test('boven de bovengrens met regen: geen deken', () {
      expect(a.levelForWeather(clip, 21, wet: true), BlanketLevel.none);
    });

    test('uitgeschakeld: zoals vroeger', () {
      final off = BlanketAdvisor(AdviceSettings.defaults.copyWith(flyRain: false));
      expect(off.levelForWeather(clip, 17, wet: true), BlanketLevel.none);
      // geschoren paard in de regen onder 16 °C: regendeken
      expect(off.levelForWeather(clip, 15.5, wet: true, base: 15.5),
          BlanketLevel.rainSheet);
    });

    test('volledig advies: ongeschoren paard bij 15 °C regen', () {
      final h = Horse(id: '1', name: 'Bella');
      // 15 − 3 (nat) = 12 °C: boven "geen deken" (8), onder 20.
      final adv = advisor.advise(h, period(temp: 15, precip: 6));
      expect(adv.level, BlanketLevel.flyRain);
      final fly = Blanket(id: 'f', name: 'Vlieg', kind: BlanketKind.fly, grams: 0);
      final turnout = Blanket(id: 't', name: 'Buiten', kind: BlanketKind.turnout, grams: 0);
      expect(BlanketPicker.pick(h, adv, [turnout, fly])!.main.id, 'f');
      expect(BlanketPicker.pick(h, adv, [turnout]), isNull);
    });

    test('bovengrens blijft boven "geen deken"', () {
      final s = AdviceSettings.defaults.withThreshold(ClipType.partial, 0, 25);
      expect(s.flyRainUpToFor(ClipType.partial), greaterThan(25));
      final t = s.withFlyRainUpTo(ClipType.partial, 3);
      expect(t.flyRainUpToFor(ClipType.partial), 26);
    });
  });

  group('zon', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);

    test('volle zon telt overdag +4°, zonnig +2°', () {
      final none = advisor.advise(h, period(temp: 10, night: false));
      final full = advisor.advise(h, period(temp: 10, night: false, sun: 1));
      final some = advisor.advise(h, period(temp: 10, night: false, sun: 0.5));
      final cloudy = advisor.advise(h, period(temp: 10, night: false, sun: 0.1));
      expect(full.effectiveTemp - none.effectiveTemp, 4);
      expect(some.effectiveTemp - none.effectiveTemp, 2);
      expect(cloudy.effectiveTemp, none.effectiveTemp);
      expect(full.reasons, contains('Volle zon +4°'));
      expect(some.reasons, contains('Zonnig +2°'));
    });

    test('niet \'s nachts en niet op stal', () {
      final night = advisor.advise(h, period(temp: 10, night: true, sun: 1));
      expect(night.reasons.where((r) => r.contains('zon')), isEmpty);
      final dry = advisor.advise(h, period(temp: 10, night: true));
      expect(night.effectiveTemp, dry.effectiveTemp);
      final inside =
          advisor.advise(h, period(temp: 10, night: false, sun: 1), inside: true);
      final insideCloudy = advisor.advise(h, period(temp: 10, night: false), inside: true);
      expect(inside.effectiveTemp, insideCloudy.effectiveTemp);
    });

    test('telt op met wind', () {
      final calm = advisor.advise(h, period(temp: 10, night: false));
      final both = advisor.advise(h, period(temp: 10, night: false, sun: 1, wind: 25));
      expect(both.effectiveTemp - calm.effectiveTemp, 2); // +4 − 2
    });

    test('nachtelijke uren tellen niet mee in de zon', () {
      final start = DateTime(2026, 11, 10, 6);
      final hours = [
        for (var i = 0; i < 6; i++)
          HourWeather(
            time: start.add(Duration(hours: i)),
            temp: 10, feels: 10, precipProb: 0, precip: 0, code: 0, wind: 5,
            humidity: 80,
            sunshine: i < 2 ? 0 : 1,
            isDay: i >= 2, // 06–08 nog donker
          ),
      ];
      final w = PeriodWeather.fromHours(hours,
          start: start, end: start.add(const Duration(hours: 6)),
          isNight: false, label: 'Ochtend');
      expect(w.sunFraction, 1);
    });
  });

  group('instellingen migreren', () {
    test('oude opgeslagen instellingen krijgen standaard voor nieuwe velden', () {
      final old = {
        'unclipped': [9, 3, -3, -10, -18],
        'partial': AdviceSettings.defaultPartial,
        'full': AdviceSettings.defaultFull,
        'windModerate': 2,
        'windStrong': 4,
        'wet': 4,
        'stable': 5,
      };
      final s = AdviceSettings.fromJson(old);
      expect(s.unclipped.first, 9);
      expect(s.wet, 4);
      expect(s.rainOnlyWet, AdviceSettings.defaultRainOnlyWet);
      expect(s.flyRain, isTrue);
      expect(s.flyRainUpTo, AdviceSettings.defaultFlyRainUpTo);
      expect(s.sunny, 2);
      expect(s.fullSun, 4);
    });

    test('nieuwe velden opslaan en teruglezen', () {
      final s = AdviceSettings.defaults
          .withRainOnlyWet(ClipType.none, false)
          .withFlyRainUpTo(ClipType.full, 24)
          .copyWith(flyRain: false, sunny: 1, fullSun: 6);
      final back = AdviceSettings.fromJson(s.toJson());
      expect(back.rainOnlyWet, [false, false, false]);
      expect(back.flyRainUpToFor(ClipType.full), 24);
      expect(back.flyRain, isFalse);
      expect(back.sunny, 1);
      expect(back.fullSun, 6);
      expect(back.isDefault, isFalse);
    });

    test('standaard zet alles terug', () {
      expect(AdviceSettings.defaults.isDefault, isTrue);
      expect(AdviceSettings.fromJson(AdviceSettings.defaults.toJson()).isDefault, isTrue);
    });
  });

  group('dekenkast', () {
    final rain = Blanket(id: 'r', name: 'Regendeken', kind: BlanketKind.rain, grams: 0);
    final b100 = Blanket(id: 'a', name: 'Licht', kind: BlanketKind.turnout, grams: 100);
    final b200 = Blanket(id: 'b', name: 'Winter', kind: BlanketKind.turnout, grams: 200);
    final stal = Blanket(
        id: 's', name: 'Staldeken', kind: BlanketKind.stable, grams: 250, waterproof: false);
    final onder = Blanket(
        id: 'o', name: 'Onderdeken', kind: BlanketKind.under, grams: 200, waterproof: false);

    test('kiest de deken die het best past', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
      final a = advisor.advise(h, period(temp: 6, night: false)); // middel
      expect(a.level, BlanketLevel.medium);
      final p = BlanketPicker.pick(h, a, [rain, b100, b200, stal])!;
      expect(p.main.id, 'b');
      expect(p.matches, isTrue);
    });

    test('buiten nooit een niet-waterdichte deken', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
      final a = advisor.advise(h, period(temp: 1)); // zwaar, buiten
      final p = BlanketPicker.pick(h, a, [b100, stal])!;
      expect(p.main.waterproof, isTrue);
    });

    test('combineert met onderdeken als één deken te licht is', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
      final a = advisor.advise(h, period(temp: -6)); // extra zwaar
      expect(a.level, BlanketLevel.extraHeavy);
      final p = BlanketPicker.pick(h, a, [b100, b200, onder])!;
      expect(p.under?.id, 'o');
      expect(p.grams, 400);
    });

    test('deken voor een ander paard telt niet mee', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);
      final other = Blanket(
          id: 'x', name: 'Van Storm', kind: BlanketKind.turnout, grams: 200, horseIds: ['2']);
      final a = advisor.advise(h, period(temp: 6, night: false));
      expect(BlanketPicker.pick(h, a, [other]), isNull);
    });

    test('geen deken nodig: geen keuze', () {
      final h = Horse(id: '1', name: 'Bella');
      final a = advisor.advise(h, period(temp: 15));
      expect(BlanketPicker.pick(h, a, [b200]), isNull);
    });
  });

  group('seizoenen', () {
    test('standaard: zomer altijd buiten, winter \'s avonds binnen', () {
      const s = SeasonSettings.defaults;
      expect(s.seasonOf(DateTime(2026, 7, 1)), Season.summer);
      expect(s.seasonOf(DateTime(2026, 12, 1)), Season.winter);
      expect(s.seasonOf(DateTime(2026, 2, 1)), Season.winter);
      expect(s.isInside(DateTime(2026, 7, 1), DayPhase.evening), isFalse);
      expect(s.isInside(DateTime(2026, 12, 1), DayPhase.evening), isTrue);
      expect(s.isInside(DateTime(2026, 12, 1), DayPhase.morning), isFalse);
    });

    test('opslaan en teruglezen', () {
      final s = SeasonSettings.defaults
          .withInside(Season.summer, DayPhase.afternoon, true)
          .withStart(Season.winter, 10, 15);
      final back = SeasonSettings.fromJson(s.toJson());
      expect(back.summerInside, {DayPhase.afternoon});
      expect(back.winterMonth, 10);
      expect(back.winterDay, 15);
    });
  });
}
