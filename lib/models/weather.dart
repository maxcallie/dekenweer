import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vereenvoudigde weersgroep (op basis van de WMO-weercode van Open-Meteo).
enum WeatherKind { clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, storm }

WeatherKind kindForCode(int code) {
  if (code == 0 || code == 1) return WeatherKind.clear;
  if (code == 2) return WeatherKind.partlyCloudy;
  if (code == 3) return WeatherKind.cloudy;
  if (code == 45 || code == 48) return WeatherKind.fog;
  if (code >= 51 && code <= 57) return WeatherKind.drizzle;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
    return WeatherKind.rain;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherKind.snow;
  }
  if (code >= 95) return WeatherKind.storm;
  return WeatherKind.cloudy;
}

String describeCode(int code) {
  switch (code) {
    case 0:
      return 'Onbewolkt';
    case 1:
      return 'Overwegend zonnig';
    case 2:
      return 'Half bewolkt';
    case 3:
      return 'Bewolkt';
    case 45:
    case 48:
      return 'Mist';
    case 51:
    case 53:
    case 55:
      return 'Motregen';
    case 56:
    case 57:
      return 'IJzel';
    case 61:
      return 'Lichte regen';
    case 63:
      return 'Regen';
    case 65:
      return 'Zware regen';
    case 66:
    case 67:
      return 'IJskoude regen';
    case 71:
      return 'Lichte sneeuw';
    case 73:
      return 'Sneeuw';
    case 75:
      return 'Zware sneeuw';
    case 77:
      return 'Korrelsneeuw';
    case 80:
    case 81:
      return 'Regenbuien';
    case 82:
      return 'Zware buien';
    case 85:
    case 86:
      return 'Sneeuwbuien';
    case 95:
      return 'Onweer';
    case 96:
    case 99:
      return 'Onweer met hagel';
  }
  return 'Wisselvallig';
}

IconData iconForKind(WeatherKind k, {bool night = false}) {
  switch (k) {
    case WeatherKind.clear:
      return night ? Icons.nightlight_round : Icons.wb_sunny;
    case WeatherKind.partlyCloudy:
      return night ? Icons.nights_stay : Icons.wb_cloudy;
    case WeatherKind.cloudy:
      return Icons.cloud;
    case WeatherKind.fog:
      return Icons.foggy;
    case WeatherKind.drizzle:
    case WeatherKind.rain:
      return Icons.grain;
    case WeatherKind.snow:
      return Icons.ac_unit;
    case WeatherKind.storm:
      return Icons.thunderstorm;
  }
}

class HourWeather {
  const HourWeather({
    required this.time,
    required this.temp,
    required this.feels,
    required this.precipProb,
    required this.precip,
    required this.code,
    required this.wind,
    required this.humidity,
  });

  final DateTime time;
  final double temp;
  final double feels;
  final int precipProb;
  final double precip;
  final int code;
  final double wind;
  final int humidity;
}

class DayWeather {
  const DayWeather({
    required this.date,
    required this.code,
    required this.tMax,
    required this.tMin,
    required this.precipSum,
    required this.precipProb,
    required this.windMax,
  });

  final DateTime date;
  final int code;
  final double tMax;
  final double tMin;
  final double precipSum;
  final int precipProb;
  final double windMax;
}

class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temp,
    required this.feels,
    required this.humidity,
    required this.precip,
    required this.code,
    required this.wind,
    required this.gusts,
    required this.isDay,
  });

  final DateTime time;
  final double temp;
  final double feels;
  final int humidity;
  final double precip;
  final int code;
  final double wind;
  final double gusts;
  final bool isDay;
}

class Forecast {
  const Forecast({
    required this.current,
    required this.hours,
    required this.days,
  });

  final CurrentWeather current;
  final List<HourWeather> hours;
  final List<DayWeather> days;

  factory Forecast.fromOpenMeteo(Map<String, dynamic> j) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    int i(Object? v) => (v as num?)?.round() ?? 0;

    final c = j['current'] as Map<String, dynamic>;
    final current = CurrentWeather(
      time: DateTime.parse(c['time'] as String),
      temp: d(c['temperature_2m']),
      feels: d(c['apparent_temperature']),
      humidity: i(c['relative_humidity_2m']),
      precip: d(c['precipitation']),
      code: i(c['weather_code']),
      wind: d(c['wind_speed_10m']),
      gusts: d(c['wind_gusts_10m']),
      isDay: i(c['is_day']) == 1,
    );

    final h = j['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    final hours = <HourWeather>[
      for (var k = 0; k < times.length; k++)
        HourWeather(
          time: DateTime.parse(times[k]),
          temp: d((h['temperature_2m'] as List)[k]),
          feels: d((h['apparent_temperature'] as List)[k]),
          precipProb: i((h['precipitation_probability'] as List)[k]),
          precip: d((h['precipitation'] as List)[k]),
          code: i((h['weather_code'] as List)[k]),
          wind: d((h['wind_speed_10m'] as List)[k]),
          humidity: i((h['relative_humidity_2m'] as List)[k]),
        ),
    ];

    final dd = j['daily'] as Map<String, dynamic>;
    final dates = (dd['time'] as List).cast<String>();
    final days = <DayWeather>[
      for (var k = 0; k < dates.length; k++)
        DayWeather(
          date: DateTime.parse(dates[k]),
          code: i((dd['weather_code'] as List)[k]),
          tMax: d((dd['temperature_2m_max'] as List)[k]),
          tMin: d((dd['temperature_2m_min'] as List)[k]),
          precipSum: d((dd['precipitation_sum'] as List)[k]),
          precipProb: i((dd['precipitation_probability_max'] as List)[k]),
          windMax: d((dd['wind_speed_10m_max'] as List)[k]),
        ),
    ];

    return Forecast(current: current, hours: hours, days: days);
  }

  /// Vat de uren in [start, end) samen tot één periode.
  PeriodWeather? period(DateTime start, DateTime end,
      {required bool isNight, required String label}) {
    final hs = hours
        .where((h) => !h.time.isBefore(start) && h.time.isBefore(end))
        .toList();
    if (hs.isEmpty) return null;
    return PeriodWeather.fromHours(hs,
        start: start, end: end, isNight: isNight, label: label);
  }
}

/// Weer over een periode (bijv. "vannacht" 20:00–08:00).
class PeriodWeather {
  const PeriodWeather({
    required this.label,
    required this.start,
    required this.end,
    required this.isNight,
    required this.minTemp,
    required this.maxTemp,
    required this.avgTemp,
    required this.minFeels,
    required this.maxWind,
    required this.totalPrecip,
    required this.maxPrecipProb,
    required this.avgHumidity,
    required this.code,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final bool isNight;
  final double minTemp;
  final double maxTemp;
  final double avgTemp;
  final double minFeels;
  final double maxWind;
  final double totalPrecip;
  final int maxPrecipProb;
  final int avgHumidity;

  /// Representatieve WMO-code voor de periode.
  final int code;

  WeatherKind get kind => kindForCode(code);

  bool get isWet =>
      totalPrecip >= 1.0 || (maxPrecipProb >= 60 && totalPrecip >= 0.3);

  factory PeriodWeather.fromHours(List<HourWeather> hs,
      {required DateTime start,
      required DateTime end,
      required bool isNight,
      required String label}) {
    double minT = double.infinity, maxT = -double.infinity, sumT = 0;
    double minF = double.infinity, maxW = 0, precip = 0;
    int maxP = 0, sumH = 0;
    final counts = <WeatherKind, int>{};
    final codeFor = <WeatherKind, int>{};
    for (final h in hs) {
      minT = math.min(minT, h.temp);
      maxT = math.max(maxT, h.temp);
      sumT += h.temp;
      minF = math.min(minF, h.feels);
      maxW = math.max(maxW, h.wind);
      precip += h.precip;
      maxP = math.max(maxP, h.precipProb);
      sumH += h.humidity;
      final k = kindForCode(h.code);
      counts[k] = (counts[k] ?? 0) + 1;
      codeFor[k] = math.max(codeFor[k] ?? 0, h.code);
    }

    // Neerslag weegt zwaarder: als het minstens 2 uur regent/sneeuwt,
    // kiezen we de zwaarste neerslagsoort.
    const precipOrder = [
      WeatherKind.storm,
      WeatherKind.snow,
      WeatherKind.rain,
      WeatherKind.drizzle,
    ];
    final precipHours = precipOrder.fold<int>(0, (s, k) => s + (counts[k] ?? 0));
    WeatherKind chosen;
    if (precipHours >= 2) {
      chosen = precipOrder.firstWhere((k) => (counts[k] ?? 0) > 0);
    } else {
      chosen = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    return PeriodWeather(
      label: label,
      start: start,
      end: end,
      isNight: isNight,
      minTemp: minT,
      maxTemp: maxT,
      avgTemp: sumT / hs.length,
      minFeels: minF,
      maxWind: maxW,
      totalPrecip: precip,
      maxPrecipProb: maxP,
      avgHumidity: (sumH / hs.length).round(),
      code: codeFor[chosen]!,
    );
  }
}

class FarmLocation {
  const FarmLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
  });

  final String name;
  final String region;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'name': name,
        'region': region,
        'lat': latitude,
        'lon': longitude,
      };

  factory FarmLocation.fromJson(Map<String, dynamic> j) => FarmLocation(
        name: j['name'] as String,
        region: j['region'] as String? ?? '',
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lon'] as num).toDouble(),
      );

  static const fallback = FarmLocation(
      name: 'Utrecht', region: 'Utrecht', latitude: 52.09, longitude: 5.12);
}
