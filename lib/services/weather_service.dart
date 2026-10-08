import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Haalt weersvoorspellingen op bij Open-Meteo (gratis, geen API-sleutel).
/// Bron: https://open-meteo.com — data onder CC BY 4.0.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Geeft de ruwe JSON terug (zodat we die kunnen bewaren voor offline
  /// gebruik) én de geparste voorspelling.
  Future<(Forecast, String)> fetch(FarmLocation loc) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': loc.latitude.toStringAsFixed(4),
      'longitude': loc.longitude.toStringAsFixed(4),
      'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
          'precipitation,weather_code,wind_speed_10m,wind_gusts_10m,is_day',
      'hourly': 'temperature_2m,apparent_temperature,precipitation_probability,'
          'precipitation,weather_code,wind_speed_10m,relative_humidity_2m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_sum,precipitation_probability_max,wind_speed_10m_max',
      'timezone': 'auto',
      'forecast_days': '8',
      'wind_speed_unit': 'kmh',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Weerdienst gaf foutcode ${res.statusCode}');
    }
    final body = res.body;
    return (parse(body), body);
  }

  static Forecast parse(String body) =>
      Forecast.fromOpenMeteo(jsonDecode(body) as Map<String, dynamic>);

  /// Zoek een plaats op naam (Open-Meteo geocoding).
  Future<List<FarmLocation>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query.trim(),
      'count': '10',
      'language': 'nl',
      'format': 'json',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (j['results'] as List?) ?? const [];
    return [
      for (final r in results.cast<Map<String, dynamic>>())
        FarmLocation(
          name: r['name'] as String,
          region: [r['admin1'], r['country']]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(', '),
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
        ),
    ];
  }
}
