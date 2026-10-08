import '../models/care.dart';

/// Iets wat (binnenkort) moet gebeuren voor een paard.
class CareDue {
  const CareDue({
    required this.horseId,
    required this.kind,
    required this.title,
    required this.due,
    this.name = '',
    this.vaccineId,
    this.urgent = false,
  });

  final String horseId;
  final CareKind kind;

  /// Korte omschrijving, bijv. "Influenza" of "Wormenkuur nodig".
  final String title;
  final DateTime due;

  /// Vaccin- of middelnaam om het formulier mee voor te vullen.
  final String name;
  final String? vaccineId;

  /// Direct actie nodig (bijv. kuur na een hoge uitslag).
  final bool urgent;

  /// Aantal dagen vanaf [now] (negatief = te laat).
  int daysFrom(DateTime now) => _day(due).difference(_day(now)).inDays;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Bepaalt uit de registraties wat er per paard op de planning staat.
class CarePlanner {
  const CarePlanner._();

  /// Dagen na een kuur voor het controle-mestonderzoek.
  static const checkAfterDays = 14;

  static List<CareDue> plan(
    List<CareRecord> records,
    CareSettings settings, {
    Iterable<String>? horseIds,
  }) {
    final ids = horseIds?.toSet();
    final byHorse = <String, List<CareRecord>>{};
    for (final r in records) {
      if (ids != null && !ids.contains(r.horseId)) continue;
      byHorse.putIfAbsent(r.horseId, () => []).add(r);
    }

    final result = <CareDue>[];
    byHorse.forEach((horseId, list) {
      list.sort((a, b) => a.date.compareTo(b.date));

      // Vaccinaties en vaste kuren: de laatste per schema telt.
      final latest = <String, CareRecord>{};
      for (final r in list) {
        if (r.kind == CareKind.fecalTest) continue;
        latest[r.scheduleKey] = r;
      }
      for (final r in latest.values) {
        final next = r.next;
        if (next == null) continue;
        final vac = r.kind == CareKind.vaccination;
        result.add(CareDue(
          horseId: horseId,
          kind: r.kind,
          title: vac
              ? (r.name.isEmpty ? 'Vaccinatie' : r.name)
              : (r.name.isEmpty ? 'Wormenkuur' : 'Wormenkuur (${r.name})'),
          due: next,
          name: r.name,
          vaccineId: r.vaccineId,
        ));
      }

      final tests = list.where((r) => r.kind == CareKind.fecalTest).toList();
      final kuren = list.where((r) => r.kind == CareKind.deworming).toList();

      // Controle-mestonderzoek na een kuur.
      final lastKuur = kuren.isEmpty ? null : kuren.last;
      if (lastKuur != null && lastKuur.checkAfter) {
        final checked = tests.any((t) => t.date.isAfter(lastKuur.date));
        if (!checked) {
          result.add(CareDue(
            horseId: horseId,
            kind: CareKind.fecalTest,
            title: 'Controle na kuur',
            due: lastKuur.date.add(const Duration(days: checkAfterDays)),
          ));
        }
      }

      // Mestonderzoek: kuur nodig bij een hoge uitslag, anders het volgende
      // onderzoek na de ingestelde termijn.
      if (tests.isNotEmpty) {
        final t = tests.last;
        final high = t.epg != null && t.epg! >= settings.epgThreshold;
        final treated = kuren.any((k) => !k.date.isBefore(_day(t.date)));
        if (high && !treated) {
          result.add(CareDue(
            horseId: horseId,
            kind: CareKind.deworming,
            title: 'Wormenkuur nodig (${t.epg} EPG)',
            due: t.date,
            urgent: true,
          ));
        } else {
          result.add(CareDue(
            horseId: horseId,
            kind: CareKind.fecalTest,
            title: 'Mestonderzoek',
            due: addMonths(t.date, settings.testIntervalMonths),
          ));
        }
      }
    });

    result.sort((a, b) => a.due.compareTo(b.due));
    return result;
  }

  /// Wat binnen [CareSettings.remindDays] dagen moet (of al te laat is).
  static List<CareDue> soon(List<CareDue> plan, CareSettings settings, DateTime now) =>
      plan.where((d) => d.urgent || d.daysFrom(now) <= settings.remindDays).toList();
}

/// "vandaag", "over 5 dagen", "3 dagen te laat", …
String dueLabel(int days) {
  if (days < -1) return '${-days} dagen te laat';
  if (days == -1) return '1 dag te laat';
  if (days == 0) return 'vandaag';
  if (days == 1) return 'morgen';
  if (days < 60) return 'over $days dagen';
  final months = (days / 30.4).round();
  return 'over $months maanden';
}
