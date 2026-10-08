import 'day_phase.dart';

enum Season {
  summer('Zomer'),
  winter('Winter');

  const Season(this.label);
  final String label;
}

const monthNames = [
  'januari', 'februari', 'maart', 'april', 'mei', 'juni',
  'juli', 'augustus', 'september', 'oktober', 'november', 'december'
];

/// Zomer- en winterseizoen met per fase van de dag of de paarden binnen of
/// buiten staan ("stalschema").
class SeasonSettings {
  const SeasonSettings({
    this.summerMonth = 5,
    this.summerDay = 1,
    this.winterMonth = 11,
    this.winterDay = 1,
    this.summerInside = const {},
    this.winterInside = const {DayPhase.evening},
  });

  /// Begindatum van de zomer (standaard 1 mei).
  final int summerMonth;
  final int summerDay;

  /// Begindatum van de winter (standaard 1 november).
  final int winterMonth;
  final int winterDay;

  /// Fases waarin de paarden binnen staan.
  final Set<DayPhase> summerInside;
  final Set<DayPhase> winterInside;

  static const defaults = SeasonSettings();

  Season seasonOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final summer = DateTime(d.year, summerMonth, summerDay);
    final winter = DateTime(d.year, winterMonth, winterDay);
    if (!summer.isAfter(winter)) {
      // zomer valt binnen het kalenderjaar (bijv. 1 mei – 1 november)
      return !day.isBefore(summer) && day.isBefore(winter) ? Season.summer : Season.winter;
    }
    // winter valt binnen het kalenderjaar (ongebruikelijk, maar mogelijk)
    return !day.isBefore(winter) && day.isBefore(summer) ? Season.winter : Season.summer;
  }

  Set<DayPhase> insideIn(Season s) => s == Season.summer ? summerInside : winterInside;

  bool isInside(DateTime day, DayPhase phase) => insideIn(seasonOf(day)).contains(phase);

  String startLabel(Season s) => s == Season.summer
      ? '$summerDay ${monthNames[summerMonth - 1]}'
      : '$winterDay ${monthNames[winterMonth - 1]}';

  SeasonSettings copyWith({
    int? summerMonth,
    int? summerDay,
    int? winterMonth,
    int? winterDay,
    Set<DayPhase>? summerInside,
    Set<DayPhase>? winterInside,
  }) =>
      SeasonSettings(
        summerMonth: summerMonth ?? this.summerMonth,
        summerDay: summerDay ?? this.summerDay,
        winterMonth: winterMonth ?? this.winterMonth,
        winterDay: winterDay ?? this.winterDay,
        summerInside: summerInside ?? this.summerInside,
        winterInside: winterInside ?? this.winterInside,
      );

  /// Zet een fase in een seizoen op binnen of buiten.
  SeasonSettings withInside(Season s, DayPhase p, bool inside) {
    final set = {...insideIn(s)};
    if (inside) {
      set.add(p);
    } else {
      set.remove(p);
    }
    return s == Season.summer ? copyWith(summerInside: set) : copyWith(winterInside: set);
  }

  /// Zet de begindatum van een seizoen (dag wordt begrensd op de maand).
  SeasonSettings withStart(Season s, int month, int day) {
    final maxDay = DateTime(2025, month + 1, 0).day; // geen schrikkeljaar
    final d = day.clamp(1, maxDay);
    return s == Season.summer
        ? copyWith(summerMonth: month, summerDay: d)
        : copyWith(winterMonth: month, winterDay: d);
  }

  Map<String, dynamic> toJson() => {
        'summerMonth': summerMonth,
        'summerDay': summerDay,
        'winterMonth': winterMonth,
        'winterDay': winterDay,
        'summerInside': [for (final p in summerInside) p.name],
        'winterInside': [for (final p in winterInside) p.name],
      };

  factory SeasonSettings.fromJson(Map<String, dynamic> j) {
    Set<DayPhase> phases(Object? v, Set<DayPhase> fallback) {
      if (v is! List) return fallback;
      return {
        for (final n in v)
          for (final p in DayPhase.values)
            if (p.name == n) p,
      };
    }

    int i(Object? v, int fallback) => (v as num?)?.toInt() ?? fallback;
    return SeasonSettings(
      summerMonth: i(j['summerMonth'], 5),
      summerDay: i(j['summerDay'], 1),
      winterMonth: i(j['winterMonth'], 11),
      winterDay: i(j['winterDay'], 1),
      summerInside: phases(j['summerInside'], const {}),
      winterInside: phases(j['winterInside'], const {DayPhase.evening}),
    );
  }
}
