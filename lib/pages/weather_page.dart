import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/data_management/weather_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({Key? key}) : super(key: key);

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final WeatherService _weatherService = WeatherService();
  bool _isLoadingForecast = false;
  String? _selectedAreaOverride;
  WeatherSummary? _activeSummaryOverride;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingForecast = true;
    });
    try {
      await Future.wait([
        if (globalWeather.value == null || forceRefresh)
          _weatherService.fetchRealtimeWeather(forceRefresh: forceRefresh),
        _weatherService.fetchTwentyFourHourForecast(forceRefresh: forceRefresh),
      ]);
      if (_selectedAreaOverride != null) {
        _activeSummaryOverride =
            _weatherService.resolveWeatherForArea(_selectedAreaOverride!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForecast = false;
        });
      }
    }
  }

  TextStyle _roundedStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    final weight = fontWeight ?? FontWeight.normal;
    return TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: [
        const FontVariation('ROND', 100),
        FontVariation.weight(weight.index * 100 + 100),
      ],
    );
  }

  String _simplifyWindDirection(String dir) {
    switch (dir.trim().toUpperCase()) {
      case 'N':
        return 'North';
      case 'S':
        return 'South';
      case 'E':
        return 'East';
      case 'W':
        return 'West';
      case 'NE':
      case 'NNE':
      case 'ENE':
        return 'North-East';
      case 'NW':
      case 'NNW':
      case 'WNW':
        return 'North-West';
      case 'SE':
      case 'SSE':
      case 'ESE':
        return 'South-East';
      case 'SW':
      case 'SSW':
      case 'WSW':
        return 'South-West';
      default:
        return dir;
    }
  }

  void _showAreaPicker(BuildContext context, WeatherSummary summary) {
    if (summary.allAreaForecasts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        "Singapore Forecast Areas",
                        style: _roundedStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedAreaOverride != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedAreaOverride = null;
                              _activeSummaryOverride = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Reset to GPS",
                            style: _roundedStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: summary.allAreaForecasts.length,
                    itemBuilder: (context, index) {
                      final item = summary.allAreaForecasts[index];
                      final isSelected =
                          (_selectedAreaOverride ?? summary.areaName) ==
                              item.area;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.location_on_outlined,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          item.area,
                          style: _roundedStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          item.forecast,
                          style: _roundedStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          final resolved =
                              _weatherService.resolveWeatherForArea(item.area);
                          setState(() {
                            _selectedAreaOverride = item.area;
                            _activeSummaryOverride = resolved;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ValueListenableBuilder<dynamic>(
          valueListenable: globalWeather,
          builder: (context, weather, child) {
            final gpsSummary = weather as WeatherSummary?;
            final summary = _activeSummaryOverride ?? gpsSummary;
            final currentArea = summary?.areaName ?? "Singapore";
            return GestureDetector(
              onTap: summary != null
                  ? () => _showAreaPicker(context, summary)
                  : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location_rounded, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        currentArea,
                        style: _roundedStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, size: 13),
                  ],
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoadingForecast
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed:
                _isLoadingForecast ? null : () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: ValueListenableBuilder<dynamic>(
        valueListenable: globalWeather,
        builder: (context, weather, child) {
          final gpsSummary = weather as WeatherSummary?;
          final summary = _activeSummaryOverride ?? gpsSummary;
          if (summary == null && _isLoadingForecast) {
            return const Center(child: LoadingIndicatorM3E());
          }
          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    "Weather data unavailable",
                    style: _roundedStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _loadData(forceRefresh: true),
                    child: Text("Retry",
                        style: _roundedStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(28.0)),
              child: RefreshIndicator(
                onRefresh: () => _loadData(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    0,
                    8,
                    0,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero Weather Section
                      _buildHeroWeather(context, summary, summary.condition),

                      const SizedBox(height: 24),

                      // PM2.5 Warning Banner if > 50
                      if (summary.isHazy) _buildHazeAlertCard(context, summary),

                      // Hourly / 24-hr Forecast Graph Card (Scrollable)
                      ValueListenableBuilder<TwentyFourHourForecast?>(
                        valueListenable:
                            _weatherService.twentyFourHourForecastNotifier,
                        builder: (context, forecast24, _) {
                          return _buildHourlyForecastCard(
                              context, summary, forecast24);
                        },
                      ),

                      const SizedBox(height: 16),

                      // 24-Hour Forecast & Regional Outlook
                      ValueListenableBuilder<TwentyFourHourForecast?>(
                        valueListenable:
                            _weatherService.twentyFourHourForecastNotifier,
                        builder: (context, forecast24, child) {
                          return _buildTwentyFourHourCard(
                              context, forecast24, summary);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Weather Metrics Grid (Rainfall, Humidity, PM2.5, Temperature)
                      _buildMetricsGrid(context, summary),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroWeather(
      BuildContext context, WeatherSummary summary, String conditionText) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tempRounded = summary.temperature.round();
    final feelsLikeRounded = summary.feelsLike.round();

    return Column(
      children: [
        const SizedBox(height: 4),
        Icon(
          summary.iconData,
          size: 78,
          color: summary.isUnhealthyHaze
              ? (isDark ? Colors.red.shade400 : Colors.red.shade700)
              : summary.isRain
                  ? (isDark
                      ? Colors.lightBlueAccent
                      : Colors.lightBlue.shade800)
                  : summary.isHazy
                      ? (isDark ? Colors.amber[300] : Colors.amber.shade900)
                      : theme.colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$tempRounded",
              style: _roundedStyle(
                fontSize: 92,
                fontWeight: FontWeight.w600,
                letterSpacing: -2,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "°",
                style: _roundedStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        Text(
          conditionText,
          style: _roundedStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "Feels like $feelsLikeRounded°",
          style: _roundedStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHazeAlertCard(BuildContext context, WeatherSummary summary) {
    String title;
    String advice;
    Color cardColor;
    Color textColor;
    IconData alertIcon;

    if (summary.pm25 > 300) {
      title = "Hazardous Air Quality (PM2.5: ${summary.pm25} µg/m³)";
      advice = "Minimise outdoor activity. Wear N95 masks outdoors.";
      cardColor = Colors.red.shade900.withOpacity(0.85);
      textColor = Colors.white;
      alertIcon = Icons.warning_rounded;
    } else if (summary.pm25 > 200) {
      title = "Very Unhealthy Air Quality (PM2.5: ${summary.pm25} µg/m³)";
      advice = "Avoid prolonged or strenuous outdoor physical exertion.";
      cardColor = Colors.red.shade900.withOpacity(0.85);
      textColor = Colors.white;
      alertIcon = Icons.warning_amber_rounded;
    } else if (summary.pm25 > 100) {
      title = "Unhealthy Air Quality (PM2.5: ${summary.pm25} µg/m³)";
      advice =
          "Reduce prolonged or strenuous outdoor exertion. Sensitive groups should minimise outdoor activity.";
      cardColor = Colors.red.shade900.withOpacity(0.85);
      textColor = Colors.white;
      alertIcon = Icons.warning_amber_rounded;
    } else {
      title = "Elevated PM2.5 Air Quality (${summary.pm25} µg/m³)";
      advice =
          "Normal activities for most. Sensitive individuals (elderly, pregnant, children, lung/heart conditions) should monitor symptoms.";
      cardColor = Colors.amber.shade900.withOpacity(0.85);
      textColor = Colors.white;
      alertIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(alertIcon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _roundedStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  advice,
                  style: _roundedStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecastCard(BuildContext context, WeatherSummary summary,
      TwentyFourHourForecast? forecast24) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Generate upcoming 24 hours of hourly projections
    final List<Map<String, dynamic>> hourlyData = [];
    final currentTemp = summary.temperature;
    final minT = forecast24?.tempLow ?? 26.0;
    final maxT = forecast24?.tempHigh ?? 33.0;

    for (int i = 0; i < 24; i++) {
      final hourTime = now.add(Duration(hours: i));
      final hourLabel =
          i == 0 ? "Now" : "${hourTime.hour.toString().padLeft(2, '0')}:00";
      final isNightHour = hourTime.hour < 7 || hourTime.hour >= 19;

      // Realistic diurnal cycle projection throughout 24 hours
      // Peak heat at 14:00 (2 PM), coolest at 06:00 (6 AM)
      final hourFrac = (hourTime.hour - 6) / 24.0 * 2 * math.pi;
      final tempProgress =
          (-math.cos(hourFrac) + 1) / 2.0; // 0 at 6am, 1 at 2pm
      double projectedTemp;
      if (i == 0) {
        projectedTemp = currentTemp;
      } else {
        projectedTemp = minT + (maxT - minT) * tempProgress;
      }
      final tempRound = projectedTemp.round();

      IconData hourIcon;
      if (summary.isRain) {
        hourIcon = summary.isDrizzle
            ? Icons.water_drop_outlined
            : summary.isThunderstorm
                ? Icons.thunderstorm_rounded
                : Icons.water_drop_rounded;
      } else {
        hourIcon =
            isNightHour ? Icons.nightlight_round : Icons.wb_sunny_rounded;
      }

      hourlyData.add({
        'label': hourLabel,
        'temp': tempRound,
        'icon': hourIcon,
      });
    }

    const double itemWidth = 64.0;
    final double totalWidth = hourlyData.length * itemWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Hourly forecast",
            style: _roundedStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    // Times and Icons row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: hourlyData.map((h) {
                        return SizedBox(
                          width: itemWidth,
                          child: Column(
                            children: [
                              Text(
                                h['label'] as String,
                                style: _roundedStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                h['icon'] as IconData,
                                size: 22,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Scrollable Trendline Graph & Temp numbers
                    SizedBox(
                      height: 52,
                      width: totalWidth,
                      child: CustomPaint(
                        size: Size(totalWidth, 52),
                        painter: _HourlyForecastGraphPainter(
                          hourlyData: hourlyData,
                          itemWidth: itemWidth,
                          lineColor: Colors.deepOrangeAccent.shade200,
                          textColor: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwentyFourHourCard(BuildContext context,
      TwentyFourHourForecast? forecast24, WeatherSummary summary) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "24-Hour Outlook",
                style: _roundedStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (forecast24 != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    forecast24.generalForecast,
                    style: _roundedStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (forecast24 == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: LoadingIndicatorM3E(),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOutlookStat(
                  context,
                  "Temperature",
                  "${forecast24.tempLow.round()}° - ${forecast24.tempHigh.round()}°",
                  Icons.thermostat_rounded,
                ),
                _buildOutlookStat(
                  context,
                  "Humidity",
                  "${forecast24.humidityLow.round()}% - ${forecast24.humidityHigh.round()}%",
                  Icons.water_drop_outlined,
                ),
                _buildOutlookStat(
                  context,
                  _simplifyWindDirection(forecast24.windDirection),
                  "${forecast24.windSpeedHigh.round()} km/h",
                  Icons.air_rounded,
                ),
              ],
            ),
            if (forecast24.periods.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                "Regional Forecast (${summary.pm25Region.toUpperCase()}):",
                style: _roundedStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...forecast24.periods.map((p) {
                final condition = p.regions[summary.pm25Region] ??
                    p.regions['central'] ??
                    forecast24.generalForecast;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          p.timeText,
                          style: _roundedStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          condition,
                          textAlign: TextAlign.end,
                          style: _roundedStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOutlookStat(
      BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: _roundedStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: _roundedStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, WeatherSummary summary) {
    // Differentiate rainfall
    String rainCategory = "No rain";
    if (summary.rainfall > 7.5) {
      rainCategory = "Heavy rain";
    } else if (summary.rainfall > 1.5) {
      rainCategory = "Moderate rain";
    } else if (summary.rainfall > 0) {
      rainCategory = "Light drizzle";
    }

    // PM2.5 Air quality status based on chart
    final pm25Status = summary.airQualityCategory;
    final pm25Color = summary.airQualityColor;

    // Use direct Rows with Expanded to avoid GridView ambient padding / random gaps
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: "Rainfall",
                value: "${summary.rainfall.toStringAsFixed(1)} mm",
                subtitle: rainCategory,
                icon: summary.isDrizzle
                    ? Icons.grain_rounded
                    : summary.isHeavyRain
                        ? Icons.thunderstorm_rounded
                        : Icons.umbrella_rounded,
                iconColor: summary.isRain ? Colors.lightBlue : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: "Humidity",
                value: "${summary.humidity.round()}%",
                subtitle: "Station: ${summary.humidityStation}",
                icon: Icons.water_drop_outlined,
                iconColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: "PM2.5 Air Quality",
                value: "${summary.pm25} µg/m³",
                subtitle: pm25Status,
                subtitleColor: pm25Color,
                icon: Icons.air_rounded,
                iconColor: pm25Color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: "Temperature",
                value: "${summary.temperature.toStringAsFixed(1)}°C",
                subtitle: "Station: ${summary.temperatureStation}",
                icon: Icons.thermostat_rounded,
                iconColor: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: "UV Index",
                value: "${summary.uvIndex}",
                subtitle: summary.uvCategory,
                subtitleColor: summary.uvColor,
                icon: Icons.wb_sunny_rounded,
                iconColor: summary.uvColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: "Data provided by",
                value: "NEA & MSS",
                subtitle: "weather.gov.sg",
                subtitleColor: Theme.of(context).colorScheme.primary,
                icon: Icons.open_in_new_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                onTap: () async {
                  final url = Uri.parse('https://www.weather.gov.sg');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    Color? subtitleColor,
    VoidCallback? onTap,
    double? valueFontSize,
  }) {
    final theme = Theme.of(context);
    final cardContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: _roundedStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon,
                  size: 18,
                  color: iconColor ?? theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: _roundedStyle(
              fontSize: valueFontSize ?? 22,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _roundedStyle(
              fontSize: 12,
              color: subtitleColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  subtitleColor != null ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }
}

/// Custom painter to draw the connected trend line across forecast points
class _HourlyForecastGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> hourlyData;
  final double itemWidth;
  final Color lineColor;
  final Color textColor;

  _HourlyForecastGraphPainter({
    required this.hourlyData,
    required this.itemWidth,
    required this.lineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyData.isEmpty) return;

    final n = hourlyData.length;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // Calculate Y coordinates based on min/max temp
    int minT = hourlyData.first['temp'] as int;
    int maxT = hourlyData.first['temp'] as int;
    for (var h in hourlyData) {
      final t = h['temp'] as int;
      if (t < minT) minT = t;
      if (t > maxT) maxT = t;
    }
    final range = math.max(1, maxT - minT);

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = (i * itemWidth) + (itemWidth / 2);
      final t = hourlyData[i]['temp'] as int;
      final normalized = (t - minT) / range;
      final y = size.height * 0.35 - (normalized * 8) + 4;
      points.add(Offset(x, y));
    }

    // Draw connecting line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw dots and text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 3, dotPaint);

      final tempText = "${hourlyData[i]['temp']}°";
      textPainter.text = TextSpan(
        text: tempText,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'GoogleSansFlex',
          fontVariations: const [
            FontVariation('ROND', 100),
            FontVariation.weight(700),
          ],
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - (textPainter.width / 2), p.dy + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyForecastGraphPainter oldDelegate) {
    return oldDelegate.hourlyData != hourlyData ||
        oldDelegate.itemWidth != itemWidth ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor;
  }
}
