import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:from_css_color/from_css_color.dart';
import 'package:sgbus/components/amenity_list_tile.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/components/trainStationListView.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:skeletonizer/skeletonizer.dart';

class StationPage extends StatefulWidget {
  final String stationCode;
  const StationPage({super.key, required this.stationCode});

  @override
  State<StationPage> createState() => _StationPageState();
}

class _StationPageState extends State<StationPage>
    with SingleTickerProviderStateMixin {
  MapboxMap? mapboxMap;
  var station;
  bool isLoaded = false;

  late TabController bottomSheetTabController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    // Fixed: Changed length to 5 to match the number of tabs
    bottomSheetTabController = TabController(
      length: 5,
      vsync: this,
    );
    _loadStationData();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    bottomSheetTabController.dispose();
    super.dispose();
  }

  void _loadStationData() {
    final mrtDataMap = getMRTData();
    if (mrtDataMap != null && mrtDataMap["stations"] != null) {
      for (var s in mrtDataMap["stations"]) {
        final codes = s["codes"] as List? ?? [];
        if (codes.contains(widget.stationCode)) {
          station = s;
          break;
        }
      }
    }
    setState(() {
      isLoaded = true;
    });
  }

  Color _getLineColor(String code) {
    final prefix = RegExp(r'^[a-zA-Z]+').stringMatch(code) ?? '';
    final data = getMRTData();
    if (data != null && data['lines'] != null) {
      for (var line in data['lines']) {
        if (line['code'] == prefix) {
          return fromCssColor(line['lineColor']);
        }
      }
    }
    return Colors.blue;
  }

  Future<void> _fitCameraToStation() async {
    if (station == null || mapboxMap == null) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    void updateBounds(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final double? sLat = station['latitude'] as double?;
    final double? sLng = station['longitude'] as double?;
    if (sLat != null && sLng != null) {
      updateBounds(sLat, sLng);
    }

    final boundariesList = station['boundaries'] as List? ?? [];
    for (var encoded in boundariesList) {
      final decodedCoords = decodePolyline(encoded as String);
      for (var c in decodedCoords) {
        updateBounds(c[0].toDouble(), c[1].toDouble());
      }
    }

    final exitsList = station['exits'] as List? ?? [];
    for (var exit in exitsList) {
      final coords = exit['coordinates'] as List? ?? [];
      if (coords.length >= 2) {
        updateBounds(
            (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
      }
    }

    if (minLat < maxLat && minLng < maxLng) {
      if (maxLat - minLat < 0.001) {
        minLat -= 0.001;
        maxLat += 0.001;
      }
      if (maxLng - minLng < 0.001) {
        minLng -= 0.001;
        maxLng += 0.001;
      }

      CameraOptions cameraOptions = await mapboxMap!.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: Point(coordinates: Position(minLng, minLat)),
          northeast: Point(coordinates: Position(maxLng, maxLat)),
          infiniteBounds: false,
        ),
        MbxEdgeInsets(
            top: 180.0,
            left: 70.0,
            bottom: MediaQuery.sizeOf(context).height * 0.5,
            right: 70.0),
        null,
        null,
        null,
        null,
      );

      mapboxMap?.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));
    } else if (sLat != null && sLng != null) {
      mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(sLng, sLat)),
          zoom: 17.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (station == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Station not found'),
        ),
      );
    }

    final double topSafeArea = MediaQuery.paddingOf(context).top;
    final double height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            station['name'],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        // actions: [
        //   Container(
        //     padding: const EdgeInsets.all(5),
        //     margin: EdgeInsets.only(right: 12),
        //     decoration: BoxDecoration(
        //       color: Theme.of(context).colorScheme.surface,
        //       borderRadius: BorderRadius.circular(24),
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.15),
        //           blurRadius: 6,
        //           offset: const Offset(0, 3),
        //         ),
        //       ],
        //     ),
        //     child: StationCodePills(station: station),
        //   )
        // ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BaseMap(
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    (station['longitude'] as num).toDouble(),
                    (station['latitude'] as num).toDouble(),
                  ),
                ),
                zoom: 16.5,
              ),
              onMapCreated: (map) {
                mapboxMap = map;
              },
              onStyleLoaded: (map) {
                _fitCameraToStation();
              },
              showCompass: true,
              showScaleBar: true,
              topPadding: MediaQuery.paddingOf(context).top + kToolbarHeight,
              bottomPadding: height * 0.4 + 10,
              // All 4 toggles shown (default)
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.4,
            minChildSize: 0.4,
            maxChildSize: 0.8,
            snap: true,
            snapSizes: const [0.4, 0.8],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                // Fixed Layout Error: Replaced ListView with a Column + SingleChildScrollView strategy
                // to allow the TabBarView to properly expand inside the DraggableScrollableSheet.
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      dividerColor: Colors.transparent,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      controller:
                          bottomSheetTabController, // Fixed: Linked controller here
                      tabs: const [
                        Tab(child: Text("Amenities")),
                        Tab(child: Text("Crowdedness")),
                        Tab(child: Text("First/Last Train")),
                        Tab(child: Text("Exits")),
                        Tab(child: Text("Bus Stops")),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: bottomSheetTabController,
                        children: [
                          // Using SingleChildScrollView linked to scrollController
                          // so pulling down on the tab lists collapses the sheet nicely
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16.0),
                            child: AmenitiesCard(
                              amenities: (station['amenities'] as List? ?? [])
                                  .map((e) => e as Map<String, dynamic>)
                                  .toList(),
                              onSearchTapped: () {
                                if (_sheetController.isAttached) {
                                  _sheetController.animateTo(
                                    0.8,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16.0),
                            child: CrowdednessCard(
                              stationCodes: (station['codes'] as List?)
                                      ?.map((e) => e.toString())
                                      .toList() ??
                                  [],
                            ),
                          ),
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16.0),
                            child: TrainTimingsCard(
                              timingsData:
                                  (station['trainFirstLastData'] as List? ?? [])
                                      .map((e) => e as Map<String, dynamic>)
                                      .toList(),
                            ),
                          ),
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(8),
                            child: ExitsCard(
                              exits: (station['exits'] as List? ?? [])
                                  .map((e) => e as Map<String, dynamic>)
                                  .toList(),
                              exitDataApproximate:
                                  station['exitDataApproximate'],
                            ),
                          ),
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(8),
                            child: NearbyStopsCard(
                              stationLat:
                                  (station['latitude'] as num).toDouble(),
                              stationLng:
                                  (station['longitude'] as num).toDouble(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- Amenities Card ----------

class AmenitiesCard extends StatefulWidget {
  final List<Map<String, dynamic>> amenities;
  final VoidCallback? onSearchTapped;
  const AmenitiesCard(
      {super.key, required this.amenities, this.onSearchTapped});

  @override
  State<AmenitiesCard> createState() => _AmenitiesCardState();
}

class _AmenitiesCardState extends State<AmenitiesCard> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    if (widget.amenities.isEmpty) {
      return Container(
        decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 15),
            Text(
              'SG Bus was unable to find amenities at this station.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontVariations: [
                  FontVariation('ROND', 100),
                  FontVariation.width(110),
                  FontVariation.weight(700),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final filteredAmenities = widget.amenities.where((a) {
      final name = (a['name'] as String? ?? "").toLowerCase();
      final type = (a['type'] as String? ?? "").toLowerCase();
      final unit = (a['unit'] as String? ?? "").toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          type.contains(query) ||
          unit.contains(query);
    }).toList();

    return Column(
      children: [
        TextField(
          onTap: widget.onSearchTapped,
          decoration: InputDecoration(
            hintText: 'Search amenities...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 12),
        if (filteredAmenities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No amenities match your search.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (var i = 0; i < filteredAmenities.length; i++)
          AmenityListTile(
            showSubtitle: true,
            amenity: filteredAmenities[i],
            isFirst: i == 0,
            isLast: i == filteredAmenities.length - 1,
          ),
      ],
    );
  }
}

// ---------- Crowdedness Card ----------

class CrowdednessCard extends StatefulWidget {
  final List<String> stationCodes;
  const CrowdednessCard({super.key, required this.stationCodes});

  @override
  State<CrowdednessCard> createState() => _CrowdednessCardState();
}

class _CrowdednessCardState extends State<CrowdednessCard> {
  // ── Static in-memory cache ────────────────────────────────────────────────
  // Key: lineCode (e.g. "EWL")
  // Value: { 'data': Map<String, dynamic>, 'fetchedAt': DateTime }
  static final Map<String, Map<String, dynamic>> _lineCache = {};
  static const Duration _cacheTTL = Duration(minutes: 2);
  // ─────────────────────────────────────────────────────────────────────────

  // Maps stationCode (e.g. "CC17") -> {crowdLevel, lineName, lineColor, ...}
  // crowdLevel is null while the entry is still loading.
  Map<String, Map<String, dynamic>> _crowdData = {};
  String? _errorMessage;
  bool _isFetching = true;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  String? _getLineCodeForStation(String stationCode, List allLines) {
    for (final l in allLines) {
      if (l is Map) {
        final lStations = l['stations'] as List? ?? [];
        for (final s in lStations) {
          if (s is Map && s['code'] == stationCode) {
            return l['code'] as String?;
          }
        }
      }
    }
    return null;
  }

  String? _getLineColorStr(String stationCode, List allLines) {
    for (final l in allLines) {
      if (l is Map) {
        final lStations = l['stations'] as List? ?? [];
        for (final s in lStations) {
          if (s is Map && s['code'] == stationCode) {
            return l['lineColor'] as String?;
          }
        }
      }
    }
    return null;
  }

  void _initData({bool forceRefresh = false}) {
    final mrtDataMap = getMRTData();
    final allLines = mrtDataMap?['lines'] as List? ?? [];

    DateTime? oldestFetch;
    List<String> linesToFetch = [];
    Map<String, Map<String, dynamic>> initialData = {};

    for (final code in widget.stationCodes) {
      final lineCode = _getLineCodeForStation(code, allLines);
      if (lineCode == null) continue;

      final cached = _lineCache[lineCode];
      final fetchedAt = cached?['fetchedAt'] as DateTime?;

      final isFresh = !forceRefresh &&
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _cacheTTL;

      if (isFresh) {
        final lineData = cached!['data'] as Map<String, dynamic>;
        final entryData = lineData[code];
        if (entryData != null) {
          initialData[code] = Map<String, dynamic>.from(entryData);
        } else {
          initialData[code] = {
            'crowdLevel': null,
            'lineName': null,
            'lineColor': _getLineColorStr(code, allLines),
            'startTime': null,
            'endTime': null,
          };
        }

        if (oldestFetch == null || fetchedAt.isBefore(oldestFetch)) {
          oldestFetch = fetchedAt;
        }
      } else {
        if (!linesToFetch.contains(lineCode)) {
          linesToFetch.add(lineCode);
        }
        initialData[code] = {
          'crowdLevel': null,
          'lineName': null,
          'lineColor': _getLineColorStr(code, allLines),
          'startTime': null,
          'endTime': null,
        };
      }
    }

    setState(() {
      _crowdData = initialData;
      _lastUpdated = oldestFetch;
      _isFetching = linesToFetch.isNotEmpty;
    });

    if (linesToFetch.isNotEmpty) {
      _fetchCrowdData(linesToFetch);
    }
  }

  Future<void> _fetchCrowdData(List<String> lineCodesToFetch) async {
    final mrtDataMap = getMRTData();
    if (mrtDataMap == null || mrtDataMap['lines'] == null) {
      if (mounted) setState(() => _errorMessage = 'MRT data unavailable');
      return;
    }

    final allLines = mrtDataMap['lines'] as List;
    final stationCodeSet = Set<String>.from(widget.stationCodes);

    final linesToProcess =
        allLines.where((line) => lineCodesToFetch.contains(line['code']));

    // Fetch relevant lines in parallel
    final futures = linesToProcess.map((line) async {
      final lineCode = line['code'] as String;
      final lineName = line['name'] as String? ?? lineCode;
      final lineColorStr = line['lineColor'] as String? ?? '#888888';

      try {
        final uri = Uri.parse('$serverURL/api/mrt/liveCrowdData/$lineCode');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) return;

        final json = jsonDecode(response.body);
        final values = json['value'] as List? ?? [];

        final now = DateTime.now();
        final Map<String, dynamic> parsedLineData = {};

        for (final entry in values) {
          final stationCode = entry['Station'] as String;
          final entryData = {
            'crowdLevel': entry['CrowdLevel'] as String? ?? 'na',
            'lineName': lineName,
            'lineColor': lineColorStr,
            'startTime': entry['StartTime'] as String?,
            'endTime': entry['EndTime'] as String?,
          };

          parsedLineData[stationCode] = entryData;

          if (stationCodeSet.contains(stationCode)) {
            // Found a match — record it
            if (mounted) {
              setState(() {
                _crowdData[stationCode] = entryData;
              });
            }
          }
        }

        _lineCache[lineCode] = {
          'data': parsedLineData,
          'fetchedAt': now,
        };
      } catch (_) {
        // Silently ignore per-line errors
      }
    }).toList();

    await Future.wait(futures);

    if (mounted) {
      DateTime? oldest;
      for (final code in widget.stationCodes) {
        final lineCode = _getLineCodeForStation(code, allLines);
        if (lineCode != null) {
          final fetchedAt = _lineCache[lineCode]?['fetchedAt'] as DateTime?;
          if (fetchedAt != null) {
            if (oldest == null || fetchedAt.isBefore(oldest)) {
              oldest = fetchedAt;
            }
          }
        }
      }

      setState(() {
        for (final entry in _crowdData.values) {
          if (entry['crowdLevel'] == null) {
            entry['crowdLevel'] = 'na';
          }
        }
        _isFetching = false;
        _lastUpdated = oldest ?? DateTime.now();
      });
    }
  }

  Color? _crowdColor(String level) {
    switch (level.toLowerCase()) {
      case 'l':
        return Colors.green[200];
      case 'm':
        return Colors.amber[200];
      case 'h':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.grey;
    }
  }

  String _crowdLabel(String level) {
    switch (level.toLowerCase()) {
      case 'l':
        return 'Low';
      case 'm':
        return 'Moderate';
      case 'h':
        return 'High';
      default:
        return 'No data';
    }
  }

  IconData _crowdIcon(String level) {
    switch (level.toLowerCase()) {
      case 'l':
        return Icons.people_outline;
      case 'm':
        return Icons.people;
      case 'h':
        return Icons.groups;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    final resolved = _crowdData.values.where((d) => d['startTime'] != null);
    final Map<String, dynamic>? firstResolved =
        resolved.isNotEmpty ? resolved.first : null;

    final entries = _crowdData.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time window header — appears once the first entry resolves

        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Skeletonizer(
                enabled: firstResolved == null && _isFetching,
                child: Text(
                  (firstResolved != null)
                      ? _formatTimeWindow(
                          firstResolved['startTime'] as String,
                          firstResolved['endTime'] as String?,
                        )
                      : (_isFetching ? "2130 - 2140" : "Data unavailable"),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // One ListTile per station code — visible immediately, pill skeleton until loaded
        for (var i = 0; i < entries.length; i++)
          () {
            final code = entries[i].key;
            final data = entries[i].value;
            final isLoaded = data['crowdLevel'] != null;
            // Use 'l' as fallback so the skeleton pill has a plausible shape
            final level = isLoaded ? data['crowdLevel'] as String : 'l';
            final crowdColor = _crowdColor(level)!;
            Color lineColor;
            try {
              lineColor = Color(int.parse(
                  (data['lineColor'] as String? ?? '#607D8B')
                      .replaceFirst('#', 'FF'),
                  radix: 16));
            } catch (_) {
              lineColor = Colors.blueGrey;
            }

            final isFirst = i == 0;
            final isLast = i == entries.length - 1;
            const bigR = Radius.circular(28.0);
            const smallR = Radius.circular(5.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? bigR : smallR,
                  topRight: isFirst ? bigR : smallR,
                  bottomLeft: isLast ? bigR : smallR,
                  bottomRight: isLast ? bigR : smallR,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: ListTile(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: lineColor,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontVariations: [
                            FontVariation.weight(750),
                            FontVariation.width(100),
                            FontVariation('ROND', 100),
                          ],
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Skeletonizer(
                  enabled: !isLoaded,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: crowdColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_crowdIcon(level), color: Colors.black, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          _crowdLabel(level),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),

        // Refresh Button Area
        if (!_isFetching && _lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Last updated: ${_lastUpdated!.toLocal().hour.toString().padLeft(2, '0')}:${_lastUpdated!.toLocal().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _initData(forceRefresh: true);
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Refresh crowd data',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTimeWindow(String start, String? end) {
    try {
      final startDt = DateTime.parse(start);
      final endDt = end != null ? DateTime.parse(end) : null;
      String fmt(DateTime dt) =>
          '${dt.toLocal().hour.toString().padLeft(2, '0')}:${dt.toLocal().minute.toString().padLeft(2, '0')}';
      if (endDt != null) {
        return '${fmt(startDt)} – ${fmt(endDt)}';
      }
      return fmt(startDt);
    } catch (_) {
      return start;
    }
  }
}

// ---------- Nearby Stops Card ----------

class NearbyStopsCard extends StatefulWidget {
  final double stationLat;
  final double stationLng;

  /// Radius in metres within which to look for stops.
  final double radiusMetres;

  const NearbyStopsCard({
    super.key,
    required this.stationLat,
    required this.stationLng,
    this.radiusMetres = 350,
  });

  @override
  State<NearbyStopsCard> createState() => _NearbyStopsCardState();
}

class _NearbyStopsCardState extends State<NearbyStopsCard> {
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _computeNearbyStops();
  }

  void _computeNearbyStops() {
    final allStops = getStops() as List?;
    if (allStops == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final List<Map<String, dynamic>> nearby = [];

    for (final stop in allStops) {
      final coords = stop['cords'] as List?;
      if (coords == null || coords.length < 2) continue;
      final double stopLng = (coords[0] as num).toDouble();
      final double stopLat = (coords[1] as num).toDouble();

      final double dist = Geolocator.distanceBetween(
        widget.stationLat,
        widget.stationLng,
        stopLat,
        stopLng,
      );

      if (dist <= widget.radiusMetres) {
        nearby.add({
          'name': stop['Name'] as String? ?? '',
          'id': stop['id']?.toString() ?? '',
          'dist': dist.round(),
        });
      }
    }

    nearby.sort((a, b) => (a['dist'] as int).compareTo(b['dist'] as int));

    if (mounted) {
      setState(() {
        _stops = nearby;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.directions_bus_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'No bus stops within ${widget.radiusMetres.round()}m of this station.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _stops.length; i++)
          () {
            final stop = _stops[i];
            final isFirst = i == 0;
            final isLast = i == _stops.length - 1;
            const bigR = Radius.circular(28.0);
            const smallR = Radius.circular(5.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? bigR : smallR,
                  topRight: isFirst ? bigR : smallR,
                  bottomLeft: isLast ? bigR : smallR,
                  bottomRight: isLast ? bigR : smallR,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: ListTile(
                title: Text(stop['name'] as String),
                subtitle: Text(stop['id'] as String),
                trailing: Text('${stop['dist']}m'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Stop(stop['id'] as String),
                    ),
                  );
                },
              ),
            );
          }(),
      ],
    );
  }
}

// ---------- Exits Card ----------

class ExitsCard extends StatefulWidget {
  final List<Map<String, dynamic>> exits;
  final bool? exitDataApproximate;
  const ExitsCard(
      {super.key, required this.exits, this.exitDataApproximate});

  @override
  State<ExitsCard> createState() => _ExitsCardState();
}

class _ExitsCardState extends State<ExitsCard> {
  // Tracks which exit indices are expanded
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    if (widget.exits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.place_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'No exit data available for this station.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.exitDataApproximate != null)
          Container(
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28.0),
            ),
            child: ListTile(
              leading: Icon(Icons.warning_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                "Unreliable exit data",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  // color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: Text(
                  "Exit data for this station is from LTA is unreliable. Exit locations have been approximated."),
            ),
          ),
        for (var i = 0; i < widget.exits.length; i++)
          () {
            final exit = widget.exits[i];
            final exitName = exit['exitName'] as String? ?? '?';
            final landmarks = (exit['landmarks'] as List? ?? [])
                .map((l) => l.toString())
                .toList();
            final isFirst = i == 0;
            final isLast = i == widget.exits.length - 1;
            final isOpen = _expanded.contains(i);
            const bigR = Radius.circular(28.0);
            const smallR = Radius.circular(5.0);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? bigR : smallR,
                  topRight: isFirst ? bigR : smallR,
                  bottomLeft: isLast && !isOpen ? bigR : smallR,
                  bottomRight: isLast && !isOpen ? bigR : smallR,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: Column(
                children: [
                  // ── Header tile ──────────────────────────────────────────
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: isFirst ? bigR : smallR,
                        topRight: isFirst ? bigR : smallR,
                        bottomLeft:
                            isOpen ? Radius.zero : (isLast ? bigR : smallR),
                        bottomRight:
                            isOpen ? Radius.zero : (isLast ? bigR : smallR),
                      ),
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        exitName
                            .replaceAll("Exit ", "")
                            .replaceAll("Terminal ", "T"),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      '$exitName',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: landmarks.isEmpty
                        ? null
                        : Text(
                            '${landmarks.length} landmark${landmarks.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                    trailing: AnimatedRotation(
                      turns: isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        if (isOpen) {
                          _expanded.remove(i);
                        } else {
                          _expanded.add(i);
                        }
                      });
                    },
                  ),

                  // ── Expanded landmarks list (animated) ───────────────────
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: isOpen
                          ? AnimatedOpacity(
                              opacity: isOpen ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                ),
                                child: landmarks.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        child: Text(
                                          'No landmarks listed for this exit.',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 13),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (var j = 0;
                                              j < landmarks.length;
                                              j++)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                top: j == 0 ? 8 : 0,
                                                bottom:
                                                    j == landmarks.length - 1
                                                        ? 12
                                                        : 0,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 7, right: 10),
                                                    child: Icon(
                                                      Icons.place,
                                                      size: 15,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 6),
                                                      child: Text(
                                                        landmarks[j],
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontVariations: [
                                                            FontVariation(
                                                                'ROND', 100),
                                                            FontVariation
                                                                .weight(550)
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

// ---------- Train Timings Card ----------

class TrainTimingsCard extends StatelessWidget {
  final List<Map<String, dynamic>> timingsData;
  const TrainTimingsCard({super.key, required this.timingsData});

  @override
  Widget build(BuildContext context) {
    if (timingsData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.schedule_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'No train timing data available for this station.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < timingsData.length; i++)
          () {
            final data = timingsData[i];
            final towards = data['towards'] as String? ?? 'Unknown Destination';
            final firstTrainList = data['firstTrain'] as List? ?? [];
            final lastTrainList = data['lastTrain'] as List? ?? [];

            // Group by day to handle multiple entries per day
            final Map<String, List<String>> groupedFirst = {};
            final Map<String, List<String>> groupedLast = {};
            final List<String> daysOrder = [];

            for (var entry in firstTrainList) {
              final day = entry['day'] as String? ?? '';
              final time = entry['time'] as String? ?? '-';
              if (!daysOrder.contains(day)) daysOrder.add(day);
              groupedFirst.putIfAbsent(day, () => []).add(time);
            }

            for (var entry in lastTrainList) {
              final day = entry['day'] as String? ?? '';
              final time = entry['time'] as String? ?? '-';
              if (!daysOrder.contains(day)) daysOrder.add(day);
              groupedLast.putIfAbsent(day, () => []).add(time);
            }

            return Container(
              margin:
                  EdgeInsets.only(bottom: i == timingsData.length - 1 ? 0 : 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_transit,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Towards $towards',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 50,
                      dataRowMaxHeight: double.infinity,
                      columns: const [
                        DataColumn(
                            label: Text('Day',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('First Train',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Last Train',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: daysOrder.map((day) {
                        final firstTimes = groupedFirst[day] ?? ['-'];
                        final lastTimes = groupedLast[day] ?? ['-'];

                        return DataRow(
                          cells: [
                            DataCell(Text(day,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      firstTimes.map((t) => Text(t)).toList(),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      lastTimes.map((t) => Text(t)).toList(),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}
