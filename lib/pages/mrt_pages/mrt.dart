import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:from_css_color/from_css_color.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sgbus/components/searchBar.dart';
import 'package:sgbus/pages/cepas_reader.dart';
import 'package:sgbus/pages/mrt_pages/mrt_map.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sgbus/pages/mrt_pages/station_page.dart';
import 'package:sgbus/components/trainStationListView.dart';
import 'dart:math';

class MRT extends StatefulWidget {
  const MRT({Key? key}) : super(key: key);

  @override
  State<MRT> createState() => _MRTState();
}

class _MRTState extends State<MRT> {
  var mrtData;
  var alerts;

  void initPage() {
    mrtData = getMRTData();
    alerts = globalAlerts.value;

    globalAlerts.addListener(() {
      setState(() {
        alerts = globalAlerts.value;
      });
    });
  }

  @override
  void initState() {
    initPage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: (mrtData != null)
          ? Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(28.0)),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 5),
                            child: Row(
                              children: [
                                Text(
                                  "Nearby Stations:",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          NearbyStationsWidget(stations: mrtData!["stations"]),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
                            child: Row(
                              children: [
                                Text(
                                  "Lines & Status:",
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.all(Radius.circular(28.0)),
                            child: Column(
                              children: [
                                for (var line in mrtData!["lines"])
                                  LineStatusListTile(
                                      line: line, alerts: alerts),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(8, 10, 8, getNavBarClearance(context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'mrt-map', // Shared tag
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(200),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => const MRTMap()));
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.route_rounded),
                                    const SizedBox(width: 8),
                                    Text(
                                      "MRT Map",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        fontVariations: [
                                          FontVariation.weight(800),
                                          FontVariation.width(100),
                                          FontVariation("ROND", 100)
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SearchBarWidget(
                          initialTabIndex: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ExpressiveLoadingIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// NearbyStationsWidget
// ---------------------------------------------------------------------------

class NearbyStationsWidget extends StatefulWidget {
  const NearbyStationsWidget({Key? key, required this.stations})
      : super(key: key);

  final List stations;

  @override
  State<NearbyStationsWidget> createState() => _NearbyStationsWidgetState();
}

class _NearbyStationsWidgetState extends State<NearbyStationsWidget> {
  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  bool isLoaded = false;
  List nearbyStations = [];
  Position? currLocation;

  final Random _random = Random();

  Future<void> getNearbyStops() async {
    setState(() {
      isLoaded = false;
    });

    try {
      final LocationResult result =
          await LocationHelper.getUserLocation(context);
      if (result.hasError || result.position == null) {
        setState(() {
          currLocation = null;
          isLoaded = true;
        });
        return;
      }

      final position = result.position!;

      final List sorted = await compute(
        _calculateNearbyStations,
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'stations': List<dynamic>.from(widget.stations),
        },
      );

      setState(() {
        currLocation = position;
        nearbyStations = sorted;
        isLoaded = true;
      });
    } catch (e) {
      setState(() {
        currLocation = null;
        isLoaded = true;
      });
    }
  }

  @override
  void initState() {
    getNearbyStops();
    super.initState();
  }

  List _skeletonStations() => List.generate(2, (index) {
        return {
          "name":
              "Loading" + List.generate(_random.nextInt(10), (_) => ".").join(),
          "codes": ["XX00"],
          "dist": 0,
        };
      });

  @override
  Widget build(BuildContext context) {
    final displayStations = isLoaded ? nearbyStations : _skeletonStations();

    return RefreshIndicator(
      onRefresh: getNearbyStops,
      child: !isLoaded
          ? Skeletonizer(
              enabled: true,
              child: _StationList(
                stations: displayStations,
                context: context,
              ),
            )
          : currLocation == null
              ? _LocationError(onRetry: getNearbyStops)
              : nearbyStations.isNotEmpty
                  ? _StationList(
                      stations: nearbyStations,
                      context: context,
                    )
                  : _NoStationsNearby(),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _StationList extends StatelessWidget {
  const _StationList({required this.stations, required this.context});

  final List stations;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          for (var entry in stations.asMap().entries)
            _StationTile(
              station: entry.value,
              isFirst: entry.key == 0,
              isLast: entry.key == stations.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.isFirst,
    required this.isLast,
  });

  final dynamic station;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final List codes = station['codes'] as List? ?? [];
    final int dist = station['dist'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft:
              isFirst ? const Radius.circular(28.0) : const Radius.circular(5),
          topRight:
              isFirst ? const Radius.circular(28.0) : const Radius.circular(5),
          bottomLeft:
              isLast ? const Radius.circular(28.0) : const Radius.circular(5),
          bottomRight:
              isLast ? const Radius.circular(28.0) : const Radius.circular(5),
        ),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: TrainStationListTile(
        station: station,
        trailing: Text(
          '${dist}m',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () {
          if (codes.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StationPage(stationCode: codes.first),
              ),
            );
          }
        },
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Icon(
                Icons.location_off_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            Text(
              "Location access is required to find nearby MRT stations.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoStationsNearby extends StatelessWidget {
  const _NoStationsNearby();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(28.0),
      ),
      child: ListTile(
        leading: Icon(Icons.warning_rounded,
            color: Theme.of(context).colorScheme.error),
        title: Text(
          "No MRT stations near you.",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            // color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Isolate top-level function
// ---------------------------------------------------------------------------

List<dynamic> _calculateNearbyStations(Map<String, dynamic> args) {
  final double latitude = args['latitude'] as double;
  final double longitude = args['longitude'] as double;
  final List<dynamic> stations = args['stations'] as List<dynamic>;

  final List<dynamic> nearby = [];

  for (var station in stations) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(station as Map);

    final double? stationLat = copy['latitude'] as double?;
    final double? stationLon = copy['longitude'] as double?;

    if (stationLat == null || stationLon == null) continue;

    final double distMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      stationLat,
      stationLon,
    );

    copy['dist'] = distMeters.round();

    if (distMeters < 1500) {
      nearby.add(copy);
    }
  }

  nearby.sort((a, b) => (a['dist'] as num).compareTo(b['dist'] as num));

  return nearby;
}

// ---------------------------------------------------------------------------
// LineStatusListTile (unchanged)
// ---------------------------------------------------------------------------

class LineStatusListTile extends StatefulWidget {
  const LineStatusListTile({
    super.key,
    required this.line,
    required this.alerts,
  });

  final dynamic line;
  final alerts;

  @override
  State<LineStatusListTile> createState() => _LineStatusListTileState();
}

class _LineStatusListTileState extends State<LineStatusListTile> {
  var activeAlertData;
  bool hasLoadedLaunch = hasFetchedLaunchData.value;

  void fetchLinesAlerts(String lineCode) {
    for (var alert in widget.alerts) {
      if (alert["affectedLine"] == lineCode) {
        activeAlertData = alert;
      }
    }
  }

  @override
  void initState() {
    fetchLinesAlerts(widget.line["code"]);
    hasFetchedLaunchData.addListener(() {
      setState(() {
        hasLoadedLaunch = hasFetchedLaunchData.value;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: ListTile(
        // visualDensity: VisualDensity.compact,
        // dense: true,
        title: Text(
          widget.line["name"],
        ),
        subtitle:
            activeAlertData != null ? Text(activeAlertData["header"]) : null,
        trailing: activeAlertData != null
            ? activeAlertData["severity"] == "low"
                ? Icon(
                    Icons.info_rounded,
                    color: isDark ? Colors.amber[200] : Colors.amber[600],
                  )
                : Icon(Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error)
            : hasLoadedLaunch
                ? Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? Colors.green[200] : Colors.green[400],
                  )
                : Icon(Icons.circle, color: Colors.grey),
        leading: Container(
          padding: EdgeInsetsGeometry.fromLTRB(10, 5, 10, 5),
          child: Text(
            widget.line["code"],
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontVariations: [
                FontVariation('ROND', 0),
                FontVariation.weight(700)
              ],
            ),
          ),
          decoration: BoxDecoration(
            color: fromCssColor(widget.line["lineColor"]),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}
