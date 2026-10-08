
import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../logic/blanket_picker.dart';
import '../logic/care_planner.dart';
import '../logic/horse_share.dart';
import '../models/advice_settings.dart';
import '../models/blanket.dart';
import '../models/care.dart';
import '../models/day_phase.dart';
import '../models/horse.dart';
import '../models/season.dart';
import '../models/weather.dart';
import '../services/storage.dart';
import '../services/weather_service.dart';

export '../models/day_phase.dart';
export '../logic/care_planner.dart';
export '../logic/horse_share.dart';
export '../models/care.dart';
export '../models/season.dart';

const weekdayShort = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
const weekdayLong = [
  'maandag',
  'dinsdag',
  'woensdag',
  'donderdag',
  'vrijdag',
  'zaterdag',
  'zondag'
];
const monthShort = [
  'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'dec'
];

String formatDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class AppState extends ChangeNotifier {
  AppState({Storage? storage, WeatherService? weather})
      : _storage = storage ?? Storage(),
        _weather = weather ?? WeatherService();

  final Storage _storage;
  final WeatherService _weather;
  AdviceSettings settings = AdviceSettings.defaults;
  SeasonSettings seasons = SeasonSettings.defaults;
  BlanketAdvisor get advisor => BlanketAdvisor(settings);

  List<Horse> horses = [];
  List<Blanket> blankets = [];

  /// Vaccinaties, wormenkuren en mestonderzoeken.
  List<CareRecord> careRecords = [];
  List<VaccineType> vaccines = [];
  CareSettings careSettings = CareSettings.defaults;
  FarmLocation location = FarmLocation.fallback;
  bool hasChosenLocation = false;
  Forecast? forecast;
  DateTime? updatedAt;
  bool loading = false;
  String? error;
  String? focusHorseId;

  /// Gekozen dag en fase (standaard: vandaag, de fase van nu).
  DateTime selectedDay = dateOnly(DateTime.now());
  DayPhase selectedPhase = DayPhase.of(DateTime.now());

  /// De 7 dagen in de datumstrip (vandaag + 6).
  List<DayWeather> get stripDays {
    final f = forecast;
    if (f == null) return const [];
    final today = dateOnly(DateTime.now());
    return f.days.where((d) => !dateOnly(d.date).isBefore(today)).take(7).toList();
  }

  /// Weer voor een dag en fase.
  PeriodWeather? periodFor(DateTime day, DayPhase phase) {
    final f = forecast;
    if (f == null) return null;
    final d = dateOnly(day);
    return f.period(
      DateTime(d.year, d.month, d.day, phase.startHour),
      DateTime(d.year, d.month, d.day, phase.endHour),
      isNight: phase.isNight,
      label: phase.label,
    );
  }

  /// Weer voor de gekozen dag en fase.
  PeriodWeather? get currentPeriod => periodFor(selectedDay, selectedPhase);

  WeatherService get weatherService => _weather;

  Future<void> init() async {
    horses = await _storage.loadHorses();
    blankets = await _storage.loadBlankets();
    settings = await _storage.loadSettings();
    seasons = await _storage.loadSeasons();
    careRecords = await _storage.loadCareRecords();
    vaccines = await _storage.loadVaccines();
    careSettings = await _storage.loadCareSettings();
    final loc = await _storage.loadLocation();
    if (loc != null) {
      location = loc;
      hasChosenLocation = true;
    }
    final cached = await _storage.loadForecastJson();
    if (cached != null) {
      try {
        _setForecast(WeatherService.parse(cached));
      } catch (_) {}
    }
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final (f, raw) = await _weather.fetch(location);
      _setForecast(f);
      updatedAt = DateTime.now();
      await _storage.saveForecastJson(raw);
    } catch (e) {
      error = forecast == null
          ? 'Kon het weer niet ophalen. Controleer je internetverbinding.'
          : 'Geen verbinding: je ziet de laatst opgehaalde voorspelling.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _setForecast(Forecast f) {
    forecast = f;
    // Een gekozen dag in het verleden (app lang open laten staan) → vandaag.
    final today = dateOnly(DateTime.now());
    if (selectedDay.isBefore(today)) {
      selectedDay = today;
      selectedPhase = DayPhase.of(DateTime.now());
    }
  }

  void selectDay(DateTime day) {
    selectedDay = dateOnly(day);
    notifyListeners();
  }

  void selectPhase(DayPhase phase) {
    selectedPhase = phase;
    notifyListeners();
  }

  void setFocusHorse(String? id) {
    focusHorseId = id;
    notifyListeners();
  }

  Horse? get focusHorse {
    if (horses.isEmpty) return null;
    return horses.firstWhere((h) => h.id == focusHorseId,
        orElse: () => horses.first);
  }

  Future<void> setLocation(FarmLocation loc) async {
    location = loc;
    hasChosenLocation = true;
    await _storage.saveLocation(loc);
    notifyListeners();
    await refresh();
  }

  Future<void> saveHorse(Horse horse) async {
    final i = horses.indexWhere((h) => h.id == horse.id);
    if (i >= 0) {
      horses[i] = horse;
    } else {
      horses.add(horse);
    }
    await _storage.saveHorses(horses);
    notifyListeners();
  }

  Future<void> deleteHorse(String id) async {
    horses.removeWhere((h) => h.id == id);
    if (focusHorseId == id) focusHorseId = null;
    await _storage.saveHorses(horses);
    if (careRecords.any((r) => r.horseId == id)) {
      careRecords.removeWhere((r) => r.horseId == id);
      await _storage.saveCareRecords(careRecords);
    }
    notifyListeners();
  }

  // ---- Zorg: vaccinaties en ontworming ---------------------------------

  /// Alles wat op de planning staat, vroegste eerst.
  List<CareDue> get carePlan =>
      CarePlanner.plan(careRecords, careSettings, horseIds: horses.map((h) => h.id));

  /// Wat binnenkort moet of te laat is (voor de herinnering).
  List<CareDue> get careSoon =>
      CarePlanner.soon(carePlan, careSettings, DateTime.now());

  Horse? horseById(String id) {
    for (final h in horses) {
      if (h.id == id) return h;
    }
    return null;
  }

  VaccineType? vaccineById(String? id) {
    for (final v in vaccines) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<void> saveCareRecords(List<CareRecord> list) async {
    for (final r in list) {
      final i = careRecords.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        careRecords[i] = r;
      } else {
        careRecords.add(r);
      }
    }
    await _storage.saveCareRecords(careRecords);
    notifyListeners();
  }

  Future<void> deleteCareRecord(String id) async {
    careRecords.removeWhere((r) => r.id == id);
    await _storage.saveCareRecords(careRecords);
    notifyListeners();
  }

  Future<void> saveVaccine(VaccineType v) async {
    final i = vaccines.indexWhere((x) => x.id == v.id);
    if (i >= 0) {
      vaccines[i] = v;
    } else {
      vaccines.add(v);
    }
    await _storage.saveVaccines(vaccines);
    notifyListeners();
  }

  Future<void> deleteVaccine(String id) async {
    vaccines.removeWhere((v) => v.id == id);
    await _storage.saveVaccines(vaccines);
    notifyListeners();
  }

  // ---- Paard delen ------------------------------------------------------

  /// Pakketje om [horse] te delen.
  HorsePackage packageFor(Horse horse,
          {bool blankets = true, bool care = true, bool seasons = true, bool advice = false}) =>
      HorsePackage.of(
        horse,
        allBlankets: this.blankets,
        allCare: careRecords,
        allVaccines: vaccines,
        withBlankets: blankets,
        withCare: care,
        seasons: seasons ? this.seasons : null,
        advice: advice ? settings : null,
      );

  /// Voegt een ontvangen paard toe, of werkt het bij als het er al is.
  Future<void> importPackage(HorsePackage p,
      {bool withSeasons = true, bool withAdvice = true}) async {
    void upsert<T>(List<T> list, T item, String Function(T) id) {
      final i = list.indexWhere((x) => id(x) == id(item));
      if (i >= 0) {
        list[i] = item;
      } else {
        list.add(item);
      }
    }

    upsert<Horse>(horses, p.horse, (h) => h.id);
    for (final b in p.blankets) {
      // een deken die je al had, houdt zijn koppelingen met jouw paarden
      final mine = blankets.where((x) => x.id == b.id).firstOrNull;
      if (mine != null && mine.horseIds.isNotEmpty && b.horseIds.isNotEmpty) {
        b.horseIds = {...mine.horseIds, ...b.horseIds}.toList();
      }
      upsert<Blanket>(blankets, b, (x) => x.id);
    }
    for (final v in p.vaccines) {
      upsert<VaccineType>(vaccines, v, (x) => x.id);
    }
    for (final r in p.care) {
      upsert<CareRecord>(careRecords, r, (x) => x.id);
    }
    await _storage.saveHorses(horses);
    await _storage.saveBlankets(blankets);
    await _storage.saveVaccines(vaccines);
    await _storage.saveCareRecords(careRecords);
    if (withSeasons && p.seasons != null) {
      seasons = p.seasons!;
      await _storage.saveSeasons(seasons);
    }
    if (withAdvice && p.advice != null) {
      settings = p.advice!;
      await _storage.saveSettings(settings);
    }
    notifyListeners();
  }

  Future<void> saveCareSettings(CareSettings s) async {
    careSettings = s;
    await _storage.saveCareSettings(s);
    notifyListeners();
  }

  Future<void> saveBlanket(Blanket blanket) async {
    final i = blankets.indexWhere((b) => b.id == blanket.id);
    if (i >= 0) {
      blankets[i] = blanket;
    } else {
      blankets.add(blanket);
    }
    await _storage.saveBlankets(blankets);
    notifyListeners();
  }

  Future<void> deleteBlanket(String id) async {
    blankets.removeWhere((b) => b.id == id);
    await _storage.saveBlankets(blankets);
    notifyListeners();
  }

  Future<void> saveSeasons(SeasonSettings s) async {
    seasons = s;
    await _storage.saveSeasons(s);
    notifyListeners();
  }

  /// Staat dit paard op deze dag in deze fase op stal?
  bool insideAt(Horse h, DateTime day, DayPhase phase) =>
      h.housing == Housing.schedule && seasons.isInside(day, phase);

  /// Staat er op deze dag in deze fase minstens één paard op stal?
  bool anyInside(DateTime day, DayPhase phase) =>
      horses.any((h) => insideAt(h, day, phase));

  /// Staan alle paarden op stal (en is er minstens één)?
  bool allInside(DateTime day, DayPhase phase) =>
      horses.isNotEmpty && horses.every((h) => insideAt(h, day, phase));

  Future<void> saveSettings(AdviceSettings s) async {
    settings = s;
    await _storage.saveSettings(s);
    notifyListeners();
  }

  /// De deken uit je eigen dekenkast die bij dit advies past. Bij een vaste
  /// keuze voor op stal is dat die deken (of geen).
  BlanketPick? pickFor(Horse horse, BlanketAdvice? advice) {
    if (advice == null) return null;
    if (advice.userChoice) {
      final id = advice.choiceBlanketId;
      if (id == null) return null;
      for (final b in blankets) {
        if (b.id == id) return BlanketPick(main: b, level: advice.level);
      }
      return null;
    }
    return BlanketPicker.pick(horse, advice, blankets);
  }

  /// Heeft dit paard dekens in de dekenkast?
  bool hasBlanketsFor(Horse horse) => blankets.any((b) => b.fits(horse.id));

  /// Advies voor de gekozen dag en fase.
  BlanketAdvice? adviceFor(Horse horse) =>
      adviceAt(horse, selectedDay, selectedPhase);

  /// Advies voor een paard op een dag en fase, rekening houdend met het
  /// stalschema en een vaste keuze voor de deken op stal.
  BlanketAdvice? adviceAt(Horse horse, DateTime day, DayPhase phase) {
    final w = periodFor(day, phase);
    if (w == null) return null;
    final inside = insideAt(horse, day, phase);
    final raw = advisor.advise(horse, w, inside: inside);
    final choice = horse.stableBlanket;
    if (!inside || choice == null) return raw;
    if (choice == Horse.noBlanket) {
      return raw.withStableChoice(
          level: BlanketLevel.none, neckCover: false, description: 'geen deken');
    }
    for (final b in blankets) {
      if (b.id == choice) {
        return raw.withStableChoice(
          level: BlanketPicker.levelForGrams(b.grams),
          neckCover: b.neck,
          blanketId: b.id,
          description: b.name,
        );
      }
    }
    return raw; // gekozen deken bestaat niet meer → gewoon het advies
  }
}
