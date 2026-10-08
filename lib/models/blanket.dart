import 'package:flutter/material.dart';

/// Soort deken. Bepaalt de standaardwaarden in het formulier en of de deken
/// meedoet in het dekenadvies.
enum BlanketKind {
  rain('Regendeken', 'Waterdicht, zonder vulling', true, 0, Icons.water_drop),
  turnout('Buitendeken', 'Waterdicht, met vulling', true, 200, Icons.landscape),
  stable('Staldeken', 'Voor op stal, niet waterdicht', false, 200, Icons.house_siding),
  under('Onderdeken', 'Extra laag onder een andere deken', false, 100, Icons.layers),
  fleece('Fleece / zweetdeken', 'Om op te drogen na het werk', false, 0, Icons.dry),
  fly('Vliegendeken', 'Tegen insecten in de zomer', false, 0, Icons.bug_report);

  const BlanketKind(
      this.label, this.hint, this.defaultWaterproof, this.defaultGrams, this.icon);
  final String label;
  final String hint;
  final bool defaultWaterproof;
  final int defaultGrams;
  final IconData icon;

  /// Kan deze deken als (buitenste) warmtedeken in het advies gekozen worden?
  bool get isMain =>
      this == BlanketKind.rain ||
      this == BlanketKind.turnout ||
      this == BlanketKind.stable;
}

class Blanket {
  Blanket({
    required this.id,
    required this.name,
    this.kind = BlanketKind.turnout,
    this.grams = 200,
    this.waterproof = true,
    this.neck = false,
    this.colorValue = 0xFF1F3A5F,
    List<String>? horseIds,
  }) : horseIds = horseIds ?? [];

  final String id;
  String name;
  BlanketKind kind;

  /// Vulling in gram.
  int grams;
  bool waterproof;

  /// Heeft een (vast of los) halsstuk.
  bool neck;
  int colorValue;

  /// Voor welke paarden de deken past. Leeg = alle paarden.
  List<String> horseIds;

  Color get color => Color(colorValue);

  bool fits(String horseId) => horseIds.isEmpty || horseIds.contains(horseId);

  String get details => [
        kind.label,
        '$grams g',
        if (waterproof) 'waterdicht',
        if (neck) 'halsstuk',
      ].join(' · ');

  Blanket copy() => Blanket.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'grams': grams,
        'waterproof': waterproof,
        'neck': neck,
        'color': colorValue,
        'horses': horseIds,
      };

  factory Blanket.fromJson(Map<String, dynamic> j) => Blanket(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Deken',
        kind: BlanketKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => BlanketKind.turnout),
        grams: (j['grams'] as num?)?.toInt() ?? 0,
        waterproof: j['waterproof'] as bool? ?? false,
        neck: j['neck'] as bool? ?? false,
        colorValue: (j['color'] as num?)?.toInt() ?? 0xFF1F3A5F,
        horseIds: ((j['horses'] as List?) ?? const []).cast<String>().toList(),
      );
}
