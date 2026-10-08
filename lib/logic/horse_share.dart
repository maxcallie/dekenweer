import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/advice_settings.dart';
import '../models/blanket.dart';
import '../models/care.dart';
import '../models/horse.dart';
import '../models/season.dart';

/// Eén paard met alles wat erbij hoort, om te delen (bijv. via WhatsApp).
///
/// Het pakketje gaat als tekst in een link mee: geen server nodig. Wie het
/// ontvangt, krijgt een kopie; nog eens delen werkt het paard bij (dezelfde
/// id's), in plaats van het dubbel toe te voegen.
class HorsePackage {
  HorsePackage({
    required this.horse,
    this.blankets = const [],
    this.care = const [],
    this.vaccines = const [],
    this.seasons,
    this.advice,
  });

  static const version = 1;

  /// Naam van de parameter in de link: …/dekenweer/?paard=<code>
  static const linkParam = 'paard';

  final Horse horse;
  final List<Blanket> blankets;
  final List<CareRecord> care;
  final List<VaccineType> vaccines;
  final SeasonSettings? seasons;
  final AdviceSettings? advice;

  /// Stelt het pakketje samen voor [horse].
  factory HorsePackage.of(
    Horse horse, {
    required List<Blanket> allBlankets,
    required List<CareRecord> allCare,
    required List<VaccineType> allVaccines,
    bool withBlankets = true,
    bool withCare = true,
    SeasonSettings? seasons,
    AdviceSettings? advice,
  }) {
    // Dekens van dit paard (of voor alle paarden). Koppelingen aan andere
    // paarden van de afzender gaan niet mee.
    final blankets = !withBlankets
        ? <Blanket>[]
        : [
            for (final b in allBlankets)
              if (b.fits(horse.id))
                b.copy()..horseIds = b.horseIds.isEmpty ? [] : [horse.id],
          ];
    final care = !withCare
        ? <CareRecord>[]
        : [for (final r in allCare) if (r.horseId == horse.id) r.copy()];
    final vaccineIds = {for (final r in care) r.vaccineId};
    final vaccines = [for (final v in allVaccines) if (vaccineIds.contains(v.id)) v];
    // De keuze "deken op stal" verwijst naar een deken; zonder die deken
    // valt het paard terug op het automatische advies.
    final h = horse.copy();
    final choice = h.stableBlanket;
    if (choice != null && choice != Horse.noBlanket && !blankets.any((b) => b.id == choice)) {
      h.stableBlanket = null;
    }
    return HorsePackage(
      horse: h,
      blankets: blankets,
      care: care,
      vaccines: vaccines,
      seasons: seasons,
      advice: advice,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'horse': horse.toJson(),
        if (blankets.isNotEmpty) 'blankets': [for (final b in blankets) b.toJson()],
        if (care.isNotEmpty) 'care': [for (final r in care) r.toJson()],
        if (vaccines.isNotEmpty) 'vaccines': [for (final v in vaccines) v.toJson()],
        if (seasons != null) 'seasons': seasons!.toJson(),
        if (advice != null) 'advice': advice!.toJson(),
      };

  factory HorsePackage.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return HorsePackage(
      horse: Horse.fromJson(j['horse'] as Map<String, dynamic>),
      blankets: list('blankets').map(Blanket.fromJson).toList(),
      care: list('care').map(CareRecord.fromJson).toList(),
      vaccines: list('vaccines').map(VaccineType.fromJson).toList(),
      seasons: j['seasons'] == null
          ? null
          : SeasonSettings.fromJson(j['seasons'] as Map<String, dynamic>),
      advice: j['advice'] == null
          ? null
          : AdviceSettings.fromJson(j['advice'] as Map<String, dynamic>),
    );
  }

  /// Compacte code voor in een link: ingepakt (deflate) en met korte
  /// datums, zodat WhatsApp de link in z'n geheel klikbaar maakt. De "z"
  /// vooraan onderscheidt dit van de oude, niet-ingepakte links.
  String encode() {
    final json = jsonEncode(toJson()).replaceAllMapped(
        RegExp(r'"(\d{4}-\d\d-\d\d)T00:00:00\.000"'), (m) => '"${m[1]}"');
    final packed = Deflate(utf8.encode(json), level: 9).getBytes();
    return 'z${base64Url.encode(packed).replaceAll('=', '')}';
  }

  /// Link naar de web-app met dit paard erin.
  String link(Uri appBase) => appBase
      .replace(queryParameters: {linkParam: encode()}, fragment: '')
      .toString()
      .replaceAll(RegExp(r'#$'), '');

  /// Leest een pakketje uit een link, een stuk tekst met een link erin, of
  /// alleen de code. Geeft null als het niet lukt.
  static HorsePackage? decode(String input) {
    var text = input.trim();
    final m = RegExp('[?&]$linkParam=([A-Za-z0-9_\\-]+)').firstMatch(text);
    if (m != null) {
      text = m.group(1)!;
    } else {
      final code = RegExp(r'[A-Za-z0-9_\-]{40,}').firstMatch(text);
      if (code == null) return null;
      text = code.group(0)!;
    }
    try {
      final packed = text.startsWith('z');
      if (packed) text = text.substring(1);
      final padded = text.padRight((text.length + 3) ~/ 4 * 4, '=');
      var bytes = base64Url.decode(padded);
      if (packed) bytes = Uint8List.fromList(Inflate(bytes).getBytes());
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic> || json['horse'] == null) return null;
      return HorsePackage.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
