import 'package:flutter/material.dart';
import 'package:sgbus/pages/weather_page.dart';
import 'package:sgbus/scripts/data_management/weather_service.dart';

class WeatherPill extends StatelessWidget {
  final WeatherSummary weather;
  final VoidCallback? onTap;

  const WeatherPill({
    Key? key,
    required this.weather,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color pillColor;
    Color pillBorderColor;
    Color pillIconColor;
    Color pillTextColor;

    if (weather.showHazeOnPill) {
      if (weather.isUnhealthyHaze) {
        pillColor = isDark
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.5)
            : const Color(0xFFFFDAD6);
        pillBorderColor = isDark
            ? Theme.of(context).colorScheme.error.withOpacity(0.4)
            : const Color(0xFFBA1A1A).withOpacity(0.4);
        pillIconColor = isDark
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFBA1A1A);
        pillTextColor = isDark
            ? Theme.of(context).colorScheme.onErrorContainer
            : const Color(0xFF410002);
      } else {
        // Elevated Haze (PM2.5 51-100)
        pillColor = isDark
            ? Colors.amber.withOpacity(0.18)
            : const Color(0xFFFFF0C2);
        pillBorderColor = isDark
            ? Colors.amber.withOpacity(0.4)
            : const Color(0xFFE6A800).withOpacity(0.5);
        pillIconColor = isDark
            ? Colors.amber.shade400
            : const Color(0xFF8B5000);
        pillTextColor = isDark
            ? Colors.amber.shade300
            : const Color(0xFF724000);
      }
    } else if (weather.isRain) {
      pillColor = isDark
          ? Colors.lightBlue.withOpacity(0.15)
          : const Color(0xFFE1F5FE);
      pillBorderColor = isDark
          ? Colors.lightBlueAccent.withOpacity(0.3)
          : const Color(0xFF81D4FA);
      pillIconColor = isDark
          ? Colors.lightBlueAccent
          : const Color(0xFF0277BD);
      pillTextColor = isDark
          ? Theme.of(context).colorScheme.onSurface
          : const Color(0xFF01579B);
    } else if (weather.showUvOnPill) {
      if (weather.isExtremeUv) {
        // Extreme UV (11+) -> Purple
        pillColor = isDark
            ? Colors.purple.withOpacity(0.22)
            : const Color(0xFFF3E5F5);
        pillBorderColor = isDark
            ? Colors.purpleAccent.withOpacity(0.4)
            : const Color(0xFFAB47BC).withOpacity(0.5);
        pillIconColor = isDark
            ? Colors.purpleAccent.shade100
            : const Color(0xFF7B1FA2);
        pillTextColor = isDark
            ? Colors.purple.shade200
            : const Color(0xFF4A148C);
      } else if (weather.isVeryHighUv) {
        // Very High UV (8-10) -> Red
        pillColor = isDark
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.4)
            : const Color(0xFFFFEBEE);
        pillBorderColor = isDark
            ? Theme.of(context).colorScheme.error.withOpacity(0.4)
            : const Color(0xFFEF5350).withOpacity(0.5);
        pillIconColor = isDark
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFC62828);
        pillTextColor = isDark
            ? Theme.of(context).colorScheme.onErrorContainer
            : const Color(0xFFB71C1C);
      } else {
        // High UV (6-7) -> Orange
        pillColor = isDark
            ? Colors.orange.withOpacity(0.22)
            : const Color(0xFFFFF3E0);
        pillBorderColor = isDark
            ? Colors.orangeAccent.withOpacity(0.4)
            : const Color(0xFFFFB74D).withOpacity(0.6);
        pillIconColor = isDark
            ? Colors.orangeAccent.shade100
            : Colors.orange.shade800;
        pillTextColor = isDark
            ? Colors.orange.shade200
            : const Color(0xFFE65100);
      }
    } else {
      pillColor = Theme.of(context)
          .colorScheme
          .surfaceVariant
          .withOpacity(isDark ? 0.5 : 0.7);
      pillBorderColor = Theme.of(context)
          .colorScheme
          .outlineVariant
          .withOpacity(isDark ? 0.2 : 0.4);
      pillIconColor = Theme.of(context).colorScheme.primary;
      pillTextColor = Theme.of(context).colorScheme.onSurface;
    }

    return Material(
      key: const ValueKey('weather_pill'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const WeatherPage(),
                ),
              );
            },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: pillBorderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                weather.iconData,
                size: 19,
                color: pillIconColor,
              ),
              const SizedBox(width: 8),
              Text(
                weather.showHazeOnPill
                    ? "Haze ${weather.pm25}"
                    : weather.showUvOnPill
                        ? "UV ${weather.uvIndex}"
                        : "${weather.temperature.round()}°",
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontVariations: const [
                    FontVariation('ROND', 100),
                    FontVariation.weight(700),
                  ],
                  color: pillTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
