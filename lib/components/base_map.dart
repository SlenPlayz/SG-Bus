import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaseMap extends StatefulWidget {
  final CameraOptions? cameraOptions;
  final void Function(MapboxMap mapboxMap)? onMapCreated;
  final void Function(MapboxMap mapboxMap)? onStyleLoaded;
  final void Function(MapContentGestureContext gestureContext)? onMapTap;
  final double fabBottomPadding;
  final Widget? overlay;
  final bool showScaleBar;
  final bool showCompass;
  final double? topPadding;

  // Controls whether the standard Singapore-wide bus stops are automatically
  // loaded and displayed on the map.
  final bool loadDefaultBusStops;

  // Controls which layer toggles appear in the "Layers" section.
  // All layers are always loaded; these flags only affect the UI toggles.
  final bool showBusStopsToggle;
  final bool showTrainLinesToggle;
  final bool showStationExitsToggle;
  final bool showStationBoundariesToggle;

  const BaseMap({
    Key? key,
    this.cameraOptions,
    this.onMapCreated,
    this.onStyleLoaded,
    this.onMapTap,
    this.fabBottomPadding = 16.0,
    this.overlay,
    required this.showScaleBar,
    required this.showCompass,
    this.topPadding,
    this.loadDefaultBusStops = true,
    this.showBusStopsToggle = true,
    this.showTrainLinesToggle = true,
    this.showStationExitsToggle = true,
    this.showStationBoundariesToggle = true,
  }) : super(key: key);

  @override
  _BaseMapState createState() => _BaseMapState();
}

class _BaseMapState extends State<BaseMap> {
  MapboxMap? mapboxMap;
  gl.Position? currLocation;
  bool _isSatelliteView = false;
  bool _isPreferencesLoaded = false;
  String? _currentStyleUri;
  bool locationError = false;

  // Layer visibility state — owned entirely by BaseMap
  bool _showBusStops = true;
  bool _showTrainLines = true;
  bool _showStationExits = true;
  bool _showStationBoundaries = true;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSatelliteView = prefs.getBool('isSatelliteView') ?? false;
        _isPreferencesLoaded = true;
      });
    }
  }

  // ── Standard layer init ────────────────────────────────────────────────────

  Future<void> _initStops() async {
    final stopsData = getStops();
    if (stopsData == null) return;
    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

    final geoJson = await compute(_generateStopsGeoJson, stopsData);

    await mapboxMap?.style.addSource(GeoJsonSource(id: 'stops', data: geoJson));

    await mapboxMap?.style.addStyleLayer(
      json.encode({'id': 'stops_layer', 'type': 'symbol', 'source': 'stops'}),
      null,
    );
    await mapboxMap?.style.setStyleLayerProperties(
      'stops_layer',
      json.encode({
        'text-field': ['get', 'name'],
        'icon-image': 'bus',
        'text-size': 10,
        'text-offset': [0, 2],
        'text-color': (isSat || isDark) ? '#fff' : '#000',
      }),
    );
    await mapboxMap?.style.addLayer(CircleLayer(
      id: 'stops_circle_layer',
      sourceId: 'stops',
      circleRadius: 1,
      maxZoom: 19.0,
      circleColor: Colors.blue.toARGB32(),
    ));
  }

  Future<void> _initMrt() async {
    final mrtData = getMRTData();
    if (mrtData == null) return;
    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

    final geoJson = await compute(_generateMrtGeoJson, mrtData);

    await mapboxMap?.style
        .addSource(GeoJsonSource(id: 'mrt_source', data: geoJson));

    final belowStops =
        widget.loadDefaultBusStops ? LayerPosition(below: 'stops_layer') : null;

    // Boundaries fill
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_boundary_layer',
        'type': 'fill',
        'source': 'mrt_source',
        'minzoom': 14.0,
        'filter': ['==', 'type', 'boundary'],
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': 0.18
        },
      }),
      belowStops,
    );

    // Boundaries line
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_boundary_line_layer',
        'type': 'line',
        'source': 'mrt_source',
        'minzoom': 14.0,
        'filter': ['==', 'type', 'boundary'],
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 3.0
        },
      }),
      belowStops,
    );

    // Train lines
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_line_layer',
        'type': 'line',
        'source': 'mrt_source',
        'filter': ['==', 'type', 'line'],
        'paint': {
          'line-color': ['get', 'lineColor'],
          'line-width': 4.0
        },
      }),
      belowStops,
    );

    // Station circles
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_station_circle_layer',
        'type': 'circle',
        'source': 'mrt_source',
        'minzoom': 10.5,
        'filter': ['==', 'type', 'station'],
        'paint': {
          'circle-radius': 5.0,
          'circle-color': '#ffffff',
          'circle-stroke-width': 2.0,
          'circle-stroke-color': '#000000',
        },
      }),
      null,
    );

    // Station labels
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_station_text_layer',
        'type': 'symbol',
        'source': 'mrt_source',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'station'],
        'layout': {
          'text-field': ['get', 'name'],
          'text-size': 12,
          'text-offset': [0, 1.5]
        },
        'paint': {
          'text-color': (isSat || isDark) ? '#ffffff' : '#000000',
          'text-halo-color': (isSat || isDark) ? '#000000' : '#ffffff',
          'text-halo-width': 1.0,
        },
      }),
      null,
    );

    // Exit circles
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_exit_circle_layer',
        'type': 'circle',
        'source': 'mrt_source',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'exit'],
        'paint': {
          'circle-radius': 3.0,
          'circle-color': '#ffeb3b',
          'circle-stroke-width': 1.0,
          'circle-stroke-color': '#000000',
        },
      }),
      null,
    );

    // Exit labels
    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'mrt_exit_text_layer',
        'type': 'symbol',
        'source': 'mrt_source',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'exit'],
        'layout': {
          'text-field': ['get', 'name'],
          'text-size': 10,
          'text-offset': [0, 1.2]
        },
        'paint': {'text-color': (isSat || isDark) ? '#ffffff' : '#000000'},
      }),
      null,
    );
  }

  // ── Visibility helpers ─────────────────────────────────────────────────────

  Future<void> _setLayerVisibility(String layerId, bool visible) async {
    try {
      final style = mapboxMap?.style;
      if (style != null && await style.styleLayerExists(layerId)) {
        await style.setStyleLayerProperty(
          layerId,
          'visibility',
          visible ? 'visible' : 'none',
        );
        mapboxMap?.triggerRepaint();
      }
    } catch (e) {
      print('Error setting visibility for $layerId: $e');
    }
  }

  Future<void> _updateBaseMapData() async {
    final style = mapboxMap?.style;
    if (style == null) return;

    if (widget.loadDefaultBusStops) {
      final stopsData = getStops();
      if (stopsData != null) {
        final geoJson = await compute(_generateStopsGeoJson, stopsData);
        if (await style.styleSourceExists('stops')) {
          await style.setStyleSourceProperty('stops', 'data', geoJson);
        } else {
          await _initStops();
        }
      }
    }

    final mrtData = getMRTData();
    if (mrtData != null) {
      final geoJson = await compute(_generateMrtGeoJson, mrtData);
      if (await style.styleSourceExists('mrt_source')) {
        await style.setStyleSourceProperty('mrt_source', 'data', geoJson);
      } else {
        await _initMrt();
      }
    }
  }

  void _toggleBusStops(bool v) {
    setState(() => _showBusStops = v);
    _setLayerVisibility('stops_layer', v);
    _setLayerVisibility('stops_circle_layer', v);
    _updateBaseMapData();
  }

  void _toggleTrainLines(bool v) {
    setState(() => _showTrainLines = v);
    _setLayerVisibility('mrt_line_layer', v);
    _setLayerVisibility('mrt_station_circle_layer', v);
    _setLayerVisibility('mrt_station_text_layer', v);
    _updateBaseMapData();
  }

  void _toggleStationExits(bool v) {
    setState(() => _showStationExits = v);
    _setLayerVisibility('mrt_exit_circle_layer', v);
    _setLayerVisibility('mrt_exit_text_layer', v);
    _updateBaseMapData();
  }

  void _toggleStationBoundaries(bool v) {
    setState(() => _showStationBoundaries = v);
    _setLayerVisibility('mrt_boundary_layer', v);
    _setLayerVisibility('mrt_boundary_line_layer', v);
    _updateBaseMapData();
  }

  // ── Map lifecycle ──────────────────────────────────────────────────────────

  void _onMapCreated(MapboxMap map) {
    mapboxMap = map;
    map.location.updateSettings(
        LocationComponentSettings(enabled: true, puckBearingEnabled: true));
    if (widget.showCompass) {
      map.compass.updateSettings(CompassSettings(
          enabled: true, marginTop: widget.topPadding ?? 0, marginRight: 10));
    } else {
      map.compass.updateSettings(CompassSettings(enabled: false));
    }
    if (widget.showScaleBar) {
      map.scaleBar.updateSettings(ScaleBarSettings(
          enabled: true,
          marginTop: widget.topPadding ?? 0,
          marginLeft: 20,
          isMetricUnits: true));
    } else {
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    }

    _currentStyleUri = (_isSatelliteView || isDark)
        ? 'mapbox://styles/slen/cl4p0y50c000a15qhcozehloa'
        : 'mapbox://styles/slen/clb64djkx000014pcw46b1h9m';

    if (widget.onMapCreated != null) widget.onMapCreated!(map);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (mapboxMap == null) return;

    // Always initialise standard layers first
    if (widget.loadDefaultBusStops) {
      await _initStops();
    }
    await _initMrt();

    // Then let the page add its own layers
    if (widget.onStyleLoaded != null) widget.onStyleLoaded!(mapboxMap!);

    if (_isSatelliteView) await _toggleSatelliteMode(true);

    if (widget.onMapTap != null) {
      mapboxMap!.setOnMapTapListener(widget.onMapTap!);
    }
  }

  Future<void> _toggleSatelliteMode(bool enableSatellite) async {
    if (mapboxMap == null) return;
    setState(() => _isSatelliteView = enableSatellite);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSatelliteView', enableSatellite);
    } catch (e) {
      print('Error saving map mode preference: $e');
    }

    final targetStyleUri = (enableSatellite || isDark)
        ? 'mapbox://styles/slen/cl4p0y50c000a15qhcozehloa'
        : 'mapbox://styles/slen/clb64djkx000014pcw46b1h9m';

    if (_currentStyleUri != targetStyleUri) {
      _currentStyleUri = targetStyleUri;
      await mapboxMap!.loadStyleURI(targetStyleUri);
      return;
    }

    try {
      final style = mapboxMap!.style;
      if (enableSatellite) {
        final sourceExists = await style.styleSourceExists('onemap-sat-source');
        if (!sourceExists) {
          await style.addSource(RasterSource(
            id: 'onemap-sat-source',
            tiles: [
              'https://www.onemap.gov.sg/maps/tiles/Satellite/{z}/{x}/{y}.png'
            ],
            tileSize: 128.0,
            bounds: [103.5, 1.1, 104.1, 1.5],
          ));
        }

        final layers = await style.getStyleLayers();
        final layerIds =
            layers.where((l) => l != null).map((l) => l!.id).toList();
        final layerExists = await style.styleLayerExists('onemap-sat-layer');
        if (!layerExists) {
          LayerPosition? position;
          if (layerIds.contains('background')) {
            position = LayerPosition(above: 'background');
          } else if (layerIds.isNotEmpty) {
            position = LayerPosition(below: layerIds.first);
          }
          if (position != null) {
            await style.addLayerAt(
                RasterLayer(
                    id: 'onemap-sat-layer',
                    sourceId: 'onemap-sat-source',
                    rasterContrast: 0.20),
                position);
          } else {
            await style.addLayer(RasterLayer(
                id: 'onemap-sat-layer', sourceId: 'onemap-sat-source'));
          }
        } else {
          await _setLayerVisibility('onemap-sat-layer', true);
        }

        for (var l in layers) {
          if (l != null && l.id != 'onemap-sat-layer') {
            if (l.type == 'background' ||
                l.type == 'fill' ||
                l.type == 'fill-extrusion' ||
                l.type == 'hillshade') {
              await _setLayerVisibility(l.id, false);
            }
          }
        }
      } else {
        await _setLayerVisibility('onemap-sat-layer', false);
        final layers = await style.getStyleLayers();
        for (var l in layers) {
          if (l != null && l.id != 'onemap-sat-layer') {
            if (l.type == 'background' ||
                l.type == 'fill' ||
                l.type == 'fill-extrusion' ||
                l.type == 'hillshade') {
              await _setLayerVisibility(l.id, true);
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error in _toggleSatelliteMode: $e');
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  // ── Bottom sheet ───────────────────────────────────────────────────────────

  void _showMapTypeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void toggle(void Function() updateState, void Function(bool) fn,
                bool value) {
              setModalState(updateState);
              fn(value);
            }

            final hasLayers =
                (widget.loadDefaultBusStops && widget.showBusStopsToggle) ||
                    widget.showTrainLinesToggle ||
                    widget.showStationExitsToggle ||
                    widget.showStationBoundariesToggle;

            TextStyle? titleStyle(BuildContext ctx) =>
                Theme.of(ctx).textTheme.titleLarge?.copyWith(fontVariations: [
                  FontVariation('ROND', 100),
                  FontVariation.width(120),
                  FontVariation.weight(1000),
                ]);

            TextStyle? subtitleStyle(BuildContext ctx) =>
                Theme.of(ctx).textTheme.labelMedium?.copyWith(fontVariations: [
                  FontVariation('ROND', 50),
                  FontVariation.width(105),
                  FontVariation.weight(500),
                ]);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Map View', style: titleStyle(context)),
                          Opacity(
                            opacity: 0.8,
                            child: Text('Changes how the map is rendered.',
                                style: subtitleStyle(context)),
                          ),
                        ],
                      ),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _isSatelliteView,
                      title: const Text('Regular View'),
                      subtitle: const Text(
                          'High contrast vector map. Quick & efficient.'),
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) {
                        if (v != null) {
                          Navigator.pop(context);
                          _toggleSatelliteMode(v);
                        }
                      },
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _isSatelliteView,
                      title: const Text('Satellite View'),
                      subtitle: const Text(
                          'HD Satellite imagery. Uses more data.\nSatellite imagery provided by SLA OneMap.'),
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) {
                        if (v != null) {
                          Navigator.pop(context);
                          _toggleSatelliteMode(v);
                        }
                      },
                    ),
                    if (hasLayers) ...[
                      const Divider(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Layers', style: titleStyle(context)),
                            Opacity(
                              opacity: 0.8,
                              child: Text('Toggle map data layers on or off.',
                                  style: subtitleStyle(context)),
                            ),
                          ],
                        ),
                      ),
                      if (widget.loadDefaultBusStops &&
                          widget.showBusStopsToggle)
                        SwitchListTile(
                          secondary: const Icon(Icons.directions_bus),
                          title: const Text('Bus Stops'),
                          value: _showBusStops,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => toggle(
                              () => _showBusStops = v, _toggleBusStops, v),
                        ),
                      if (widget.showTrainLinesToggle)
                        SwitchListTile(
                          secondary: const Icon(Icons.train),
                          title: const Text('Train Line Routes'),
                          value: _showTrainLines,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => toggle(
                              () => _showTrainLines = v, _toggleTrainLines, v),
                        ),
                      if (widget.showStationExitsToggle)
                        SwitchListTile(
                          secondary: const Icon(Icons.exit_to_app),
                          title: const Text('Station Exits'),
                          value: _showStationExits,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => toggle(() => _showStationExits = v,
                              _toggleStationExits, v),
                        ),
                      if (widget.showStationBoundariesToggle)
                        SwitchListTile(
                          secondary: const Icon(Icons.crop_square),
                          title: const Text('Station Boundaries'),
                          value: _showStationBoundaries,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => toggle(
                              () => _showStationBoundaries = v,
                              _toggleStationBoundaries,
                              v),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isPreferencesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MapWidget(
          cameraOptions: widget.cameraOptions ??
              CameraOptions(
                center: Point(
                  coordinates: currLocation != null
                      ? Position(
                          currLocation!.longitude, currLocation!.latitude)
                      : Position(103.8198, 1.290270),
                ),
                zoom: currLocation != null ? 17 : 9,
              ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          styleUri: (_isSatelliteView || isDark)
              ? 'mapbox://styles/slen/cl4p0y50c000a15qhcozehloa'
              : 'mapbox://styles/slen/clb64djkx000014pcw46b1h9m',
        ),
        Positioned(
          bottom: widget.fabBottomPadding,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'map_layer_toggle_${widget.hashCode}',
                onPressed: () => _showMapTypeBottomSheet(context),
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'my_location_${widget.hashCode}',
                onPressed: () async {
                  final res = await LocationHelper.getUserLocation(context);
                  if (!res.hasError && res.position != null) {
                    setState(() {
                      locationError = false;
                      currLocation = res.position;
                    });
                    mapboxMap?.flyTo(
                      CameraOptions(
                        zoom: 17,
                        center: Point(
                          coordinates: Position(
                              res.position!.longitude, res.position!.latitude),
                        ),
                      ),
                      MapAnimationOptions(duration: 2000, startDelay: 0),
                    );
                  } else {
                    setState(() => locationError = true);
                  }
                },
                child: (!locationError)
                    ? const Icon(Icons.my_location)
                    : const Icon(Icons.location_disabled_rounded),
              ),
            ],
          ),
        ),
        if (widget.overlay != null) widget.overlay!,
      ],
    );
  }
}

// ── Top-level compute functions ────────────────────────────────────────────────

String _generateStopsGeoJson(List data) {
  final List<Map<String, dynamic>> features = [];
  for (var stop in data) {
    if (stop["cords"] != null && stop["cords"].length == 2) {
      features.add({
        'type': 'Feature',
        'id': stop['id'],
        'properties': {
          'number': stop['id'],
          'name': stop['Name'],
          'road': stop['Road'],
        },
        'geometry': {'type': 'Point', 'coordinates': stop['cords']},
      });
    }
  }
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': features,
  });
}

String _generateMrtGeoJson(Map mrtData) {
  final List<Map<String, dynamic>> features = [];
  final lines = mrtData['lines'] as List? ?? [];

  String lineColor(List codes) {
    if (codes.isEmpty) return '#888888';
    // Loop through each line's stations list to find a matching station code,
    // then return that line's color.
    for (final stationCode in codes) {
      for (final l in lines) {
        final lineStations = l['stations'] as List? ?? [];
        for (final s in lineStations) {
          if (s is Map && s['code'] == stationCode) {
            return l['lineColor'] as String? ?? '#888888';
          }
        }
      }
    }
    return '#888888';
  }

  for (var line in lines) {
    if (line['polyline'] != null) {
      for (var encoded in line['polyline']) {
        final coords =
            decodePolyline(encoded as String).map((c) => [c[1], c[0]]).toList();
        features.add({
          'type': 'Feature',
          'properties': {
            'type': 'line',
            'lineColor': line['lineColor'] ?? '#000000',
            'name': line['name']
          },
          'geometry': {'type': 'LineString', 'coordinates': coords},
        });
      }
    }
  }

  for (var station in mrtData['stations'] ?? []) {
    features.add({
      'type': 'Feature',
      'properties': {
        'type': 'station',
        'name': station['name'],
        'code': station['codes']?.join('/')
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [station['longitude'], station['latitude']]
      },
    });

    if (station['boundaries'] != null) {
      final color = lineColor(station['codes'] ?? []);
      for (var encoded in station['boundaries']) {
        final coords =
            decodePolyline(encoded as String).map((c) => [c[1], c[0]]).toList();
        features.add({
          'type': 'Feature',
          'properties': {'type': 'boundary', 'color': color},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [coords]
          },
        });
      }
    }

    if (station['exits'] != null) {
      for (var exit in station['exits']) {
        final coords = exit['coordinates'];
        if (coords is List && coords.length >= 2) {
          features.add({
            'type': 'Feature',
            'properties': {'type': 'exit', 'name': exit['exitName']},
            'geometry': {
              'type': 'Point',
              'coordinates': [coords[1], coords[0]]
            },
          });
        }
      }
    }
  }

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': features,
  });
}
