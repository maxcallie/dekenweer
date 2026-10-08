import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/advice_settings.dart';
import '../models/blanket.dart';
import '../models/horse.dart';
import '../models/season.dart';
import '../models/weather.dart';

/// Bewaart paarden, locatie en de laatste voorspelling op het toestel.
class Storage {
  static const _horsesKey = 'horses_v1';
  static const _locationKey = 'location_v1';
  static const _forecastKey = 'forecast_v1';
  static const _blanketsKey = 'blankets_v1';
  static const _settingsKey = 'advice_settings_v1';
  static const _seasonsKey = 'seasons_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Horse>> loadHorses() async {
    final raw = (await _prefs).getString(_horsesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Horse.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHorses(List<Horse> horses) async {
    await (await _prefs)
        .setString(_horsesKey, jsonEncode([for (final h in horses) h.toJson()]));
  }

  Future<FarmLocation?> loadLocation() async {
    final raw = (await _prefs).getString(_locationKey);
    if (raw == null) return null;
    try {
      return FarmLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocation(FarmLocation loc) async {
    await (await _prefs).setString(_locationKey, jsonEncode(loc.toJson()));
  }

  Future<String?> loadForecastJson() async =>
      (await _prefs).getString(_forecastKey);

  Future<void> saveForecastJson(String json) async {
    await (await _prefs).setString(_forecastKey, json);
  }

  Future<List<Blanket>> loadBlankets() async {
    final raw = (await _prefs).getString(_blanketsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Blanket.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBlankets(List<Blanket> blankets) async {
    await (await _prefs).setString(
        _blanketsKey, jsonEncode([for (final b in blankets) b.toJson()]));
  }

  Future<AdviceSettings> loadSettings() async {
    final raw = (await _prefs).getString(_settingsKey);
    if (raw == null) return AdviceSettings.defaults;
    try {
      return AdviceSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AdviceSettings.defaults;
    }
  }

  Future<void> saveSettings(AdviceSettings s) async {
    await (await _prefs).setString(_settingsKey, jsonEncode(s.toJson()));
  }

  Future<SeasonSettings> loadSeasons() async {
    final raw = (await _prefs).getString(_seasonsKey);
    if (raw == null) return SeasonSettings.defaults;
    try {
      return SeasonSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return SeasonSettings.defaults;
    }
  }

  Future<void> saveSeasons(SeasonSettings s) async {
    await (await _prefs).setString(_seasonsKey, jsonEncode(s.toJson()));
  }
}
