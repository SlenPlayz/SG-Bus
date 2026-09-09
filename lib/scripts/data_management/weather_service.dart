import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';

class WeatherWarning {
  final String type;
  final String description;
  final String issued;

  WeatherWarning({
    required this.type,
    required this.description,
    required this.issued,
  });

  factory WeatherWarning.fromJson(Map<String, dynamic> json) {
    return WeatherWarning(
      type: json['type']?.toString() ?? 'Weather Warning',
      description: json['description']?.toString() ?? '',
      issued: json['issued']?.toString() ?? '',
    );
  }
}

class WeatherSummary {
  final double temperature;
  final String temperatureStation;
  final double rainfall;
  final String rainfallStation;
  final double humidity;
  final String humidityStation;
  final int pm25;
  final int psi;
  final String pm25Region;
  final String condition;
  final String areaName;
  final double feelsLike;
  final DateTime timestamp;
  final List<TwoHourForecastArea> allAreaForecasts;
  final double nearestStationDistance;
  final List<WeatherWarning> warnings;

  final int uvIndex;

  static const double kMaxStationDistanceKm = 30.0;

  WeatherSummary({
    required this.temperature,
    required this.temperatureStation,
    required this.rainfall,
    required this.rainfallStation,
    required this.humidity,
    required this.humidityStation,
    required this.pm25,
    this.psi = 0,
    required this.pm25Region,
    this.uvIndex = 0,
    required this.condition,
    required this.areaName,
    required this.feelsLike,
    required this.timestamp,
    this.allAreaForecasts = const [],
    this.nearestStationDistance = 0.0,
    this.warnings = const [],
  });

  /// User is considered too far from any Singapore station if distance exceeds 30 km.
  bool get isTooFarFromStation =>
      nearestStationDistance > kMaxStationDistanceKm;

  /// Official NEA 1-hr PM2.5 Bands:
  /// Band I (Normal): 0 - 55 µg/m³
  /// Band II (Elevated): 56 - 150 µg/m³
  /// Band III (High): 151 - 250 µg/m³
  /// Band IV (Very High): > 250 µg/m³
  bool get isHazy => pm25 > 55 || (psi > 100);
  bool get isUnhealthyHaze => pm25 > 150 || (psi > 200);

  /// On the main page weather pill, rain takes precedence over haze unless PM2.5 > 150 (High/Band III)
  bool get showHazeOnPill => isUnhealthyHaze || (isHazy && !isRain);

  /// UV warnings: High (6-7), Very High (8-10) or Extremely High (11+)
  bool get isHighUv => uvIndex >= 6 && uvIndex <= 7;
  bool get isVeryHighUv => uvIndex >= 8 && uvIndex <= 10;
  bool get isExtremeUv => uvIndex >= 11;
  bool get isHighOrAboveUv => uvIndex >= 6;

  /// Show dedicated alert banner for UV when it reaches Very High (8+) or Extreme (11+)
  bool get showUvAlertBanner => uvIndex >= 8;

  /// For the pill: takes least precedence, showing only when no rain, no haze warning, and UV index >= 6
  bool get showUvOnPill => !isRain && !showHazeOnPill && isHighOrAboveUv;

  /// Whether active official weather warnings exist
  bool get hasWeatherWarnings => warnings.isNotEmpty;

  String get uvCategory {
    if (uvIndex >= 11) return 'Extreme';
    if (uvIndex >= 8) return 'Very High';
    if (uvIndex >= 6) return 'High';
    if (uvIndex >= 3) return 'Moderate';
    return 'Low';
  }

  Color get uvColor {
    if (uvIndex >= 11) return Colors.purple.shade600;
    if (uvIndex >= 8) return Colors.red.shade600;
    if (uvIndex >= 6) return Colors.orange.shade700;
    if (uvIndex >= 3) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  /// Air quality category according to official NEA 1-Hour PM2.5 Bands
  String get airQualityCategory {
    if (pm25 > 250) return 'Very High';
    if (pm25 > 150) return 'High';
    if (pm25 > 55) return 'Elevated';
    return 'Normal';
  }

  Color get airQualityColor {
    if (pm25 > 250) return Colors.purple.shade700;
    if (pm25 > 150) return Colors.red.shade600;
    if (pm25 > 55) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  /// PSI Category according to official NEA 24-hr PSI bands
  String get psiCategory {
    if (psi > 300) return 'Hazardous';
    if (psi > 200) return 'Very Unhealthy';
    if (psi > 100) return 'Unhealthy';
    if (psi > 50) return 'Moderate';
    return 'Good';
  }

  Color get psiColor {
    if (psi > 300) return Colors.purple.shade900;
    if (psi > 200) return Colors.purple.shade700;
    if (psi > 100) return Colors.red.shade600;
    if (psi > 50) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  bool get isRain =>
      rainfall > 0 ||
      condition.toLowerCase().contains('rain') ||
      condition.toLowerCase().contains('shower');

  bool get isDrizzle =>
      (rainfall > 0 && rainfall <= 1.5) ||
      condition.toLowerCase().contains('light') ||
      condition.toLowerCase().contains('passing') ||
      condition.toLowerCase().contains('drizzle');

  bool get isHeavyRain =>
      rainfall > 7.5 || condition.toLowerCase().contains('heavy');

  bool get isThunderstorm =>
      condition.toLowerCase().contains('thunder') ||
      condition.toLowerCase().contains('thundery');

  IconData get iconData {
    if (showHazeOnPill) {
      return Icons.blur_on_rounded;
    }
    if (isRain) {
      if (isThunderstorm) return Icons.thunderstorm_rounded;
      if (isHeavyRain) return Icons.cloudy_snowing;
      if (isDrizzle) return Icons.water_drop_outlined;
      return Icons.water_drop_rounded;
    }
    if (showUvOnPill) {
      return Icons.wb_sunny_rounded;
    }

    final lower = condition.toLowerCase();
    final hour = DateTime.now().hour;
    final isNight = hour < 7 || hour >= 19 || lower.contains('night');

    if (lower.contains('partly cloudy')) {
      return isNight ? Icons.nightlight_outlined : Icons.cloud_queue_rounded;
    }
    if (lower.contains('cloudy') || lower.contains('overcast')) {
      return Icons.cloud_rounded;
    }
    if (lower.contains('mist') || lower.contains('fog')) {
      return Icons.foggy;
    }
    if (lower.contains('fair & warm') || lower.contains('fair and warm')) {
      return Icons.sunny;
    }
    if (lower.contains('fair') || lower.contains('clear')) {
      return isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
    }

    return isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
  }
}

class RadarBoundaryBox {
  final double upperLeftLng;
  final double upperLeftLat;
  final double lowerRightLng;
  final double lowerRightLat;

  RadarBoundaryBox({
    required this.upperLeftLng,
    required this.upperLeftLat,
    required this.lowerRightLng,
    required this.lowerRightLat,
  });

  factory RadarBoundaryBox.fromJson(Map<String, dynamic> json) {
    final upperLeft = json['upperLeft'] as Map<String, dynamic>? ?? {};
    final lowerRight = json['lowerRight'] as Map<String, dynamic>? ?? {};
    return RadarBoundaryBox(
      upperLeftLng: (upperLeft['longitude'] as num?)?.toDouble() ?? 103.342685,
      upperLeftLat: (upperLeft['latitude'] as num?)?.toDouble() ?? 1.97854,
      lowerRightLng:
          (lowerRight['longitude'] as num?)?.toDouble() ?? 104.602315,
      lowerRightLat:
          (lowerRight['latitude'] as num?)?.toDouble() ?? 0.719515,
    );
  }

  /// Clockwise coordinates for Mapbox ImageSource:
  /// Top-Left, Top-Right, Bottom-Right, Bottom-Left
  List<List<double>> toMapboxCoordinates() {
    return [
      [upperLeftLng, upperLeftLat],
      [lowerRightLng, upperLeftLat],
      [lowerRightLng, lowerRightLat],
      [upperLeftLng, lowerRightLat],
    ];
  }
}

class RadarFrame {
  final DateTime timestamp;
  final String url;
  final String label;
  final String range;

  RadarFrame({
    required this.timestamp,
    required this.url,
    required this.label,
    required this.range,
  });

  factory RadarFrame.fromJson(Map<String, dynamic> json) {
    final tsStr = json['timestamp']?.toString() ?? '';
    final dt = DateTime.tryParse(tsStr)?.toLocal() ?? DateTime.now();
    final img = json['image'] as Map<String, dynamic>? ?? {};
    return RadarFrame(
      timestamp: dt,
      url: img['url']?.toString() ?? '',
      label: img['label']?.toString() ?? '',
      range: img['range']?.toString() ?? '70km',
    );
  }
}

class RadarData {
  final RadarBoundaryBox boundaryBox;
  final List<RadarFrame> frames;
  final String range;

  RadarData({
    required this.boundaryBox,
    required this.frames,
    required this.range,
  });

  RadarFrame? get latestFrame => frames.isNotEmpty ? frames.last : null;
}

class TwoHourForecastArea {
  final String area;
  final String forecast;
  final double latitude;
  final double longitude;

  TwoHourForecastArea({
    required this.area,
    required this.forecast,
    required this.latitude,
    required this.longitude,
  });
}

class TwentyFourHourPeriod {
  final String timeText;
  final String startTime;
  final String endTime;
  final Map<String, String> regions; // central, east, north, south, west

  TwentyFourHourPeriod({
    required this.timeText,
    required this.startTime,
    required this.endTime,
    required this.regions,
  });
}

class TwentyFourHourForecast {
  final String generalForecast;
  final String generalCode;
  final double tempLow;
  final double tempHigh;
  final double humidityLow;
  final double humidityHigh;
  final String windDirection;
  final double windSpeedLow;
  final double windSpeedHigh;
  final List<TwentyFourHourPeriod> periods;
  final DateTime timestamp;

  TwentyFourHourForecast({
    required this.generalForecast,
    required this.generalCode,
    required this.tempLow,
    required this.tempHigh,
    required this.humidityLow,
    required this.humidityHigh,
    required this.windDirection,
    required this.windSpeedLow,
    required this.windSpeedHigh,
    required this.periods,
    required this.timestamp,
  });
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const Duration _cacheTtl = Duration(minutes: 15);

  Map<String, dynamic>? _cachedAllWeatherData;
  DateTime? _lastFetchTime;
  Future<Map<String, dynamic>?>? _pendingFetch;

  final ValueNotifier<TwentyFourHourForecast?> twentyFourHourForecastNotifier =
      ValueNotifier<TwentyFourHourForecast?>(null);

  /// Fetch all weather datasets in a single request from $serverURL/api/v2/weather
  Future<Map<String, dynamic>?> _fetchAllWeatherData(
      {bool forceRefresh = false}) async {
    // If a network request is already running, wait for it instead of duplicating
    if (_pendingFetch != null) {
      return _pendingFetch;
    }

    final future = _doFetchAllWeatherData(forceRefresh: forceRefresh);
    _pendingFetch = future;
    try {
      return await future;
    } finally {
      _pendingFetch = null;
    }
  }

  Future<Map<String, dynamic>?> _doFetchAllWeatherData(
      {bool forceRefresh = false}) async {
    final now = DateTime.now();

    // 1. Check in-memory cache
    if (!forceRefresh &&
        _cachedAllWeatherData != null &&
        _lastFetchTime != null) {
      if (now.difference(_lastFetchTime!) < _cacheTtl) {
        return _cachedAllWeatherData;
      }
    }

    // 2. Check SharedPreferences persistent cache
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('weather_all_v2_cache');
        final cachedTimeStr = prefs.getString('weather_all_v2_time');
        if (cachedJson != null && cachedTimeStr != null) {
          final cachedTime = DateTime.parse(cachedTimeStr);
          if (now.difference(cachedTime) < _cacheTtl) {
            final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
            _cachedAllWeatherData = decoded;
            _lastFetchTime = cachedTime;
            return decoded;
          }
        }
      } catch (_) {
        // Fall through to network
      }
    }

    // 3. Network fetch from backend api/v2/weather
    try {
      final base = serverURL.endsWith('/')
          ? serverURL.substring(0, serverURL.length - 1)
          : serverURL;
      final url = Uri.parse('$base/api/v2/weather');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedAllWeatherData = decoded;
        _lastFetchTime = now;

        // Persist to SharedPreferences asynchronously
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('weather_all_v2_cache', response.body);
          prefs.setString('weather_all_v2_time', now.toIso8601String());
        }).catchError((_) {});

        return decoded;
      } else {
        print(
            'WeatherService error: status ${response.statusCode} from /api/v2/weather');
      }
    } catch (e) {
      print('WeatherService error fetching /api/v2/weather: $e');
    }

    // Fallback: return stale memory or persistent cache on error
    return _cachedAllWeatherData;
  }

  /// Calculates distance in km between two GPS coords using Haversine formula
  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final c = math.cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  /// Calculates apparent temperature (feels-like) in Celsius
  double _calculateFeelsLike(double tempC, double humidity) {
    // Water vapor pressure in hPa
    final e = (humidity / 100.0) *
        6.105 *
        math.exp((17.27 * tempC) / (237.7 + tempC));
    // Apparent temperature formula: Ta = T + 0.33*e - 0.70*ws - 4.00 (ws ~ 3 m/s)
    final feels = tempC + 0.33 * e - 0.70 * 3.0 - 4.00;
    return double.parse(feels.toStringAsFixed(1));
  }

  Map<String, dynamic>? _lastTempData;
  Map<String, dynamic>? _lastRainData;
  Map<String, dynamic>? _lastHumData;
  Map<String, dynamic>? _lastPmData;
  Map<String, dynamic>? _lastPsiData;
  Map<String, dynamic>? _lastUvData;
  Map<String, dynamic>? _lastForecastData;
  List<WeatherWarning> _lastWarnings = [];
  List<TwoHourForecastArea> _lastAllAreaForecasts = [];

  /// Attempt to get user GPS coords with quick timeout.
  /// Returns null if location service is disabled, permission denied, or error.
  Future<Map<String, double>?> _getUserCoordinates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return {'lat': last.latitude, 'lon': last.longitude};
      } else {
        if (!kIsWeb) {
          final isLocationServiceAvailable =
              await Geolocator.isLocationServiceEnabled();
          if (!isLocationServiceAvailable) return null;
        }
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        return {'lat': current.latitude, 'lon': current.longitude};
      }
    } catch (_) {}
    return null;
  }

  static T? _firstOrNull<T>(List<T>? list) {
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  /// Builds a WeatherSummary centered on target coordinates and area
  WeatherSummary _buildSummaryFromData({
    required Map<String, dynamic>? tempData,
    required Map<String, dynamic>? rainData,
    required Map<String, dynamic>? humData,
    required Map<String, dynamic>? pmData,
    Map<String, dynamic>? psiData,
    required Map<String, dynamic>? uvData,
    required Map<String, dynamic>? forecastData,
    List<WeatherWarning> warnings = const [],
    required double targetLat,
    required double targetLon,
    String? areaNameOverride,
    String? conditionOverride,
    List<TwoHourForecastArea>? existingForecasts,
  }) {
    double minStationDist = double.infinity;

    // 1. Temperature (nearest station)
    double temperature = 29.0;
    String tempStationName = 'Central';
    if (tempData != null && tempData['data'] != null) {
      final stations = (tempData['data']['stations'] as List?) ?? [];
      final readingsList = (tempData['data']['readings'] as List?);
      final readings = (_firstOrNull(readingsList)?['data'] as List?) ?? [];
      final matched =
          _findNearestStationReading(stations, readings, targetLat, targetLon);
      if (matched != null) {
        temperature = (matched['value'] as num).toDouble();
        tempStationName = matched['name'] as String;
        final d = (matched['distance'] as num?)?.toDouble() ?? double.infinity;
        if (d < minStationDist) minStationDist = d;
      }
    }

    // 2. Rainfall (nearest station)
    double rainfall = 0.0;
    String rainStationName = 'Central';
    if (rainData != null && rainData['data'] != null) {
      final stations = (rainData['data']['stations'] as List?) ?? [];
      final readingsList = (rainData['data']['readings'] as List?);
      final readings = (_firstOrNull(readingsList)?['data'] as List?) ?? [];
      final matched =
          _findNearestStationReading(stations, readings, targetLat, targetLon);
      if (matched != null) {
        rainfall = (matched['value'] as num).toDouble();
        rainStationName = matched['name'] as String;
        final d = (matched['distance'] as num?)?.toDouble() ?? double.infinity;
        if (d < minStationDist) minStationDist = d;
      }
    }

    // 3. Humidity (nearest station)
    double humidity = 75.0;
    String humStationName = 'Central';
    if (humData != null && humData['data'] != null) {
      final stations = (humData['data']['stations'] as List?) ?? [];
      final readingsList = (humData['data']['readings'] as List?);
      final readings = (_firstOrNull(readingsList)?['data'] as List?) ?? [];
      final matched =
          _findNearestStationReading(stations, readings, targetLat, targetLon);
      if (matched != null) {
        humidity = (matched['value'] as num).toDouble();
        humStationName = matched['name'] as String;
        final d = (matched['distance'] as num?)?.toDouble() ?? double.infinity;
        if (d < minStationDist) minStationDist = d;
      }
    }

    // 4. PM2.5 & PSI (nearest region: north, south, east, west, central)
    int pm25 = 25;
    int psi = 0;
    String pm25Region = _findNearestPm25Region(targetLat, targetLon);
    if (pmData != null && pmData['data'] != null) {
      final itemsList = (pmData['data']['items'] as List?);
      final items = _firstOrNull(itemsList);
      if (items != null && items['readings'] != null) {
        final oneHourly =
            items['readings']['pm25_one_hourly'] as Map<String, dynamic>?;
        if (oneHourly != null) {
          final val = oneHourly[pm25Region] ?? oneHourly['central'] ?? 25;
          pm25 = (val as num).toInt();
        }
      }
    }

    // PSI resolution from psiData
    if (psiData != null) {
      try {
        final itemsList = (psiData['items'] as List?) ?? (psiData['data']?['items'] as List?);
        final firstItem = _firstOrNull(itemsList);
        final readings = firstItem?['readings'] as Map<String, dynamic>? ??
            psiData['readings'] as Map<String, dynamic>? ??
            psiData['data']?['readings'] as Map<String, dynamic>?;
        if (readings != null) {
          final psiMap = readings['psi_twenty_four_hourly'] as Map<String, dynamic>? ??
              readings['psi_three_hourly'] as Map<String, dynamic>?;
          if (psiMap != null) {
            final val = psiMap[pm25Region] ?? psiMap['central'] ?? psiMap['national'];
            if (val is num) psi = val.toInt();
          }
        }
      } catch (_) {}
    }

    // 5. UV Index
    int uvIndex = 0;
    if (uvData != null && uvData['data'] != null) {
      final recordsList = uvData['data']['records'] as List?;
      final records = _firstOrNull(recordsList);
      if (records != null && records['index'] != null) {
        final indexList = records['index'] as List?;
        if (indexList != null && indexList.isNotEmpty) {
          DateTime? latestTime;
          for (var item in indexList) {
            if (item is Map) {
              final val = item['value'];
              final hourStr = item['hour']?.toString();
              if (val != null) {
                if (hourStr != null) {
                  try {
                    final dt = DateTime.parse(hourStr);
                    if (latestTime == null || dt.isAfter(latestTime)) {
                      latestTime = dt;
                      uvIndex = (val as num).toInt();
                    }
                  } catch (_) {
                    if (latestTime == null) {
                      uvIndex = (val as num).toInt();
                    }
                  }
                } else if (latestTime == null) {
                  uvIndex = (val as num).toInt();
                }
              }
            }
          }
        }
      }
    }

    // 6. 2-Hour Forecast (nearest area or override)
    String condition = conditionOverride ?? 'Fair';
    String areaName = areaNameOverride ?? 'Singapore';
    final List<TwoHourForecastArea> allAreaForecasts =
        existingForecasts != null && existingForecasts.isNotEmpty
            ? existingForecasts
            : [];

    if (allAreaForecasts.isEmpty &&
        forecastData != null &&
        forecastData['data'] != null) {
      final areaMetadata =
          (forecastData['data']['area_metadata'] as List?) ?? [];
      final itemsList = (forecastData['data']['items'] as List?);
      final forecasts = (_firstOrNull(itemsList)?['forecasts'] as List?) ?? [];

      final Map<String, String> forecastMap = {};
      for (var f in forecasts) {
        forecastMap[f['area']?.toString() ?? ''] =
            f['forecast']?.toString() ?? '';
      }

      double minDistance = double.infinity;
      for (var area in areaMetadata) {
        final name = area['name']?.toString() ?? '';
        final loc = area['label_location'] ?? area['location'] ?? {};
        final lat = (loc['latitude'] as num?)?.toDouble() ?? 1.35;
        final lon = (loc['longitude'] as num?)?.toDouble() ?? 103.82;
        final fText = forecastMap[name] ?? 'Fair';

        allAreaForecasts.add(TwoHourForecastArea(
          area: name,
          forecast: fText,
          latitude: lat,
          longitude: lon,
        ));

        final dist = _distance(targetLat, targetLon, lat, lon);
        if (dist < minDistance) {
          minDistance = dist;
          if (areaNameOverride == null) areaName = name;
          if (conditionOverride == null) condition = fText;
        }
        if (dist < minStationDist) minStationDist = dist;
      }
    }

    if (minStationDist == double.infinity) {
      minStationDist = _distance(targetLat, targetLon, 1.3521, 103.8198);
    }

    final feelsLike = _calculateFeelsLike(temperature, humidity);

    return WeatherSummary(
      temperature: temperature,
      temperatureStation: tempStationName,
      rainfall: rainfall,
      rainfallStation: rainStationName,
      humidity: humidity,
      humidityStation: humStationName,
      pm25: pm25,
      psi: psi,
      pm25Region: pm25Region,
      uvIndex: uvIndex,
      condition: condition,
      areaName: areaName,
      feelsLike: feelsLike,
      timestamp: DateTime.now(),
      allAreaForecasts: allAreaForecasts,
      nearestStationDistance: minStationDist,
      warnings: warnings,
    );
  }

  /// Re-evaluates nearest sensor stations, readings, and condition for a chosen area
  WeatherSummary? resolveWeatherForArea(String targetAreaName) {
    if (_lastAllAreaForecasts.isEmpty) {
      final cur = globalWeather.value as WeatherSummary?;
      if (cur != null) {
        _lastAllAreaForecasts = cur.allAreaForecasts;
      }
    }

    final matches =
        _lastAllAreaForecasts.where((a) => a.area == targetAreaName).toList();
    if (matches.isEmpty) return null;
    final match = matches.first;

    return _buildSummaryFromData(
      tempData: _lastTempData,
      rainData: _lastRainData,
      humData: _lastHumData,
      pmData: _lastPmData,
      psiData: _lastPsiData,
      uvData: _lastUvData,
      forecastData: _lastForecastData,
      warnings: _lastWarnings,
      targetLat: match.latitude,
      targetLon: match.longitude,
      areaNameOverride: match.area,
      conditionOverride: match.forecast,
      existingForecasts: _lastAllAreaForecasts,
    );
  }

  TwentyFourHourForecast? _parseTwentyFourHourForecast(
      Map<String, dynamic>? res) {
    if (res == null || res['data'] == null) return null;
    try {
      final recordsList = (res['data']['records'] as List?);
      final records = _firstOrNull(recordsList);
      if (records != null) {
        final general = records['general'] ?? {};
        final periodsList = (records['periods'] as List?) ?? [];

        final List<TwentyFourHourPeriod> periods = [];
        for (var p in periodsList) {
          final tp = p['timePeriod'] ?? {};
          final regionsData = p['regions'] as Map<String, dynamic>? ?? {};
          final Map<String, String> regionTexts = {};
          regionsData.forEach((key, val) {
            if (val is Map) {
              regionTexts[key] = val['text']?.toString() ?? '';
            } else {
              regionTexts[key] = val?.toString() ?? '';
            }
          });

          periods.add(TwentyFourHourPeriod(
            timeText: tp['text']?.toString() ?? '',
            startTime: tp['start']?.toString() ?? '',
            endTime: tp['end']?.toString() ?? '',
            regions: regionTexts,
          ));
        }

        return TwentyFourHourForecast(
          generalForecast: general['forecast']?['text']?.toString() ?? 'Fair',
          generalCode: general['forecast']?['code']?.toString() ?? 'FN',
          tempLow: (general['temperature']?['low'] as num?)?.toDouble() ?? 25.0,
          tempHigh:
              (general['temperature']?['high'] as num?)?.toDouble() ?? 33.0,
          humidityLow:
              (general['relativeHumidity']?['low'] as num?)?.toDouble() ?? 60.0,
          humidityHigh:
              (general['relativeHumidity']?['high'] as num?)?.toDouble() ??
                  90.0,
          windDirection: general['wind']?['direction']?.toString() ?? 'SSE',
          windSpeedLow:
              (general['wind']?['speed']?['low'] as num?)?.toDouble() ?? 10.0,
          windSpeedHigh:
              (general['wind']?['speed']?['high'] as num?)?.toDouble() ?? 25.0,
          periods: periods,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      print('WeatherService error parsing 24hr forecast: $e');
    }
    return null;
  }

  /// Fetch initial real-time weather batch from backend api/v2/weather
  Future<WeatherSummary?> fetchRealtimeWeather(
      {bool forceRefresh = false}) async {
    try {
      isWeatherLoading.value = true;
      final coords = await _getUserCoordinates();
      if (coords == null) {
        globalWeather.value = null;
        return null;
      }
      final userLat = coords['lat']!;
      final userLon = coords['lon']!;

      final allData = await _fetchAllWeatherData(forceRefresh: forceRefresh);
      if (allData != null) {
        _lastTempData = allData['temperature'] as Map<String, dynamic>?;
        _lastRainData = allData['rainfall'] as Map<String, dynamic>?;
        _lastHumData = allData['humidity'] as Map<String, dynamic>?;
        _lastPmData = allData['pm25'] as Map<String, dynamic>?;
        _lastPsiData = allData['psi'] as Map<String, dynamic>?;
        _lastUvData = allData['uv'] as Map<String, dynamic>?;
        _lastForecastData = allData['twoHourForecast'] as Map<String, dynamic>?;

        // Parse weather warnings if present
        final rawWarnings = allData['warnings'] as List? ?? allData['weatherWarnings'] as List? ?? [];
        _lastWarnings = rawWarnings
            .whereType<Map<String, dynamic>>()
            .map((w) => WeatherWarning.fromJson(w))
            .toList();

        final twentyFourRaw =
            allData['twentyFourHourForecast'] as Map<String, dynamic>?;
        final tfForecast = _parseTwentyFourHourForecast(twentyFourRaw);
        if (tfForecast != null) {
          twentyFourHourForecastNotifier.value = tfForecast;
        }
      }

      final summary = _buildSummaryFromData(
        tempData: _lastTempData,
        rainData: _lastRainData,
        humData: _lastHumData,
        pmData: _lastPmData,
        psiData: _lastPsiData,
        uvData: _lastUvData,
        forecastData: _lastForecastData,
        warnings: _lastWarnings,
        targetLat: userLat,
        targetLon: userLon,
      );

      _lastAllAreaForecasts = summary.allAreaForecasts;
      globalWeather.value = summary;
      return summary;
    } catch (e) {
      print('WeatherService fetchRealtimeWeather error: $e');
      return null;
    } finally {
      isWeatherLoading.value = false;
    }
  }

  /// Returns the current 24-hour forecast from the bundled weather data,
  /// or fetches the weather bundle if not yet loaded.
  Future<TwentyFourHourForecast?> fetchTwentyFourHourForecast(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && twentyFourHourForecastNotifier.value != null) {
      return twentyFourHourForecastNotifier.value;
    }
    await fetchRealtimeWeather(forceRefresh: forceRefresh);
    return twentyFourHourForecastNotifier.value;
  }

  /// Helper to find the nearest station with an active reading
  Map<String, dynamic>? _findNearestStationReading(
      List stations, List readings, double userLat, double userLon) {
    if (stations.isEmpty || readings.isEmpty) return null;

    final Map<String, num> valueMap = {};
    for (var r in readings) {
      final sId = r['stationId']?.toString();
      final val = r['value'];
      if (sId != null && val != null && val is num) {
        valueMap[sId] = val;
      }
    }

    double minDistance = double.infinity;
    Map<String, dynamic>? bestMatch;

    for (var s in stations) {
      final sId = s['id']?.toString() ?? s['deviceId']?.toString() ?? '';
      if (!valueMap.containsKey(sId)) continue;

      final loc = s['location'] ?? {};
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lon = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final dist = _distance(userLat, userLon, lat, lon);
      if (dist < minDistance) {
        minDistance = dist;
        bestMatch = {
          'stationId': sId,
          'name': s['name']?.toString() ?? sId,
          'value': valueMap[sId],
          'distance': dist,
        };
      }
    }

    return bestMatch;
  }

  /// Finds closest PM2.5 region
  String _findNearestPm25Region(double userLat, double userLon) {
    final regions = {
      'central': [1.355, 103.820],
      'north': [1.420, 103.820],
      'south': [1.280, 103.820],
      'east': [1.350, 103.940],
      'west': [1.350, 103.700],
    };

    String bestRegion = 'central';
    double minDistance = double.infinity;

    regions.forEach((region, coords) {
      final dist = _distance(userLat, userLon, coords[0], coords[1]);
      if (dist < minDistance) {
        minDistance = dist;
        bestRegion = region;
      }
    });

    return bestRegion;
  }

  /// Fetches real-time weather radar imagery and recent frame history from NEA (data.gov.sg).
  /// [range] can be '70km' (Singapore local) or '240km' (regional).
  /// [fetchHistory] if true queries today's frames (?date=YYYY-MM-DD) which returns up to ~25 recent frames.
  Future<RadarData?> fetchWeatherRadar({
    String range = '70km',
    bool fetchHistory = true,
  }) async {
    try {
      String urlStr =
          'https://api-open.data.gov.sg/v2/real-time/api/weather-radar-images/$range';
      if (fetchHistory) {
        final now = DateTime.now().toLocal();
        final yyyy = now.year.toString().padLeft(4, '0');
        final mm = now.month.toString().padLeft(2, '0');
        final dd = now.day.toString().padLeft(2, '0');
        urlStr += '?date=$yyyy-$mm-$dd';
      }

      final url = Uri.parse(urlStr);
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        final bboxJson = data['boundaryBox'] as Map<String, dynamic>? ?? {};
        final bbox = RadarBoundaryBox.fromJson(bboxJson);
        final rawRecords = data['records'] as List<dynamic>? ?? [];

        final List<RadarFrame> frames = [];
        for (final rec in rawRecords) {
          if (rec is Map<String, dynamic>) {
            frames.add(RadarFrame.fromJson(rec));
          }
        }

        // Sort frames chronologically (oldest to newest) for smooth playback/scrubbing
        frames.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return RadarData(
          boundaryBox: bbox,
          frames: frames,
          range: range,
        );
      }
    } catch (e) {
      print('Error fetching weather radar: $e');
    }
    return null;
  }
}
