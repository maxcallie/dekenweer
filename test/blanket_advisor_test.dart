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

  // ---- Doel: niet geschoren (standaardinstellingen) ----------------------
  group('niet geschoren, overdag', () {
    final h = Horse(id: '1', name: 'Bella');
    BlanketLevel day(double t, {double precip = 0, double wind = 5, double? sun}) =>
        advisor.advise(h, period(temp: t, night: false, precip: precip, wind: wind, sun: sun)).level;

    test('22 °C, droog → geen deken', () => expect(day(22), BlanketLevel.none));
    test('17 °C, droog → vliegendeken met regenstuk', () => expect(day(17), BlanketLevel.flyRain));
    test('17 °C, regen → vliegendeken met regenstuk',
        () => expect(day(17, precip: 6), BlanketLevel.flyRain));
    test('12 °C, bewolkt, droog → regendeken',
        () => expect(day(12, sun: 0.1), BlanketLevel.rainSheet));
    test('12 °C, regen en wind → regendeken',
        () => expect(day(12, precip: 6, wind: 25), BlanketLevel.rainSheet));
    test('12 °C, volle zon, windstil (+4) → vliegendeken met regenstuk',
        () => expect(day(12, sun: 1), BlanketLevel.flyRain));
    test('7 °C → lichte deken', () => expect(day(7), BlanketLevel.light));
    test('verder: 2 → middel, −3 → zwaar, −8 → extra zwaar', () {
      expect(day(2), BlanketLevel.medium);
      expect(day(-3), BlanketLevel.heavy);
      expect(day(-8), BlanketLevel.extraHeavy);
    });
    test('grenzen: 20 → geen, 15 → vlieg, 10 → regen, 5 → licht', () {
      expect(day(20), BlanketLevel.none);
      expect(day(15), BlanketLevel.flyRain);
      expect(day(10), BlanketLevel.rainSheet);
      expect(day(5), BlanketLevel.light);
    });
    test('uitleg noemt de grens', () {
      final a = advisor.advise(h, period(temp: 17, night: false, precip: 6));
      expect(a.why, contains('tussen 15 °C en 20 °C'));
      expect(a.why, contains('zonder regencorrectie'));
    });
  });

  group('niet geschoren, nacht', () {
    final h = Horse(id: '1', name: 'Bella');
    BlanketLevel night(double t, {double precip = 0}) =>
        advisor.advise(h, period(temp: t, night: true, precip: precip)).level;

    test('16 °C → geen deken', () => expect(night(16), BlanketLevel.none));
    test('12 °C, droog → vliegendeken met regenstuk', () => expect(night(12), BlanketLevel.flyRain));
    test('12 °C, regen → vliegendeken met regenstuk',
        () => expect(night(12, precip: 6), BlanketLevel.flyRain));
    test('8 °C → lichte deken', () => expect(night(8), BlanketLevel.light));
    test('grenzen: 15 → geen, 10 → vlieg', () {
      expect(night(15), BlanketLevel.none);
      expect(night(10), BlanketLevel.flyRain);
    });
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
    final w = period(temp: -1); // pony +3 → 2 °C (middel), volbloed −2 → −3 °C (zwaar)
    expect(advisor.advise(pony, w).level.index,
        lessThan(advisor.advise(arab, w).level.index));
  });

  group('eigen instellingen', () {
    test('hogere grens geeft eerder een zwaardere deken', () {
      final h = Horse(id: '1', name: 'Bella');
      final w = period(temp: 12, night: false);
      expect(advisor.advise(h, w).level, BlanketLevel.rainSheet);
      final custom = AdviceSettings.defaults.withThreshold(ClipType.none, 1, 13);
      expect(BlanketAdvisor(custom).advise(h, w).level, BlanketLevel.light);
    });

    test('grenzen blijven aflopend, vliegendeken ertussen', () {
      final s = AdviceSettings.defaults.withThreshold(ClipType.full, 1, 25);
      final t = s.thresholdsFor(ClipType.full);
      for (var i = 1; i < t.length; i++) {
        expect(t[i], lessThan(t[i - 1]));
      }
      expect(s.flyFromFor(ClipType.full), inInclusiveRange(t[1], t[0]));
      final f = AdviceSettings.defaults.withFlyFrom(ClipType.none, 25);
      expect(f.thresholdsFor(ClipType.none)[0], greaterThanOrEqualTo(25));
      final g = AdviceSettings.defaults.withFlyFrom(ClipType.none, 8);
      expect(g.thresholdsFor(ClipType.none)[1], lessThanOrEqualTo(8));
    });

    test('nachtgrenzen blijven in volgorde', () {
      final s = AdviceSettings.defaults.withNightFly(ClipType.none, 17);
      expect(s.nightNoneFor(ClipType.none), 17);
      final t = AdviceSettings.defaults.withNightNone(ClipType.none, 8);
      expect(t.nightFlyFor(ClipType.none), 8);
    });

    test('opslaan en teruglezen', () {
      final s = AdviceSettings.defaults.copyWith(wet: 5);
      final back = AdviceSettings.fromJson(s.toJson());
      expect(back.wet, 5);
      expect(back.full, AdviceSettings.defaultFull);
      expect(back.isDefault, isFalse);
      expect(AdviceSettings.fromJson(AdviceSettings.defaults.toJson()).isDefault, isTrue);
    });
  });

  group('alleen bij regen / nat weer', () {
    const clip = ClipType.partial; // vlieg 15–20 (alleen bij regen), regen 10–15

    test('regendeken: 12 °C droog, schakelaar uit → regendeken, aan → geen deken', () {
      final uit = BlanketAdvisor(AdviceSettings.defaults.withRainOnlyWet(clip, false));
      final aan = BlanketAdvisor(AdviceSettings.defaults.withRainOnlyWet(clip, true));
      expect(uit.levelForWeather(clip, 12, wet: false), BlanketLevel.rainSheet);
      expect(aan.levelForWeather(clip, 12, wet: false), BlanketLevel.none);
    });

    test('vliegendeken alleen bij regen: 17 °C droog → geen, met regen → vlieg', () {
      expect(advisor.levelForWeather(clip, 17, wet: false), BlanketLevel.none);
      expect(advisor.levelForWeather(clip, 14, wet: true, dryEff: 17), BlanketLevel.flyRain);
      expect(advisor.levelForWeather(clip, 18, wet: true, dryEff: 21), BlanketLevel.none);
    });

    test('vliegendeken uitgeschakeld', () {
      final off = BlanketAdvisor(AdviceSettings.defaults.copyWith(flyRain: false));
      expect(off.levelForWeather(clip, 17, wet: true, base: 17), BlanketLevel.none);
      // geschoren paard in de regen onder 16 °C: regendeken
      expect(off.levelForWeather(clip, 15.5, wet: true, base: 15.5), BlanketLevel.rainSheet);
      final h = Horse(id: '1', name: 'Bella');
      expect(off.advise(h, period(temp: 17, night: false)).level, BlanketLevel.none);
    });

    test('regen telt niet mee voor het regenstuk (18 °C, regen, wat wind)', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final adv = advisor.advise(h, period(temp: 18, night: false, precip: 3, wind: 25));
      // 18 − 3 (regen, grootste) − 1 (wind erbij) = 14, zonder regen 16
      expect(adv.effectiveTemp, 14);
      expect(adv.dryTemp, 16);
      expect(adv.level, BlanketLevel.flyRain);
      expect(adv.corrections.firstWhere((c) => c.rain).delta, -3);
      expect(adv.corrections.firstWhere((c) => !c.info).delta, -4);
    });

    test('volledig advies: vliegendeken uit de dekenkast', () {
      final h = Horse(id: '1', name: 'Bella');
      final adv = advisor.advise(h, period(temp: 17, night: false));
      expect(adv.level, BlanketLevel.flyRain);
      final fly = Blanket(id: 'f', name: 'Vlieg', kind: BlanketKind.fly, grams: 0);
      final turnout = Blanket(id: 't', name: 'Buiten', kind: BlanketKind.turnout, grams: 0);
      expect(BlanketPicker.pick(h, adv, [turnout, fly])!.main.id, 'f');
      expect(BlanketPicker.pick(h, adv, [turnout]), isNull);
    });
  });

  group('nachtgrenzen instelbaar', () {
    test('deels geschoren: nachtgrenzen naar 13 °C', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final s = AdviceSettings.defaults
          .withNightNone(ClipType.partial, 13)
          .withNightFly(ClipType.partial, 13);
      final a = BlanketAdvisor(s);
      expect(a.advise(h, period(temp: 14, night: true)).level, BlanketLevel.none);
      // 12 °C: onder de nachtgrens → normale grenzen → regendeken
      expect(a.advise(h, period(temp: 12, night: true)).level, BlanketLevel.rainSheet);
      expect(AdviceSettings.fromJson(s.toJson()).nightNoneFor(ClipType.partial), 13);
    });
  });

  group('instellingen migreren (oud formaat)', () {
    test('nooit aangepast → nieuwe standaard', () {
      final old = {
        'unclipped': [8, 3, -3, -10, -18],
        'partial': [15, 10, 5, 0, -7],
        'full': [18, 14, 9, 3, -3],
        'windModerate': 2, 'windStrong': 4, 'wet': 3, 'stable': 5,
        'sunny': 2, 'fullSun': 4,
        'rainOnlyWet': [true, false, false],
        'flyRain': true,
        'flyRainUpTo': [20, 20, 22],
        'nightNone': [10, 10, 10],
        'blanketChanges': 1, 'dayStart': 9, 'dayEnd': 18,
      };
      expect(AdviceSettings.fromJson(old).isDefault, isTrue);
    });

    test('aangepast → zelfde advies als vroeger', () {
      final old = {
        'unclipped': [9, 3, -3, -10, -18],
        'wet': 4,
      };
      final s = AdviceSettings.fromJson(old);
      expect(s.wet, 4);
      expect(s.thresholdsFor(ClipType.none), [20, 3, -3, -10, -18]);
      expect(s.flyFromFor(ClipType.none), 9);
      expect(s.flyOnlyWetFor(ClipType.none), isTrue);
      expect(s.rainOnlyWetFor(ClipType.none), isTrue);
      final a = BlanketAdvisor(s);
      // vroeger: 12 °C droog → geen deken, met regen (zonder regencorrectie 12) → vlieg
      expect(a.levelForWeather(ClipType.none, 12, wet: false), BlanketLevel.none);
      expect(a.levelForWeather(ClipType.none, 8, wet: true, dryEff: 12), BlanketLevel.flyRain);
      // 5 °C droog: regendeken alleen bij nat → geen deken (zoals vroeger)
      expect(a.levelForWeather(ClipType.none, 5, wet: false), BlanketLevel.none);
      expect(a.levelForWeather(ClipType.none, 1, wet: false), BlanketLevel.light);
      // de andere scheerstatussen waren niet aangepast → nieuwe standaard
      expect(s.thresholdsFor(ClipType.partial), AdviceSettings.defaultPartial);
    });

    test('nieuwe velden opslaan en teruglezen', () {
      final s = AdviceSettings.defaults
          .withRainOnlyWet(ClipType.none, true)
          .withFlyOnlyWet(ClipType.none, true)
          .withFlyFrom(ClipType.full, 20)
          .withNightFly(ClipType.full, 12)
          .copyWith(flyRain: false, sunny: 1, fullSun: 6);
      final back = AdviceSettings.fromJson(s.toJson());
      expect(back.rainOnlyWetFor(ClipType.none), isTrue);
      expect(back.flyOnlyWetFor(ClipType.none), isTrue);
      expect(back.flyFromFor(ClipType.full), 20);
      expect(back.nightFlyFor(ClipType.full), 12);
      expect(back.flyRain, isFalse);
      expect(back.sunny, 1);
      expect(back.fullSun, 6);
      expect(back.isDefault, isFalse);
    });
  });

  group('eigen dekens uitgebreid', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.full);

    test('bij regen geen waterdichte: toch de dichtstbijzijnde, met waarschuwing', () {
      final stal = Blanket(
          id: 's', name: 'Staldeken', kind: BlanketKind.stable, grams: 200, waterproof: false);
      final a = advisor.advise(h, period(temp: 9, precip: 6, night: false));
      expect(a.wet, isTrue);
      final p = BlanketPicker.pick(h, a, [stal])!;
      expect(p.main.id, 's');
      expect(p.warning, contains('regent'));
    });

    test('waterdicht gaat voor bij regen', () {
      final stal = Blanket(
          id: 's', name: 'Staldeken', kind: BlanketKind.stable, grams: 200, waterproof: false);
      final rain = Blanket(id: 'r', name: 'Regen', kind: BlanketKind.rain, grams: 0);
      final a = advisor.advise(h, period(temp: 9, precip: 6, night: false));
      final p = BlanketPicker.pick(h, a, [stal, rain])!;
      expect(p.main.waterproof, isTrue);
      expect(p.warning, isNull);
    });

    test('eigen bereik gaat voor op de vulling', () {
      final a = advisor.advise(h, period(temp: 6, night: false)); // middel, voelt 6 °C
      expect(a.level, BlanketLevel.medium);
      final b200 = Blanket(id: 'b', name: 'Winter', kind: BlanketKind.turnout, grams: 200);
      // 100 g, maar volgens de eigenaar goed van 3 tot 10 °C
      final own = Blanket(
          id: 'o', name: 'Eigen', kind: BlanketKind.turnout, grams: 100,
          minTemp: 3, maxTemp: 10);
      final p = BlanketPicker.pick(h, a, [b200, own])!;
      expect(p.main.id, 'o');
      expect(p.matches, isTrue);
    });

    test('te lichte deken: dichtstbijzijnde met melding', () {
      final a = advisor.advise(h, period(temp: -6)); // extra zwaar
      final b100 = Blanket(id: 'a', name: 'Licht', kind: BlanketKind.turnout, grams: 100);
      final p = BlanketPicker.pick(h, a, [b100])!;
      expect(p.fit, -1);
      expect(p.fitNote, contains('fleece'));
    });

    test('zon en warm: zonwerende deken gaat voor', () {
      // volledig geschoren, 'geen deken' pas vanaf 25 °C; 16 °C met volle
      // zon voelt als 20 °C → regendeken
      final custom = BlanketAdvisor(
          AdviceSettings.defaults
              .withThreshold(ClipType.full, 0, 25)
              .withFlyFrom(ClipType.full, 25));
      final a = custom.advise(h, period(temp: 16, night: false, sun: 1));
      expect(a.sunnyWarm, isTrue);
      expect(a.level, BlanketLevel.rainSheet);
      final plain = Blanket(id: 'p', name: 'Gewoon', kind: BlanketKind.rain, grams: 0);
      final sun = Blanket(
          id: 'z', name: 'Zon', kind: BlanketKind.rain, grams: 0, sunProtect: true);
      expect(BlanketPicker.pick(h, a, [plain, sun])!.main.id, 'z');
    });

    test('oude opgeslagen deken: nieuwe velden standaard uit', () {
      final b = Blanket.fromJson({'id': 'x', 'name': 'Oud', 'kind': 'turnout', 'grams': 150});
      expect(b.sunProtect, isFalse);
      expect(b.hasOwnRange, isFalse);
      final back = Blanket.fromJson(
          Blanket(id: 'y', name: 'Nieuw', sunProtect: true, minTemp: 2, maxTemp: 9).toJson());
      expect(back.sunProtect, isTrue);
      expect(back.minTemp, 2);
      expect(back.maxTemp, 9);
    });
  });

  group('weercorrecties niet optellen', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial); // geen deken vanaf 15

    test('17 °C, droog, wind 25 km/u → 15 °C → geen deken', () {
      final a = advisor.advise(h, period(temp: 17, night: false, wind: 25));
      expect(a.baseTemp, 17);
      expect(a.effectiveTemp, 15);
      expect(a.level, BlanketLevel.none);
    });

    test('14 °C, regen, wind 25 km/u → 14 − 3 − 1 = 10 °C → regendeken', () {
      final a = advisor.advise(h, period(temp: 14, night: false, wind: 25, precip: 6));
      expect(a.effectiveTemp, 10);
      expect(a.level, BlanketLevel.rainSheet);
    });

    test('12 °C, droog, windstil, volle zon → 16 °C → geen deken', () {
      final a = advisor.advise(h, period(temp: 12, night: false, sun: 1));
      expect(a.effectiveTemp, 16);
      expect(a.level, BlanketLevel.none);
    });

    test('harde wind en regen: grootste + 1, zon telt niet bij regen', () {
      final a = advisor.advise(h, period(temp: 14, night: false, wind: 40, precip: 6, sun: 1));
      expect(a.effectiveTemp, 14 - 4); // max(4, 3) + 1 = 5, begrensd op −4
    });

    test('correctie alleen in uren waarin de factor speelt', () {
      final start = DateTime(2026, 10, 13, 12);
      final hours = [
        for (var i = 0; i < 6; i++)
          HourWeather(
            time: start.add(Duration(hours: i)),
            temp: 17, feels: 13, precipProb: 0, precip: 0, code: 2,
            wind: i < 3 ? 25 : 5, // de helft van de uren waait het
            humidity: 80,
          ),
      ];
      final w = PeriodWeather.fromHours(hours,
          start: start, end: start.add(const Duration(hours: 6)),
          isNight: false, label: 'Middag');
      final a = advisor.advise(h, w);
      expect(a.effectiveTemp, 16); // gemiddeld −1, niet −2
    });

    test('gevoelstemperatuur van de weerdienst wordt niet gebruikt', () {
      // 'feels' staat in period() gelijk aan temp; hier lager: geen effect.
      final start = DateTime(2026, 10, 13, 12);
      final hours = [
        for (var i = 0; i < 6; i++)
          HourWeather(
            time: start.add(Duration(hours: i)),
            temp: 17, feels: 11, precipProb: 0, precip: 0, code: 2, wind: 5,
            humidity: 80,
          ),
      ];
      final w = PeriodWeather.fromHours(hours,
          start: start, end: start.add(const Duration(hours: 6)),
          isNight: false, label: 'Middag');
      expect(advisor.advise(h, w).effectiveTemp, 17);
    });
  });

  group('eigen bereik van dekens', () {
    final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial); // regendeken 10–15
    final a = Blanket(id: 'A', name: 'Deken A', kind: BlanketKind.rain, grams: 0);
    final b = Blanket(
        id: 'B', name: 'Deken B', kind: BlanketKind.rain, grams: 0, minTemp: 5, maxTemp: 10);

    BlanketPick? pickAt(double temp, {bool night = false, List<Blanket>? all}) {
      final adv = advisor.advise(h, period(temp: temp, night: night));
      return BlanketPicker.pick(h, adv, all ?? [a, b]);
    }

    test('13 °C → deken A', () => expect(pickAt(13)!.main.id, 'A'));
    test('7 °C → deken B', () => expect(pickAt(7)!.main.id, 'B'));
    test('7 °C nacht → deken B', () => expect(pickAt(7, night: true)!.main.id, 'B'));
    test('grenzen tellen mee: 10 °C → B mag, 5 °C → B mag', () {
      expect(pickAt(5)!.main.id, 'B');
      // 10 °C is regendeken-klasse: A past, B past ook (max 10); score kiest
      final p = pickAt(10)!;
      expect(p.matches, isTrue);
    });

    test('17 °C → nooit deken B', () {
      expect(pickAt(17)?.main.id, isNot('B'));
      expect(pickAt(17, all: [b]), isNull); // geen deken nodig
      for (final t in [11.0, 12.0, 13.0, 14.0]) {
        expect(pickAt(t)!.main.id, 'A');
      }
    });

    test('alleen B en te warm: dichtstbijzijnde met melding', () {
      final p = pickAt(13, all: [b])!;
      expect(p.main.id, 'B');
      expect(p.matches, isFalse);
      expect(p.fitNote, 'buiten ingesteld bereik (max 10 °C)');
    });

    test('na opnieuw laden werkt het bereik nog', () {
      final b2 = Blanket.fromJson(b.toJson());
      expect(b2.minTemp, 5);
      expect(b2.maxTemp, 10);
      expect(pickAt(13, all: [a, b2])!.main.id, 'A');
      expect(pickAt(7, all: [a, b2])!.main.id, 'B');
    });
  });

  group('dekenwissels per dag', () {
    // Dag 09–18 en nacht 18–09, met een temperatuurverloop van [lo] tot [hi].
    PeriodWeather slot({
      required bool night,
      required double lo,
      required double hi,
      double precip = 0,
      double wind = 5,
    }) {
      final start = DateTime(2026, 10, 13, night ? 18 : 9);
      final n = night ? 15 : 9;
      final hours = [
        for (var i = 0; i < n; i++)
          HourWeather(
            time: start.add(Duration(hours: i)),
            // overdag oplopend naar hi, 's nachts aflopend naar lo
            temp: night ? hi - (hi - lo) * i / (n - 1) : lo + (hi - lo) * i / (n - 1),
            feels: 0,
            precipProb: precip > 0 ? 80 : 0,
            precip: precip,
            code: precip > 0 ? 61 : 2,
            wind: wind,
            humidity: 85,
          ),
      ];
      return PeriodWeather.fromHours(hours,
          start: start,
          end: start.add(Duration(hours: n)),
          isNight: night,
          label: night ? 'Avond & nacht' : 'Overdag');
    }

    test("10° / 19° droog, '1 keer': overdag geen deken, nacht volgens nachtgrenzen", () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final day = advisor.advise(h, slot(night: false, lo: 15, hi: 19));
      final night = advisor.advise(h, slot(night: true, lo: 10, hi: 15));
      expect(day.level, BlanketLevel.none);
      expect(night.effectiveTemp, 10);
      expect(night.level, BlanketLevel.none); // geen deken 's nachts vanaf 10°
    });

    test("10° / 19° droog, 'Geen': één advies voor het etmaal", () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final day = advisor.advise(h, slot(night: false, lo: 15, hi: 19));
      final night = advisor.advise(h, slot(night: true, lo: 10, hi: 15));
      final all = advisor.wholeDay(day, night, h.clip);
      expect(all.level, BlanketLevel.none);
      expect(all.wholeDay, isTrue);
    });

    test("'Geen': nachtdeken overdag te warm → lichtere deken met melding", () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      // dag gemiddeld 12 °C (regendeken), nacht 8 °C (lichte deken)
      final day = advisor.advise(h, slot(night: false, lo: 10, hi: 14));
      final night = advisor.advise(h, slot(night: true, lo: 8, hi: 12));
      expect(day.level, BlanketLevel.rainSheet);
      expect(night.level, BlanketLevel.light);
      final all = advisor.wholeDay(day, night, h.clip);
      expect(all.level, BlanketLevel.rainSheet);
      expect(all.notes.first,
          "Overdag te warm voor de lichte deken (12 °C). Kies de regendeken; 's nachts is het rond 8 °C.");
    });

    test("'Geen': nachtdeken past overdag nog → nachtdeken", () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final day = advisor.advise(h, slot(night: false, lo: 7, hi: 9)); // 8 °C: licht
      final night = advisor.advise(h, slot(night: true, lo: 3, hi: 7)); // 3 °C: middel
      expect(night.level, BlanketLevel.medium);
      final all = advisor.wholeDay(day, night, h.clip);
      // middel tot 5 °C; overdag 8 °C is te warm → lichte deken
      expect(all.level, BlanketLevel.light);
      final cold = advisor.wholeDay(
          advisor.advise(h, slot(night: false, lo: 3, hi: 5)), night, h.clip);
      expect(cold.level, BlanketLevel.medium);
    });

    test("'Geen': eigen maximum van de nachtdeken telt", () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final day = advisor.advise(h, slot(night: false, lo: 7, hi: 9)); // 8 °C: licht
      final night = advisor.advise(h, slot(night: true, lo: 3, hi: 7)); // 3 °C: middel
      expect(night.level, BlanketLevel.medium);
      // eigen deken voor de nacht tot 9 °C: past overdag (8 °C) nog
      expect(advisor.wholeDay(day, night, h.clip, nightMax: 9).level, BlanketLevel.medium);
      // tot 7 °C: overdag te warm → lichte deken
      expect(advisor.wholeDay(day, night, h.clip, nightMax: 7).level, BlanketLevel.light);
    });

    test("12° / 17°, regen overdag, '1 keer': gemiddeld 14,5 °C → regendeken", () {
      final h = Horse(id: '1', name: 'Bella');
      final day = advisor.advise(h, slot(night: false, lo: 12, hi: 17, precip: 0.5));
      expect(day.dryTemp, 14.5);
      expect(day.level, BlanketLevel.rainSheet);
      final warmer = advisor.advise(h, slot(night: false, lo: 14, hi: 19, precip: 0.5));
      expect(warmer.level, BlanketLevel.flyRain); // gemiddeld 16,5 °C
    });

    test('lichte regen in een paar uur telt ook als nat (regenstuk)', () {
      final h = Horse(id: '1', name: 'Bella', clip: ClipType.partial);
      final start = DateTime(2026, 10, 13, 9);
      final hours = [
        for (var i = 0; i < 9; i++)
          HourWeather(
            time: start.add(Duration(hours: i)),
            temp: 17, feels: 0, precipProb: 30,
            precip: i < 3 ? 0.25 : 0, // samen 0,75 mm
            code: 61, wind: 5, humidity: 85,
          ),
      ];
      final w = PeriodWeather.fromHours(hours,
          start: start, end: start.add(const Duration(hours: 9)),
          isNight: false, label: 'Overdag');
      expect(advisor.advise(h, w).level, BlanketLevel.flyRain);
    });

    test('instellingen: standaard 1 keer, 09–18, opslaan en teruglezen', () {
      const d = AdviceSettings.defaults;
      expect(d.blanketChanges, 1);
      expect((d.dayStart, d.dayEnd), (9, 18));
      final t = d.copyWith(blanketChanges: 0).withDayTimes(start: 8, end: 19);
      final back = AdviceSettings.fromJson(t.toJson());
      expect(back.blanketChanges, 0);
      expect((back.dayStart, back.dayEnd), (8, 19));
      expect(AdviceSettings.fromJson({}).blanketChanges, 1);
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
