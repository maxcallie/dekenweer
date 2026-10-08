import 'package:flutter/material.dart';

/// Soort zorg-registratie.
enum CareKind {
  vaccination('Vaccinatie', Icons.vaccines),
  deworming('Wormenkuur', Icons.medication),
  fecalTest('Mestonderzoek', Icons.science);

  const CareKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Een vaccin dat je zelf hebt toegevoegd, met de standaardtermijn tot de
/// volgende enting.
class VaccineType {
  VaccineType({required this.id, required this.name, this.intervalMonths = 12});

  final String id;
  String name;
  int intervalMonths;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'intervalMonths': intervalMonths};

  factory VaccineType.fromJson(Map<String, dynamic> j) => VaccineType(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        intervalMonths: (j['intervalMonths'] as num?)?.toInt() ?? 12,
      );
}

/// Snelkeuzes bij het toevoegen van een vaccin (naam + gebruikelijke termijn).
const vaccineSuggestions = <(String, int)>[
  ('Influenza', 12),
  ('Tetanus', 24),
  ('Influenza + tetanus', 12),
  ('Rhinopneumonie', 6),
];

/// Eén registratie: een vaccinatie, wormenkuur of mestonderzoek.
class CareRecord {
  CareRecord({
    required this.id,
    required this.horseId,
    required this.kind,
    required this.date,
    this.name = '',
    this.vaccineId,
    this.next,
    this.epg,
    this.checkAfter = false,
    this.note = '',
  });

  final String id;
  String horseId;
  CareKind kind;
  DateTime date;

  /// Vaccin- of middelnaam.
  String name;

  /// Bij een vaccinatie: welk vaccin uit je lijst.
  String? vaccineId;

  /// Wanneer de volgende (vaccinatie of vaste kuur) moet; null = geen.
  DateTime? next;

  /// Mestonderzoek: aantal eieren per gram mest (null = uitslag onbekend).
  int? epg;

  /// Wormenkuur: na 2 weken een controle-mestonderzoek.
  bool checkAfter;

  String note;

  /// Groepeert registraties die bij hetzelfde schema horen.
  String get scheduleKey => switch (kind) {
        CareKind.vaccination => 'v:${vaccineId ?? name.trim().toLowerCase()}',
        CareKind.deworming => 'd:${name.trim().toLowerCase()}',
        CareKind.fecalTest => 'f',
      };

  CareRecord copy() => CareRecord.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'horseId': horseId,
        'kind': kind.name,
        'date': date.toIso8601String(),
        'name': name,
        'vaccineId': vaccineId,
        'next': next?.toIso8601String(),
        'epg': epg,
        'checkAfter': checkAfter,
        'note': note,
      };

  factory CareRecord.fromJson(Map<String, dynamic> j) => CareRecord(
        id: j['id'] as String,
        horseId: j['horseId'] as String,
        kind: CareKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => CareKind.vaccination),
        date: DateTime.parse(j['date'] as String),
        name: j['name'] as String? ?? '',
        vaccineId: j['vaccineId'] as String?,
        next: j['next'] == null ? null : DateTime.parse(j['next'] as String),
        epg: (j['epg'] as num?)?.toInt(),
        checkAfter: j['checkAfter'] as bool? ?? false,
        note: j['note'] as String? ?? '',
      );
}

/// Instellingen voor ontworming en herinneringen.
class CareSettings {
  const CareSettings({
    this.epgThreshold = 200,
    this.testIntervalMonths = 3,
    this.remindDays = 14,
  });

  /// Vanaf zoveel eieren per gram wordt een kuur aangeraden.
  final int epgThreshold;

  /// Na zoveel maanden het volgende mestonderzoek.
  final int testIntervalMonths;

  /// Zoveel dagen van tevoren verschijnt een herinnering.
  final int remindDays;

  static const defaults = CareSettings();

  CareSettings copyWith({int? epgThreshold, int? testIntervalMonths, int? remindDays}) =>
      CareSettings(
        epgThreshold: epgThreshold ?? this.epgThreshold,
        testIntervalMonths: testIntervalMonths ?? this.testIntervalMonths,
        remindDays: remindDays ?? this.remindDays,
      );

  Map<String, dynamic> toJson() => {
        'epgThreshold': epgThreshold,
        'testIntervalMonths': testIntervalMonths,
        'remindDays': remindDays,
      };

  factory CareSettings.fromJson(Map<String, dynamic> j) => CareSettings(
        epgThreshold: (j['epgThreshold'] as num?)?.toInt() ?? 200,
        testIntervalMonths: (j['testIntervalMonths'] as num?)?.toInt() ?? 3,
        remindDays: (j['remindDays'] as num?)?.toInt() ?? 14,
      );
}

/// [d] plus [months] maanden (31 jan + 1 maand = 28/29 feb).
DateTime addMonths(DateTime d, int months) {
  final m0 = d.month - 1 + months;
  final y = d.year + (m0 >= 0 ? m0 ~/ 12 : (m0 - 11) ~/ 12);
  final m = m0 % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}
