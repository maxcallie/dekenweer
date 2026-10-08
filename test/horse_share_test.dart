import 'package:dekenweer/logic/horse_share.dart';
import 'package:dekenweer/models/blanket.dart';
import 'package:dekenweer/models/care.dart';
import 'package:dekenweer/models/horse.dart';
import 'package:dekenweer/models/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nero = Horse(id: 'n1', name: 'Nero', coat: CoatColor.chestnut)
    ..stableBlanket = 'b-stal';
  final other = Horse(id: 'x9', name: 'Storm');
  final blankets = [
    Blanket(id: 'b-stal', name: 'Staldeken', kind: BlanketKind.stable, grams: 200,
        horseIds: ['n1', 'x9']),
    Blanket(id: 'b-alg', name: 'Regendeken', kind: BlanketKind.rain, grams: 0),
    Blanket(id: 'b-storm', name: 'Van Storm', kind: BlanketKind.turnout, grams: 100,
        horseIds: ['x9']),
  ];
  final care = [
    CareRecord(id: 'c1', horseId: 'n1', kind: CareKind.vaccination,
        date: DateTime(2026, 3, 1), name: 'Influenza', vaccineId: 'v1',
        next: DateTime(2027, 3, 1)),
    CareRecord(id: 'c2', horseId: 'x9', kind: CareKind.fecalTest,
        date: DateTime(2026, 4, 1), epg: 100),
  ];
  final vaccines = [
    VaccineType(id: 'v1', name: 'Influenza'),
    VaccineType(id: 'v2', name: 'Tetanus', intervalMonths: 24),
  ];

  HorsePackage pkg({bool withBlankets = true}) => HorsePackage.of(nero,
      allBlankets: blankets,
      allCare: care,
      allVaccines: vaccines,
      withBlankets: withBlankets,
      seasons: SeasonSettings.defaults.withStart(Season.winter, 10, 15));

  test('alleen wat bij dit paard hoort gaat mee', () {
    final p = pkg();
    expect(p.blankets.map((b) => b.id), ['b-stal', 'b-alg']);
    // koppeling met het andere paard van de afzender gaat niet mee
    expect(p.blankets.first.horseIds, ['n1']);
    expect(p.blankets[1].horseIds, isEmpty);
    expect(p.care.map((r) => r.id), ['c1']);
    expect(p.vaccines.map((v) => v.id), ['v1']);
    // het origineel blijft ongewijzigd
    expect(blankets.first.horseIds, ['n1', 'x9']);
    expect(other.name, 'Storm');
  });

  test('link heen en terug', () {
    final p = pkg();
    final link = p.link(Uri.parse('https://maxcallie.github.io/dekenweer/'));
    expect(link, startsWith('https://maxcallie.github.io/dekenweer/?paard='));
    final back = HorsePackage.decode('Hier is Nero voor Dekenweer 🐴 $link')!;
    expect(back.horse.name, 'Nero');
    expect(back.horse.id, 'n1');
    expect(back.blankets.length, 2);
    expect(back.care.single.next, DateTime(2027, 3, 1));
    expect(back.seasons!.winterMonth, 10);
    expect(back.advice, isNull);
  });

  test('zonder dekens vervalt de keuze voor de staldeken', () {
    final p = pkg(withBlankets: false);
    expect(p.blankets, isEmpty);
    expect(p.horse.stableBlanket, isNull);
    expect(nero.stableBlanket, 'b-stal');
  });

  test('onzin geeft null', () {
    expect(HorsePackage.decode('hallo'), isNull);
    expect(HorsePackage.decode('https://x.nl/?paard=abc'), isNull);
  });
}
