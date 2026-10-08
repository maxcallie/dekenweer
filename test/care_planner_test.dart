import 'package:dekenweer/logic/care_planner.dart';
import 'package:dekenweer/models/care.dart';
import 'package:flutter_test/flutter_test.dart';

CareRecord rec(CareKind kind, DateTime date,
        {String horse = 'h1', String name = '', String? vac, DateTime? next, int? epg, bool check = false}) =>
    CareRecord(
      id: '${date.microsecondsSinceEpoch}$name$horse',
      horseId: horse,
      kind: kind,
      date: date,
      name: name,
      vaccineId: vac,
      next: next,
      epg: epg,
      checkAfter: check,
    );

void main() {
  const s = CareSettings.defaults;

  test('maanden optellen, ook aan het eind van de maand', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    expect(addMonths(DateTime(2026, 5, 10), 12), DateTime(2027, 5, 10));
  });

  test('alleen de laatste vaccinatie van hetzelfde vaccin telt', () {
    final plan = CarePlanner.plan([
      rec(CareKind.vaccination, DateTime(2025, 3, 1), name: 'Influenza', vac: 'i',
          next: DateTime(2026, 3, 1)),
      rec(CareKind.vaccination, DateTime(2026, 3, 2), name: 'Influenza', vac: 'i',
          next: DateTime(2027, 3, 2)),
      rec(CareKind.vaccination, DateTime(2025, 6, 1), name: 'Tetanus', vac: 't',
          next: DateTime(2027, 6, 1)),
    ], s);
    expect(plan.map((d) => d.due), [DateTime(2027, 3, 2), DateTime(2027, 6, 1)]);
  });

  test('hoge uitslag: kuur nodig, tot er een kuur is gegeven', () {
    final test = rec(CareKind.fecalTest, DateTime(2026, 9, 1), epg: 450);
    var plan = CarePlanner.plan([test], s);
    expect(plan.single.urgent, isTrue);
    expect(plan.single.kind, CareKind.deworming);

    plan = CarePlanner.plan(
        [test, rec(CareKind.deworming, DateTime(2026, 9, 3), name: 'Equest')], s);
    expect(plan.any((d) => d.urgent), isFalse);
    expect(plan.single.title, 'Mestonderzoek');
    expect(plan.single.due, DateTime(2026, 12, 1));
  });

  test('lage uitslag: volgend mestonderzoek na de ingestelde termijn', () {
    final plan = CarePlanner.plan([rec(CareKind.fecalTest, DateTime(2026, 4, 10), epg: 50)], s);
    expect(plan.single.due, DateTime(2026, 7, 10));
    expect(plan.single.urgent, isFalse);
  });

  test('controle na kuur verdwijnt na een nieuw mestonderzoek', () {
    final kuur = rec(CareKind.deworming, DateTime(2026, 10, 1), check: true);
    var plan = CarePlanner.plan([kuur], s);
    expect(plan.single.title, 'Controle na kuur');
    expect(plan.single.due, DateTime(2026, 10, 15));
    plan = CarePlanner.plan([kuur, rec(CareKind.fecalTest, DateTime(2026, 10, 15), epg: 0)], s);
    expect(plan.any((d) => d.title == 'Controle na kuur'), isFalse);
  });

  test('registraties van verwijderde paarden tellen niet mee', () {
    final plan = CarePlanner.plan([
      rec(CareKind.vaccination, DateTime(2026, 1, 1), horse: 'weg', name: 'Influenza',
          next: DateTime(2027, 1, 1)),
    ], s, horseIds: ['h1']);
    expect(plan, isEmpty);
  });

  test('herinnering binnen de ingestelde dagen', () {
    final now = DateTime(2026, 10, 8);
    final plan = CarePlanner.plan([
      rec(CareKind.vaccination, DateTime(2025, 10, 15), name: 'Influenza',
          next: DateTime(2026, 10, 15)),
      rec(CareKind.vaccination, DateTime(2025, 12, 1), name: 'Tetanus',
          next: DateTime(2026, 12, 1)),
    ], s);
    final soon = CarePlanner.soon(plan, s, now);
    expect(soon.single.title, 'Influenza');
    expect(dueLabel(soon.single.daysFrom(now)), 'over 7 dagen');
  });

  test('opslaan en teruglezen', () {
    final r = rec(CareKind.fecalTest, DateTime(2026, 2, 3), epg: 120)..note = 'lab';
    final back = CareRecord.fromJson(r.toJson());
    expect(back.epg, 120);
    expect(back.note, 'lab');
    expect(back.kind, CareKind.fecalTest);
  });
}
