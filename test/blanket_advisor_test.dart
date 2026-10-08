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
