import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/components/bus_timing_est.dart';
import 'package:sgbus/scripts/data_management/data.dart';

class BusTiming extends StatefulWidget {
  final dynamic data;
  final List<dynamic>? stopCoords;
  final String? stopCode;
  final String? stopName;
  const BusTiming(this.data,
      {Key? key, this.stopCoords, this.stopCode, this.stopName})
      : super(key: key);

  @override
  _BusTimingState createState() => _BusTimingState();
}

class _BusTimingState extends State<BusTiming> {
  bool _isExpanded = false;
  static final Map<String, List<dynamic>> _firstLastTimingsCache = {};

  String _getStopName(String stopCode, String? stopName) {
    if (stopName != null && stopName.isNotEmpty) return stopName;
    if (stopCode.isEmpty) return '';
    try {
      final List stops = getStops();
      for (var s in stops) {
        if (s['id']?.toString().toLowerCase() == stopCode.toLowerCase()) {
          final String sName = s['Name']?.toString() ?? '';
          if (sName.isNotEmpty) return sName;
        }
      }
    } catch (_) {}
    return stopCode;
  }

  Future<List<dynamic>> _getfirstLastTimings(String stopCode) async {
    if (_firstLastTimingsCache.containsKey(stopCode)) {
      return _firstLastTimingsCache[stopCode]!;
    }
    final url = Uri.parse('$serverURL/api/v2/data/firstLastTimings/$stopCode');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _firstLastTimingsCache[stopCode] = data;
      return data;
    } else {
      throw Exception('Failed to load timings');
    }
  }

  String _formatTiming(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty || rawTime == '-') return '-';
    final clean = rawTime.trim();
    if (clean.length == 4 && RegExp(r'^\d{4}$').hasMatch(clean)) {
      return '${clean.substring(0, 2)}:${clean.substring(2)}';
    }
    return clean;
  }

  void _showFirstLastBusBottomSheet(BuildContext context) {
    final serviceNo = widget.data['ServiceNo']?.toString() ?? '';
    final stopCode = widget.stopCode ?? '';
    final displayStopName = _getStopName(stopCode, widget.stopName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            serviceNo,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontVariations: const [
                                FontVariation('ROND', 100),
                                FontVariation.width(120),
                                FontVariation.weight(900),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First & Last Bus Timings',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontVariations: [
                                    FontVariation('ROND', 100),
                                    FontVariation.width(110),
                                    FontVariation.weight(900)
                                  ],
                                ),
                              ),
                              if (displayStopName.isNotEmpty)
                                Text(
                                  "at " + displayStopName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontVariations: [
                                      FontVariation('ROND', 100),
                                      FontVariation.width(110),
                                      FontVariation.weight(700)
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<dynamic>>(
                      future: _getfirstLastTimings(stopCode),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: ExpressiveLoadingIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Unable to load bus timings',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final allData = snapshot.data!;
                        final matches = allData.where((item) {
                          final sNo = item['serviceNo']?.toString();
                          return sNo != null &&
                              sNo.toLowerCase() == serviceNo.toLowerCase();
                        }).toList();

                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 40,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.6),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No timing information available for Service $serviceNo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: matches.map((match) {
                            final dir = match['direction'];
                            final String? dirLabel =
                                (matches.length > 1 && dir != null)
                                    ? 'Direction $dir'
                                    : null;

                            final wd = match['WD'] as Map<String, dynamic>?;
                            final sat = match['SAT'] as Map<String, dynamic>?;
                            final sun =
                                match['SUN / PH'] as Map<String, dynamic>?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (dirLabel != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(
                                        dirLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.2),
                                      1: FlexColumnWidth(1.0),
                                      2: FlexColumnWidth(1.0),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withOpacity(0.2),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        children: [
                                          _buildTableCell(context, 'Day',
                                              isHeader: true),
                                          _buildTableCell(context, 'First Bus',
                                              isHeader: true,
                                              icon: Icons.wb_sunny_outlined),
                                          _buildTableCell(context, 'Last Bus',
                                              isHeader: true,
                                              icon: Icons.bedtime_outlined),
                                        ],
                                      ),
                                      _buildTableRow(
                                          context,
                                          'Weekdays',
                                          _formatTiming(wd?['First']),
                                          _formatTiming(wd?['Last'])),
                                      _buildTableRow(
                                          context,
                                          'Saturdays',
                                          _formatTiming(sat?['First']),
                                          _formatTiming(sat?['Last'])),
                                      _buildTableRow(
                                          context,
                                          'Sun / PH',
                                          _formatTiming(sun?['First']),
                                          _formatTiming(sun?['Last']),
                                          isLast: true),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableCell(BuildContext context, String text,
      {bool isHeader = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: isHeader && icon != null
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isHeader
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            textAlign: isHeader ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: isHeader ? 12 : 14,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
              color: isHeader
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontVariations: const [
                FontVariation('ROND', 100),
                FontVariation.weight(600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(
      BuildContext context, String day, String first, String last,
      {bool isLast = false}) {
    return TableRow(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.2),
                ),
              ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            day,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            first,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.weight(700),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            last,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.weight(700),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                child: Row(
                  children: [
                    SizedBox(
                      width: width * 0.2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.data['ServiceNo'] ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontVariations: const [
                                  FontVariation('ROND', 100),
                                  FontVariation.width(110),
                                  FontVariation.weight(900)
                                ],
                                fontSize: 27,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.data["to"] != null)
                            Text(
                              widget.data["to"] ?? "",
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            )
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(children: [
                      BusTimingEst(
                        data: widget.data['NextBus'],
                        isCM: widget.data != null &&
                            (widget.data['CM'] == true ||
                                widget.data['CM'] == 'true'),
                      ),
                      BusTimingEst(
                        data: widget.data['NextBus2'],
                        isCM: widget.data != null &&
                            (widget.data['CM'] == true ||
                                widget.data['CM'] == 'true'),
                      ),
                      BusTimingEst(
                        data: widget.data['NextBus3'],
                        isCM: widget.data != null &&
                            (widget.data['CM'] == true ||
                                widget.data['CM'] == 'true'),
                      ),
                    ]),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: BusLocationsMap(
                              serviceNo: widget.data['ServiceNo'] ?? '',
                              nextBus1: widget.data['NextBus'],
                              nextBus2: widget.data['NextBus2'],
                              nextBus3: widget.data['NextBus3'],
                              stopCoords: widget.stopCoords,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.stopCode != null &&
                            widget.stopCode!.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BusRoute(widget.data['ServiceNo']),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.route_rounded),
                                  label: const Text(
                                    'Route',
                                    style: TextStyle(
                                      fontVariations: [
                                        FontVariation('ROND', 100),
                                        FontVariation.width(110),
                                        FontVariation.weight(700),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _showFirstLastBusBottomSheet(context);
                                  },
                                  icon: const Icon(Icons.schedule_rounded),
                                  label: const Text(
                                    'First/Last',
                                    style: TextStyle(
                                      fontVariations: [
                                        FontVariation('ROND', 100),
                                        FontVariation.width(110),
                                        FontVariation.weight(700),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BusRoute(widget.data['ServiceNo']),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.directions_bus_rounded),
                              label: const Text(
                                'View Bus Route',
                                style: TextStyle(
                                  fontVariations: [
                                    FontVariation('ROND', 100),
                                    FontVariation.width(110),
                                    FontVariation.weight(700),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class BusLocationsMap extends StatefulWidget {
  final String serviceNo;
  final dynamic nextBus1;
  final dynamic nextBus2;
  final dynamic nextBus3;
  final List<dynamic>? stopCoords;

  const BusLocationsMap({
    Key? key,
    required this.serviceNo,
    this.nextBus1,
    this.nextBus2,
    this.nextBus3,
    this.stopCoords,
  }) : super(key: key);

  @override
  State<BusLocationsMap> createState() => _BusLocationsMapState();
}

class _BusLocationsMapState extends State<BusLocationsMap> {
  MapboxMap? mapboxMap;

  BusMarkerData? _parseBus(dynamic busData, String label) {
    if (busData == null) return null;
    final latVal = busData['Latitude'];
    final lngVal = busData['Longitude'];
    if (latVal == null || lngVal == null) return null;

    double? lat;
    double? lng;

    if (latVal is num) {
      lat = latVal.toDouble();
    } else {
      lat = double.tryParse(latVal.toString());
    }

    if (lngVal is num) {
      lng = lngVal.toDouble();
    } else {
      lng = double.tryParse(lngVal.toString());
    }

    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return null;
    return BusMarkerData(
      lat: lat,
      lng: lng,
      label: label,
      type: busData['Type']?.toString(),
      load: busData['Load']?.toString(),
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    mapboxMap = map;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (mapboxMap == null || !mounted) return;

    // Apply theme config first
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      await mapboxMap!.style.setStyleImportConfigProperties('basemap', {
        'lightPreset': isDark ? 'dusk' : 'day',
      });
    } catch (e) {
      print('Error applying style import config properties: $e');
    }

    // setStyleImportConfigProperties triggers an async internal style refresh
    // that can wipe programmatically added layers. Wait for it to settle.
    await Future.delayed(const Duration(milliseconds: 500));
    if (mapboxMap == null || !mounted) return;

    await _addBusLayers();
  }

  Future<void> _addBusLayers() async {
    if (mapboxMap == null || !mounted) return;

    final buses = [
      _parseBus(widget.nextBus1, '1'),
      _parseBus(widget.nextBus2, '2'),
      _parseBus(widget.nextBus3, '3'),
    ].whereType<BusMarkerData>().toList();

    final features = <Map<String, dynamic>>[];
    final allPoints = <List<double>>[];

    // Bus stop feature
    if (widget.stopCoords != null && widget.stopCoords!.length == 2) {
      final stopLng = (widget.stopCoords![0] as num).toDouble();
      final stopLat = (widget.stopCoords![1] as num).toDouble();
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [stopLng, stopLat],
        },
        'properties': {
          'isStop': true,
          'label': 'Stop',
        },
      });
      allPoints.add([stopLng, stopLat]);
    }

    // Buses features
    for (final bus in buses) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [bus.lng, bus.lat],
        },
        'properties': {
          'isStop': false,
          'label': bus.label,
          'load': bus.load ?? '',
        },
      });
      allPoints.add([bus.lng, bus.lat]);
    }

    final geoJsonData = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    final srcId = 'bus_loc_src_${widget.serviceNo}';
    final busesCircleId = 'buses_circle_${widget.serviceNo}';
    final busesSymbolId = 'buses_symbol_${widget.serviceNo}';
    final stopCircleId = 'stop_circle_${widget.serviceNo}';

    // Clean up any existing layers/sources
    try {
      if (await mapboxMap!.style.styleSourceExists(srcId)) {
        try {
          await mapboxMap!.style.removeStyleLayer(busesSymbolId);
        } catch (_) {}
        try {
          await mapboxMap!.style.removeStyleLayer(busesCircleId);
        } catch (_) {}
        try {
          await mapboxMap!.style.removeStyleLayer(stopCircleId);
        } catch (_) {}
        try {
          await mapboxMap!.style.removeStyleSource(srcId);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await mapboxMap!.style
          .addSource(GeoJsonSource(id: srcId, data: geoJsonData));

      // Circle layer for buses
      await mapboxMap!.style.addLayer(CircleLayer(
        id: busesCircleId,
        sourceId: srcId,
        filter: [
          '!=',
          ['get', 'isStop'],
          true
        ],
        slot: LayerSlot.TOP,
        circleRadius: 12.0,
        circleColor: Colors.blueAccent.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeColor: Colors.white.toARGB32(),
        circleEmissiveStrength: 1.0,
      ));

      // Symbol layer for bus labels (1, 2, 3)
      await mapboxMap!.style.addStyleLayer(
        jsonEncode({
          'id': busesSymbolId,
          'type': 'symbol',
          'source': srcId,
          'filter': [
            '!=',
            ['get', 'isStop'],
            true
          ],
          'slot': 'top',
        }),
        null,
      );
      await mapboxMap!.style.setStyleLayerProperties(
        busesSymbolId,
        jsonEncode({
          'text-field': ['get', 'label'],
          'text-size': 12,
          'text-color': '#ffffff',
        }),
      );

      // Circle layer for Stop
      if (widget.stopCoords != null && widget.stopCoords!.length == 2) {
        await mapboxMap!.style.addLayer(CircleLayer(
          id: stopCircleId,
          sourceId: srcId,
          filter: [
            '==',
            ['get', 'isStop'],
            true
          ],
          slot: LayerSlot.TOP,
          circleRadius: 8.0,
          circleColor: Colors.redAccent.toARGB32(),
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleEmissiveStrength: 1.0,
        ));
      }
    } catch (e) {
      print('Error adding bus locations map layers: $e');
    }

    _fitBounds(allPoints);
  }

  void _fitBounds(List<List<double>> points) async {
    if (mapboxMap == null || points.isEmpty || !mounted) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (final pt in points) {
      final lng = pt[0];
      final lat = pt[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom;
    if (maxSpan <= 0) {
      zoom = 14.0;
    } else if (maxSpan < 0.005) {
      zoom = 13.5;
    } else if (maxSpan < 0.01) {
      zoom = 12.8;
    } else if (maxSpan < 0.02) {
      zoom = 12.0;
    } else if (maxSpan < 0.04) {
      zoom = 11.2;
    } else if (maxSpan < 0.08) {
      zoom = 10.5;
    } else if (maxSpan < 0.15) {
      zoom = 9.5;
    } else if (maxSpan < 0.3) {
      zoom = 8.5;
    } else {
      zoom = 7.5;
    }

    // Animate to the computed bounds
    try {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      print('Error flying camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final buses = [
      _parseBus(widget.nextBus1, '1'),
      _parseBus(widget.nextBus2, '2'),
      _parseBus(widget.nextBus3, '3'),
    ].whereType<BusMarkerData>().toList();

    // Default to stop location or Singapore center
    double defaultLat = 1.3521;
    double defaultLng = 103.8198;
    double defaultZoom = 11.0;

    if (widget.stopCoords != null && widget.stopCoords!.length == 2) {
      defaultLng = (widget.stopCoords![0] as num).toDouble();
      defaultLat = (widget.stopCoords![1] as num).toDouble();
    }

    return Stack(
      children: [
        MapWidget(
          key: ValueKey('bus_map_${widget.serviceNo}'),
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(defaultLng, defaultLat)),
            zoom: defaultZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          styleUri: MapboxStyles.STANDARD,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer()),
          },
        ),
        if (buses.isEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No live location for buses',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BusMarkerData {
  final double lat;
  final double lng;
  final String label;
  final String? type;
  final String? load;

  BusMarkerData({
    required this.lat,
    required this.lng,
    required this.label,
    this.type,
    this.load,
  });
}
