import 'package:flutter/material.dart';

/// Vachtkleur van het paard (bepaalt hoe het getekend wordt).
enum CoatColor {
  bay('Bruin', Color(0xFF7A4526), Color(0xFF1E1410), Color(0xFF231812)),
  chestnut('Vos', Color(0xFFBC6431), Color(0xFFA4502A), Color(0xFFB05C2E)),
  black('Zwart', Color(0xFF2A2523), Color(0xFF141110), Color(0xFF141110)),
  grey('Schimmel', Color(0xFFD9D6D0), Color(0xFFB9B5AE), Color(0xFF9E9A94)),
  // Witte schimmel met fijne donkere spikkeltjes ("flea-bitten"), veel
  // gezien bij oudere schimmels en Spanjaarden (PRE).
  fleabitten('Vliegenschimmel', Color(0xFFEFECE6), Color(0xFFD9D2C4), Color(0xFFE2DED6),
      flecks: Color(0xFF7A6658)),
  palomino('Palomino', Color(0xFFE0B465), Color(0xFFF6EBD0), Color(0xFFCF9F55)),
  dun('Valk', Color(0xFFC9A774), Color(0xFF2B211A), Color(0xFF3A2C20)),
  pinto('Bont', Color(0xFF8A5230), Color(0xFF2E211A), Color(0xFF6E4127)),
  appaloosa('Tijger', Color(0xFFEDE7DC), Color(0xFF5B4A3E), Color(0xFF8F8378)),

  // Roan: witte haren door de rompvacht, hoofd, benen, manen en staart
  // blijven in de basiskleur. Wordt, anders dan een schimmel, niet witter
  // met de jaren.
  bayRoan('Roan (bruin)', Color(0xFFA48577), Color(0xFF1E1410), Color(0xFF231812),
      head: Color(0xFF6B3D24)),
  strawberryRoan('Roan (vos)', Color(0xFFC99A84), Color(0xFF8A4520), Color(0xFF7A3D1C),
      head: Color(0xFFA0552A)),
  blueRoan('Roan (blauw)', Color(0xFF7E828B), Color(0xFF141110), Color(0xFF141110),
      head: Color(0xFF2E2927));

  const CoatColor(this.label, this.body, this.mane, this.legs, {this.head, this.flecks});
  final String label;
  final Color body;
  final Color mane;
  final Color legs;

  /// Kleur van hoofd en bovenbenen als die afwijkt van de romp (spanjaard).
  final Color? head;

  bool get isRoan => head != null;

  /// Kleur van fijne spikkeltjes (vliegenschimmel).
  final Color? flecks;

  /// Schimmels hebben een donkere huid rond de neus.
  bool get isGrey => this == CoatColor.grey || this == CoatColor.fleabitten;
}

/// Witte aftekening op het hoofd.
enum Blaze {
  none('Geen'),
  star('Kol'),
  stripe('Smalle bles'),
  wide('Brede bles');

  const Blaze(this.label);
  final String label;
}

/// Witte aftekening op een been.
enum LegMark {
  none('Geen'),
  sock('Sok'),
  stocking('Kous');

  const LegMark(this.label);
  final String label;
}

/// Volgorde van de benen in [Horse.legs].
const legNames = ['Linksvoor', 'Rechtsvoor', 'Linksachter', 'Rechtsachter'];

enum HorseType {
  pony('Pony', 'Shetlander, Welsh, Fjord e.d.'),
  coldblood('Koudbloed', 'Fries, Haflinger, trekpaard'),
  warmblood('Warmbloed', 'KWPN, sportpaard'),
  baroque('Barok', 'Spanjaard (PRE), Lusitano, Andalusiër'),
  hotblood('Volbloed', 'Arabier, Engelse volbloed');

  const HorseType(this.label, this.hint);
  final String label;
  final String hint;
}

enum ClipType {
  none('Niet geschoren'),
  partial('Deels geschoren'),
  full('Volledig geschoren');

  const ClipType(this.label);
  final String label;
}

enum BodyCondition {
  thin('Aan de magere kant'),
  normal('Normaal'),
  heavy('Goed in vlees');

  const BodyCondition(this.label);
  final String label;
}

enum Sensitivity {
  cold('Heeft het snel koud'),
  normal('Gemiddeld'),
  warm('Heeft het snel warm');

  const Sensitivity(this.label);
  final String label;
}

enum Housing {
  schedule('Volgt het stalschema', 'Binnen of buiten volgens het seizoen'),
  outside('Altijd buiten', 'Ook \'s nachts, zonder schuilstal'),
  shelter('Altijd buiten, met schuilstal', 'Kan zelf schuilen voor wind en regen');

  const Housing(this.label, this.hint);
  final String label;
  final String hint;
}

/// Kleuren waaruit je de kleur van de deken in de tekening kunt kiezen.
const blanketColors = <Color>[
  Color(0xFF1F3A5F), // navy
  Color(0xFF2E6B3F), // groen
  Color(0xFF8E2C3A), // bordeaux
  Color(0xFF3C3C46), // antraciet
  Color(0xFF5A3E8E), // paars
  Color(0xFF2B7A8C), // petrol
  Color(0xFFB5652B), // cognac
  Color(0xFFD6A21E), // oker
];

class Horse {
  Horse({
    required this.id,
    required this.name,
    this.coat = CoatColor.bay,
    this.type = HorseType.warmblood,
    this.age = 10,
    this.clip = ClipType.none,
    this.condition = BodyCondition.normal,
    this.sensitivity = Sensitivity.normal,
    this.housing = Housing.schedule,
    this.blanketColorValue = 0xFF1F3A5F,
    this.blaze = Blaze.none,
    List<LegMark>? legs,
    this.stableBlanket,
  }) : legs = legs ?? List.filled(4, LegMark.none);

  final String id;
  String name;
  CoatColor coat;
  HorseType type;
  int age;
  ClipType clip;
  BodyCondition condition;
  Sensitivity sensitivity;
  Housing housing;
  int blanketColorValue;
  Blaze blaze;

  /// Linksvoor, rechtsvoor, linksachter, rechtsachter.
  List<LegMark> legs;

  /// Deken op stal: `null` = volgens het advies, [noBlanket] = geen deken,
  /// anders het id van een deken uit de dekenkast.
  String? stableBlanket;

  static const noBlanket = 'none';

  Color get blanketColor => Color(blanketColorValue);

  Horse copy() => Horse.fromJson(toJson());

  /// Easter egg: Nero is blind aan zijn linkeroog. Een paard dat Nero heet,
  /// krijgt daarom een licht melkachtig linkeroog.
  bool get blindLeftEye => name.trim().toLowerCase() == 'nero';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coat': coat.name,
        'type': type.name,
        'age': age,
        'clip': clip.name,
        'condition': condition.name,
        'sensitivity': sensitivity.name,
        'housing': housing.name,
        'blanketColor': blanketColorValue,
        'blaze': blaze.name,
        'legs': [for (final l in legs) l.name],
        'stableBlanket': stableBlanket,
      };

  factory Horse.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return Horse(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Paard',
      coat: pick(CoatColor.values, j['coat'], CoatColor.bay),
      type: pick(HorseType.values, j['type'], HorseType.warmblood),
      age: (j['age'] as num?)?.toInt() ?? 10,
      clip: pick(ClipType.values, j['clip'], ClipType.none),
      condition: pick(BodyCondition.values, j['condition'], BodyCondition.normal),
      sensitivity: pick(Sensitivity.values, j['sensitivity'], Sensitivity.normal),
      // oude waarde 'stableAtNight' (voor het stalschema bestond) → schema
      housing: pick(Housing.values, j['housing'], Housing.schedule),
      blanketColorValue: (j['blanketColor'] as num?)?.toInt() ?? 0xFF1F3A5F,
      blaze: pick(Blaze.values, j['blaze'], Blaze.none),
      legs: () {
        final raw = (j['legs'] as List?) ?? const [];
        return List<LegMark>.generate(4,
            (i) => i < raw.length ? pick(LegMark.values, raw[i], LegMark.none) : LegMark.none);
      }(),
      stableBlanket: j['stableBlanket'] as String?,
    );
  }
}
