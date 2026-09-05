import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/data_management/weather_service.dart';

void main() {
  group('WeatherSummary Tests', () {
    test('Correctly identifies Drizzle vs Heavy Rain vs Thunderstorm', () {
      final drizzleWeather = WeatherSummary(
        temperature: 28.5,
        temperatureStation: 'Clementi',
        rainfall: 0.8,
        rainfallStation: 'Clementi',
        humidity: 82.0,
        humidityStation: 'Clementi',
        pm25: 22,
        pm25Region: 'west',
        condition: 'Light Showers',
        areaName: 'Clementi',
        feelsLike: 31.0,
        timestamp: DateTime.now(),
      );

      expect(drizzleWeather.isRain, isTrue);
      expect(drizzleWeather.isDrizzle, isTrue);
      expect(drizzleWeather.isHeavyRain, isFalse);
      expect(drizzleWeather.iconData, equals(Icons.water_drop_outlined));

      final heavyRainWeather = WeatherSummary(
        temperature: 26.0,
        temperatureStation: 'Newton',
        rainfall: 12.0,
        rainfallStation: 'Newton',
        humidity: 92.0,
        humidityStation: 'Newton',
        pm25: 18,
        pm25Region: 'central',
        condition: 'Heavy Rain',
        areaName: 'Novena',
        feelsLike: 27.5,
        timestamp: DateTime.now(),
      );

      expect(heavyRainWeather.isHeavyRain, isTrue);
      expect(heavyRainWeather.isDrizzle, isFalse);
      expect(heavyRainWeather.iconData, equals(Icons.cloudy_snowing));

      final thunderWeather = WeatherSummary(
        temperature: 27.0,
        temperatureStation: 'Changi',
        rainfall: 8.5,
        rainfallStation: 'Changi',
        humidity: 88.0,
        humidityStation: 'Changi',
        pm25: 20,
        pm25Region: 'east',
        condition: 'Thundery Showers',
        areaName: 'Bedok',
        feelsLike: 29.0,
        timestamp: DateTime.now(),
      );

      expect(thunderWeather.isThunderstorm, isTrue);
      expect(thunderWeather.iconData, equals(Icons.thunderstorm_rounded));
    });

    test('Identifies Haze categories and thresholds (Elevated > 50, Unhealthy > 100)', () {
      final normalWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Marina Bay',
        rainfall: 0.0,
        rainfallStation: 'Marina Bay',
        humidity: 70.0,
        humidityStation: 'Marina Bay',
        pm25: 45,
        pm25Region: 'central',
        condition: 'Fair',
        areaName: 'Downtown Core',
        feelsLike: 34.0,
        timestamp: DateTime.now(),
      );
      expect(normalWeather.isHazy, isFalse);
      expect(normalWeather.isUnhealthyHaze, isFalse);
      expect(normalWeather.showHazeOnPill, isFalse);

      final elevatedHazeWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Marina Bay',
        rainfall: 0.0,
        rainfallStation: 'Marina Bay',
        humidity: 70.0,
        humidityStation: 'Marina Bay',
        pm25: 75,
        pm25Region: 'central',
        condition: 'Hazy',
        areaName: 'Downtown Core',
        feelsLike: 34.0,
        timestamp: DateTime.now(),
      );
      expect(elevatedHazeWeather.isHazy, isTrue);
      expect(elevatedHazeWeather.isUnhealthyHaze, isFalse);
      expect(elevatedHazeWeather.airQualityCategory, equals('Elevated'));
      expect(elevatedHazeWeather.showHazeOnPill, isTrue);
      expect(elevatedHazeWeather.iconData, equals(Icons.blur_on_rounded));

      final unhealthyHazeWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Marina Bay',
        rainfall: 0.0,
        rainfallStation: 'Marina Bay',
        humidity: 70.0,
        humidityStation: 'Marina Bay',
        pm25: 125,
        pm25Region: 'central',
        condition: 'Hazy',
        areaName: 'Downtown Core',
        feelsLike: 34.0,
        timestamp: DateTime.now(),
      );
      expect(unhealthyHazeWeather.isHazy, isTrue);
      expect(unhealthyHazeWeather.isUnhealthyHaze, isTrue);
      expect(unhealthyHazeWeather.airQualityCategory, equals('Unhealthy'));
      expect(unhealthyHazeWeather.showHazeOnPill, isTrue);
      expect(unhealthyHazeWeather.iconData, equals(Icons.blur_on_rounded));
    });

    test('Rain takes precedence over haze on pill unless PM2.5 > 100', () {
      // 1. Raining with elevated haze (PM2.5 = 75, <= 100): rain wins
      final rainWithElevatedHaze = WeatherSummary(
        temperature: 27.0,
        temperatureStation: 'Ang Mo Kio',
        rainfall: 2.5,
        rainfallStation: 'Ang Mo Kio',
        humidity: 90.0,
        humidityStation: 'Ang Mo Kio',
        pm25: 75,
        pm25Region: 'north',
        condition: 'Moderate Rain',
        areaName: 'Ang Mo Kio',
        feelsLike: 29.0,
        timestamp: DateTime.now(),
      );

      expect(rainWithElevatedHaze.isRain, isTrue);
      expect(rainWithElevatedHaze.isHazy, isTrue);
      expect(rainWithElevatedHaze.isUnhealthyHaze, isFalse);
      expect(rainWithElevatedHaze.showHazeOnPill, isFalse); // Rain takes precedence!
      expect(rainWithElevatedHaze.iconData, equals(Icons.water_drop_rounded)); // Rain icon, not haze blur

      // 2. Raining with unhealthy haze (PM2.5 = 115, > 100): haze wins
      final rainWithUnhealthyHaze = WeatherSummary(
        temperature: 27.0,
        temperatureStation: 'Ang Mo Kio',
        rainfall: 2.5,
        rainfallStation: 'Ang Mo Kio',
        humidity: 90.0,
        humidityStation: 'Ang Mo Kio',
        pm25: 115,
        pm25Region: 'north',
        condition: 'Moderate Rain',
        areaName: 'Ang Mo Kio',
        feelsLike: 29.0,
        timestamp: DateTime.now(),
      );

      expect(rainWithUnhealthyHaze.isRain, isTrue);
      expect(rainWithUnhealthyHaze.isHazy, isTrue);
      expect(rainWithUnhealthyHaze.isUnhealthyHaze, isTrue);
      expect(rainWithUnhealthyHaze.showHazeOnPill, isTrue); // Unhealthy haze overrides rain!
      expect(rainWithUnhealthyHaze.iconData, equals(Icons.blur_on_rounded)); // Blur icon
    });

    test('resolveWeatherForArea returns custom WeatherSummary for selected area', () {
      final service = WeatherService();
      final areas = [
        TwoHourForecastArea(
          area: 'Woodlands',
          forecast: 'Thundery Showers',
          latitude: 1.4382,
          longitude: 103.789,
        ),
        TwoHourForecastArea(
          area: 'Changi',
          forecast: 'Fair',
          latitude: 1.357,
          longitude: 103.987,
        ),
      ];

      // Set global weather with area forecasts
      globalWeather.value = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Central',
        rainfall: 0.0,
        rainfallStation: 'Central',
        humidity: 70.0,
        humidityStation: 'Central',
        pm25: 25,
        pm25Region: 'central',
        condition: 'Fair',
        areaName: 'Bishan',
        feelsLike: 33.0,
        timestamp: DateTime.now(),
        allAreaForecasts: areas,
      );

      final woodlandsWeather = service.resolveWeatherForArea('Woodlands');
      expect(woodlandsWeather, isNotNull);
      expect(woodlandsWeather!.areaName, equals('Woodlands'));
      expect(woodlandsWeather.condition, equals('Thundery Showers'));
      expect(woodlandsWeather.isThunderstorm, isTrue);
      expect(woodlandsWeather.pm25Region, equals('north'));
    });

    test('isTooFarFromStation detects when user is outside Singapore (>30km)', () {
      final insideSingaporeWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 70.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        condition: 'Fair',
        areaName: 'Novena',
        feelsLike: 33.0,
        timestamp: DateTime.now(),
        nearestStationDistance: 3.5, // 3.5km from Newton station
      );

      expect(insideSingaporeWeather.isTooFarFromStation, isFalse);

      final outsideSingaporeWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Admiralty',
        rainfall: 0.0,
        rainfallStation: 'Admiralty',
        humidity: 70.0,
        humidityStation: 'Admiralty',
        pm25: 25,
        pm25Region: 'north',
        condition: 'Fair',
        areaName: 'Singapore',
        feelsLike: 33.0,
        timestamp: DateTime.now(),
        nearestStationDistance: 13000.0, // Mountain View / far abroad
      );

      expect(outsideSingaporeWeather.isTooFarFromStation, isTrue);

      final borderEdgeWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Tuas South',
        rainfall: 0.0,
        rainfallStation: 'Tuas South',
        humidity: 70.0,
        humidityStation: 'Tuas South',
        pm25: 25,
        pm25Region: 'west',
        condition: 'Fair',
        areaName: 'Singapore',
        feelsLike: 33.0,
        timestamp: DateTime.now(),
        nearestStationDistance: 30.0, // Exactly threshold
      );

      expect(borderEdgeWeather.isTooFarFromStation, isFalse);

      final beyondBorderWeather = WeatherSummary(
        temperature: 30.0,
        temperatureStation: 'Tuas South',
        rainfall: 0.0,
        rainfallStation: 'Tuas South',
        humidity: 70.0,
        humidityStation: 'Tuas South',
        pm25: 25,
        pm25Region: 'west',
        condition: 'Fair',
        areaName: 'Singapore',
        feelsLike: 33.0,
        timestamp: DateTime.now(),
        nearestStationDistance: 30.1,
      );

      expect(beyondBorderWeather.isTooFarFromStation, isTrue);
    });

    test('launchApiHasError notifier defaults to false and updates on error', () {
      expect(launchApiHasError.value, isFalse);
      launchApiHasError.value = true;
      expect(launchApiHasError.value, isTrue);
      launchApiHasError.value = false;
      expect(launchApiHasError.value, isFalse);
    });

    test('UV Index categorization and showUvOnPill precedence rules', () {
      // Moderate UV (5) -> should NOT show on pill
      final moderateUvWeather = WeatherSummary(
        temperature: 31.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 65.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        uvIndex: 5,
        condition: 'Fair',
        areaName: 'Novena',
        feelsLike: 34.0,
        timestamp: DateTime.now(),
      );
      expect(moderateUvWeather.uvCategory, equals('Moderate'));
      expect(moderateUvWeather.showUvOnPill, isFalse);

      // High UV (6) with no rain and no haze -> SHOULD show on pill
      final highUvWeather = WeatherSummary(
        temperature: 32.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 62.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        uvIndex: 6,
        condition: 'Fair',
        areaName: 'Novena',
        feelsLike: 35.0,
        timestamp: DateTime.now(),
      );
      expect(highUvWeather.uvCategory, equals('High'));
      expect(highUvWeather.isHighUv, isTrue);
      expect(highUvWeather.isHighOrAboveUv, isTrue);
      expect(highUvWeather.showUvOnPill, isTrue);
      expect(highUvWeather.iconData, equals(Icons.wb_sunny_rounded));

      // Very High UV (9) with no rain and no haze -> SHOULD show on pill
      final veryHighUvWeather = WeatherSummary(
        temperature: 33.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 60.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        uvIndex: 9,
        condition: 'Fair',
        areaName: 'Novena',
        feelsLike: 37.0,
        timestamp: DateTime.now(),
      );
      expect(veryHighUvWeather.uvCategory, equals('Very High'));
      expect(veryHighUvWeather.isVeryHighUv, isTrue);
      expect(veryHighUvWeather.showUvOnPill, isTrue);
      expect(veryHighUvWeather.iconData, equals(Icons.wb_sunny_rounded));

      // Extreme UV (12) with no rain and no haze -> SHOULD show on pill
      final extremeUvWeather = WeatherSummary(
        temperature: 34.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 55.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        uvIndex: 12,
        condition: 'Fair',
        areaName: 'Novena',
        feelsLike: 38.0,
        timestamp: DateTime.now(),
      );
      expect(extremeUvWeather.uvCategory, equals('Extreme'));
      expect(extremeUvWeather.isExtremeUv, isTrue);
      expect(extremeUvWeather.showUvOnPill, isTrue);

      // Very High UV (9) but RAINING -> Rain takes precedence over UV
      final rainWithUvWeather = WeatherSummary(
        temperature: 28.0,
        temperatureStation: 'Newton',
        rainfall: 2.0,
        rainfallStation: 'Newton',
        humidity: 85.0,
        humidityStation: 'Newton',
        pm25: 25,
        pm25Region: 'central',
        uvIndex: 9,
        condition: 'Showers',
        areaName: 'Novena',
        feelsLike: 31.0,
        timestamp: DateTime.now(),
      );
      expect(rainWithUvWeather.isRain, isTrue);
      expect(rainWithUvWeather.showUvOnPill, isFalse); // Suppressed by rain
      expect(rainWithUvWeather.iconData, equals(Icons.water_drop_rounded));

      // Very High UV (9) but ELEVATED HAZE (PM2.5 = 65) -> Haze takes precedence over UV
      final hazeWithUvWeather = WeatherSummary(
        temperature: 32.0,
        temperatureStation: 'Newton',
        rainfall: 0.0,
        rainfallStation: 'Newton',
        humidity: 60.0,
        humidityStation: 'Newton',
        pm25: 65,
        pm25Region: 'central',
        uvIndex: 9,
        condition: 'Hazy',
        areaName: 'Novena',
        feelsLike: 35.0,
        timestamp: DateTime.now(),
      );
      expect(hazeWithUvWeather.showHazeOnPill, isTrue);
      expect(hazeWithUvWeather.showUvOnPill, isFalse); // Suppressed by haze warning
    });

    test('TwentyFourHourForecast correctly initializes with period data', () {
      final forecast = TwentyFourHourForecast(
        generalForecast: 'Thundery Showers',
        generalCode: 'TL',
        tempLow: 24.0,
        tempHigh: 32.0,
        humidityLow: 65.0,
        humidityHigh: 95.0,
        windDirection: 'SSE',
        windSpeedLow: 15.0,
        windSpeedHigh: 25.0,
        periods: [
          TwentyFourHourPeriod(
            timeText: 'Midday to 6 pm',
            startTime: '2026-09-05T12:00:00+08:00',
            endTime: '2026-09-05T18:00:00+08:00',
            regions: {
              'central': 'Thundery Showers',
              'north': 'Thundery Showers',
              'south': 'Partly Cloudy',
              'east': 'Fair',
              'west': 'Thundery Showers',
            },
          ),
        ],
        timestamp: DateTime.now(),
      );

      expect(forecast.generalForecast, equals('Thundery Showers'));
      expect(forecast.generalCode, equals('TL'));
      expect(forecast.tempLow, equals(24.0));
      expect(forecast.tempHigh, equals(32.0));
      expect(forecast.periods.length, equals(1));
      expect(forecast.periods.first.regions['central'], equals('Thundery Showers'));
    });
  });
}
