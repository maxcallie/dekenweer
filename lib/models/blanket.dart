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

/// Patroon op de deken (in een tweede kleur).
enum BlanketPattern {
  none('Effen'),
  check('Ruit'),
  stripes('Strepen'),
  twoTone('Tweekleurig'),
  pinstripe('Krijtstreep'),
  dots('Stippen'),
  stars('Sterren');

  const BlanketPattern(this.label);
  final String label;
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
    this.pattern = BlanketPattern.none,
    this.color2Value = 0xFFE9D9A8,
    this.brand = '',
    this.sunProtect = false,
    this.minTemp,
    this.maxTemp,
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

  /// Patroon en de kleur van het patroon.
  BlanketPattern pattern;
  int color2Value;

  /// Merknaam op de zij (leeg = niets).
  String brand;

  /// Zonwerend of reflecterend (houdt de zon tegen).
  bool sunProtect;

  /// Eigen temperatuurbereik (gevoelstemperatuur voor het paard, °C). Als
  /// beide zijn ingevuld gaat dit voor op het bereik van het dekengewicht.
  double? minTemp;
  double? maxTemp;

  bool get hasOwnRange => minTemp != null && maxTemp != null;

  /// Voor welke paarden de deken past. Leeg = alle paarden.
  List<String> horseIds;

  Color get color => Color(colorValue);
  Color get color2 => Color(color2Value);

  bool fits(String horseId) => horseIds.isEmpty || horseIds.contains(horseId);

  String get details => [
        kind.label,
        '$grams g',
        if (waterproof) 'waterdicht',
        if (neck) 'halsstuk',
        if (sunProtect) 'zonwerend',
        if (hasOwnRange) '${minTemp!.round()} tot ${maxTemp!.round()}°C',
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
        if (pattern != BlanketPattern.none) 'pattern': pattern.name,
        if (pattern != BlanketPattern.none) 'color2': color2Value,
        if (brand.isNotEmpty) 'brand': brand,
        if (sunProtect) 'sun': true,
        if (hasOwnRange) 'min': minTemp,
        if (hasOwnRange) 'max': maxTemp,
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
        pattern: BlanketPattern.values.firstWhere((p) => p.name == j['pattern'],
            orElse: () => BlanketPattern.none),
        color2Value: (j['color2'] as num?)?.toInt() ?? 0xFFE9D9A8,
        brand: j['brand'] as String? ?? '',
        sunProtect: j['sun'] == true,
        minTemp: (j['min'] as num?)?.toDouble(),
        maxTemp: (j['max'] as num?)?.toDouble(),
        horseIds: ((j['horses'] as List?) ?? const []).cast<String>().toList(),
      );
}
