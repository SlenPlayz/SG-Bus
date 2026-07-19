import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/pages/mrt_pages/station_page.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GpsState {
  uncentered,
  centered,
  heading,
}

class BaseMap extends StatefulWidget {
  final GpsState initialGpsState;
  final CameraOptions? cameraOptions;
  final void Function(MapboxMap mapboxMap)? onMapCreated;
  final void Function(MapboxMap mapboxMap)? onStyleLoaded;
  final void Function(MapContentGestureContext gestureContext)? onMapTap;
  final Widget? overlay;
  final bool showScaleBar;
  final bool showCompass;
  final double? topPadding;
  final double? bottomPadding;

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
    this.initialGpsState = GpsState.uncentered,
    this.cameraOptions,
    this.onMapCreated,
    this.onStyleLoaded,
    this.onMapTap,
    this.overlay,
    required this.showScaleBar,
    required this.showCompass,
    this.topPadding,
    this.bottomPadding,
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
  String _mapTheme = 'auto';
  bool _isPreferencesLoaded = false;
  String? _currentStyleUri;
  bool locationError = false;

  GpsState _gpsState = GpsState.uncentered;
  ViewportState? _viewportState;
  double _currentPitch = 0.0;

  // Layer visibility state — owned entirely by BaseMap
  bool _showBusStops = true;
  bool _showTrainLines = true;
  bool _showStationExits = true;
  bool _showStationBoundaries = true;

  void _onMapScroll(MapContentGestureContext context) {
    _onMapInteraction();
  }

  void _onMapZoom(MapContentGestureContext context) {
    _onMapInteraction();
  }

  void _onMapInteraction() {
    if (_gpsState != GpsState.uncentered) {
      setState(() {
        _gpsState = GpsState.uncentered;
        _viewportState = const IdleViewportState();
      });
    }
  }

  void _toggle3d() {
    final targetPitch = _currentPitch == 0.0 ? 45.0 : 0.0;

    if (_gpsState == GpsState.centered) {
      setStateWithViewportAnimation(() {
        _viewportState = FollowPuckViewportState(
          zoom: 17.0,
          bearing: const FollowPuckViewportStateBearingConstant(0.0),
          pitch: targetPitch,
        );
      }, transition: const EasingViewportTransition(duration: Duration(milliseconds: 300)));
    } else if (_gpsState == GpsState.heading) {
      setStateWithViewportAnimation(() {
        _viewportState = FollowPuckViewportState(
          zoom: 17.0,
          bearing: const FollowPuckViewportStateBearingHeading(),
          pitch: targetPitch,
        );
      }, transition: const EasingViewportTransition(duration: Duration(milliseconds: 300)));
    } else {
      mapboxMap?.easeTo(
        CameraOptions(pitch: targetPitch),
        MapAnimationOptions(duration: 300),
      );
    }
  }

  Widget _buildGpsIcon() {
    if (locationError) {
      return const Icon(Icons.location_disabled_rounded);
    }
    switch (_gpsState) {
      case GpsState.uncentered:
        return Icon(
          Icons.location_searching,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case GpsState.centered:
        return Icon(
          Icons.my_location,
          color: Theme.of(context).colorScheme.primary,
        );
      case GpsState.heading:
        return Icon(
          Icons.explore,
          color: Theme.of(context).colorScheme.primary,
        );
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _gpsState = widget.initialGpsState;
    if (_gpsState == GpsState.centered) {
      _viewportState = FollowPuckViewportState(
        zoom: widget.cameraOptions?.zoom ?? 17.0,
        bearing: const FollowPuckViewportStateBearingConstant(0.0),
        pitch: widget.cameraOptions?.pitch ?? 0.0,
      );
    }
    _currentPitch = widget.cameraOptions?.pitch ?? 0.0;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSatelliteView = prefs.getBool('isSatelliteView') ?? false;
        _mapTheme = prefs.getString('mapTheme') ?? 'auto';
        _isPreferencesLoaded = true;
      });
    }
  }

  // ── Standard layer init ────────────────────────────────────────────────────

  Future<void> _initStops() async {
    final stopsData = getStops();
    if (stopsData == null) return;
    final prefs = await SharedPreferences.getInstance();

    final geoJson = await compute(_generateStopsGeoJson, stopsData);

    await mapboxMap?.style.addSource(GeoJsonSource(id: 'stops', data: geoJson));

    await mapboxMap?.style.addStyleLayer(
      json.encode({
        'id': 'stops_layer',
        'type': 'symbol',
        'source': 'stops',
        'slot': 'top',
        'minzoom': 13.0,
      }),
      null,
    );
    await mapboxMap?.style.setStyleLayerProperties(
      'stops_layer',
      json.encode({
        'text-field': ['get', 'name'],
        'text-size': 11,
        'text-offset': [0, 1.2],
        'text-color': _isMapDark ? '#ffffff' : '#000000',
        'text-halo-color': _isMapDark ? '#000000' : '#ffffff',
        'text-halo-width': 1.5,
        'text-emissive-strength': 1,
        'icon-emissive-strength': 1,
      }),
    );
    await mapboxMap?.style.addLayer(CircleLayer(
      id: 'stops_circle_layer',
      sourceId: 'stops',
      slot: LayerSlot.TOP,
      circleRadius: 4.0,
      minZoom: 13.0,
      maxZoom: 19.0,
      circleColor: Colors.blue.toARGB32(),
      circleStrokeWidth: 1.5,
      circleStrokeColor: Colors.white.toARGB32(),
      circleEmissiveStrength: 1.0,
    ));
  }

  Future<void> _initMrt() async {
    final mrtData = getMRTData();
    if (mrtData == null) return;
    final prefs = await SharedPreferences.getInstance();

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
        'slot': 'middle',
        'minzoom': 14.0,
        'filter': ['==', 'type', 'boundary'],
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': 0.18,
          'fill-emissive-strength': 1,
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
        'slot': 'middle',
        'minzoom': 14.0,
        'filter': ['==', 'type', 'boundary'],
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 3.0,
          'line-emissive-strength': 1,
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
        'slot': 'middle',
        'filter': ['==', 'type', 'line'],
        'paint': {
          'line-color': ['get', 'lineColor'],
          'line-width': 4.0,
          'line-emissive-strength': 1,
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
        'slot': 'top',
        'minzoom': 10.5,
        'filter': ['==', 'type', 'station'],
        'paint': {
          'circle-radius': 5.0,
          'circle-color': '#ffffff',
          'circle-stroke-width': 2.0,
          'circle-stroke-color': '#000000',
          'circle-emissive-strength': 1,
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
        'slot': 'top',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'station'],
        'layout': {
          'text-field': ['get', 'name'],
          'text-size': 12,
          'text-offset': [0, 1.5]
        },
        'paint': {
          'text-color': _isMapDark ? '#ffffff' : '#000000',
          'text-halo-color': _isMapDark ? '#000000' : '#ffffff',
          'text-halo-width': 1.0,
          'text-emissive-strength': 1,
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
        'slot': 'top',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'exit'],
        'paint': {
          'circle-radius': 3.0,
          'circle-color': '#ffeb3b',
          'circle-stroke-width': 1.0,
          'circle-stroke-color': '#000000',
          'circle-emissive-strength': 1,
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
        'slot': 'top',
        'minzoom': 15.0,
        'filter': ['==', 'type', 'exit'],
        'layout': {
          'text-field': ['get', 'name'],
          'text-size': 10,
          'text-offset': [0, 1.2]
        },
        'paint': {
          'text-color': _isMapDark ? '#ffffff' : '#000000',
          'text-emissive-strength': 1,
        },
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
    final bottomMargin = widget.bottomPadding ?? 0;
    map.logo.updateSettings(LogoSettings(marginBottom: bottomMargin));
    map.attribution.updateSettings(AttributionSettings(marginBottom: bottomMargin));
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

    _currentStyleUri = MapboxStyles.STANDARD;

    if (widget.onMapCreated != null) widget.onMapCreated!(map);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (mapboxMap == null) return;

    // Configure Standard style: light preset and disable transit labels
    await _applyStandardStyleConfig();

    // Always initialise standard layers first
    if (widget.loadDefaultBusStops) {
      await _initStops();
    }
    await _initMrt();

    // Then let the page add its own layers
    if (widget.onStyleLoaded != null) widget.onStyleLoaded!(mapboxMap!);

    if (_isSatelliteView) await _toggleSatelliteMode(true);

    mapboxMap!.setOnMapTapListener(_handleMapTap);
  }

  bool get _isMapDark {
    if (_isSatelliteView) return true;
    if (_mapTheme == 'night' || _mapTheme == 'dusk') return true;
    if (_mapTheme == 'day' || _mapTheme == 'dawn') return false;
    final hour = DateTime.now().hour;
    return (hour >= 19 || hour < 7);
  }

  Future<void> _updateLayerTextColors() async {
    final style = mapboxMap?.style;
    if (style == null) return;

    final textColor = _isMapDark ? '#ffffff' : '#000000';
    final haloColor = _isMapDark ? '#000000' : '#ffffff';

    try {
      if (await style.styleLayerExists('stops_layer')) {
        await style.setStyleLayerProperty(
            'stops_layer', 'text-color', textColor);
        await style.setStyleLayerProperty(
            'stops_layer', 'text-halo-color', haloColor);
      }
      if (await style.styleLayerExists('mrt_station_text_layer')) {
        await style.setStyleLayerProperty(
            'mrt_station_text_layer', 'text-color', textColor);
        await style.setStyleLayerProperty(
            'mrt_station_text_layer', 'text-halo-color', haloColor);
      }
      if (await style.styleLayerExists('mrt_exit_text_layer')) {
        await style.setStyleLayerProperty(
            'mrt_exit_text_layer', 'text-color', textColor);
      }
    } catch (e) {
      print('Error updating text colors: $e');
    }
  }

  Future<void> _setMapTheme(String theme) async {
    setState(() => _mapTheme = theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapTheme', theme);
    await _applyStandardStyleConfig();
    await _updateLayerTextColors();
  }

  /// Applies Standard style configuration: sets the light preset based on
  /// the current theme and disables transit labels.
  Future<void> _applyStandardStyleConfig() async {
    try {
      final style = mapboxMap?.style;
      if (style == null) return;

      String preset = 'day';
      if (_isSatelliteView) {
        preset = 'night';
      } else if (_mapTheme == 'night') {
        preset = 'night';
      } else if (_mapTheme == 'dusk') {
        preset = 'dusk';
      } else if (_mapTheme == 'day') {
        preset = 'day';
      } else if (_mapTheme == 'dawn') {
        preset = 'dawn';
      } else {
        final hour = DateTime.now().hour;
        if (hour >= 9 && hour < 17) {
          preset = 'day';
        } else if (hour >= 17 && hour < 19) {
          preset = 'dusk';
        } else if (hour >= 19 || hour < 6) {
          preset = 'night';
        } else {
          preset = 'dawn';
        }
      }

      await style.setStyleImportConfigProperties('basemap', {
        'lightPreset': preset,
        'showTransitLabels': false,
        'show3dObjects': !_isSatelliteView,
      });
    } catch (e) {
      print('Error applying Standard style config: $e');
    }
  }

  /// Extracts a property value from a queried feature's properties,
  /// handling both Map and JSON-string formats returned by Mapbox SDK.
  String? _getFeatureProperty(
      QueriedRenderedFeature? qrf, String propertyName) {
    if (qrf == null) return null;
    try {
      final feature = qrf.queriedFeature.feature;
      var properties = feature['properties'];
      if (properties is String) {
        properties = json.decode(properties);
      }
      if (properties is Map) {
        final value = properties[propertyName];
        return value?.toString();
      }
    } catch (e) {
      print('Error extracting feature property "$propertyName": $e');
    }
    return null;
  }

  Future<void> _handleMapTap(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) {
      widget.onMapTap?.call(gestureContext);
      return;
    }

    final conv = gestureContext.touchPosition;
    final screenCoord = RenderedQueryGeometry.fromScreenCoordinate(
      ScreenCoordinate(x: conv.x, y: conv.y),
    );

    // 1. Check MRT station circles
    try {
      final stationFeatures = await mapboxMap!.queryRenderedFeatures(
        screenCoord,
        RenderedQueryOptions(layerIds: ['mrt_station_circle_layer']),
      );
      if (stationFeatures.isNotEmpty) {
        final codeStr = _getFeatureProperty(stationFeatures[0], 'code');
        if (codeStr != null && codeStr.isNotEmpty) {
          final code = codeStr.split('/').first;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StationPage(stationCode: code),
          ));
          return;
        }
      }
    } catch (e) {
      print('Error querying station circles: $e');
    }

    // 2. Check MRT boundaries (fill + outline)
    try {
      final boundaryFeatures = await mapboxMap!.queryRenderedFeatures(
        screenCoord,
        RenderedQueryOptions(
            layerIds: ['mrt_boundary_layer', 'mrt_boundary_line_layer']),
      );
      if (boundaryFeatures.isNotEmpty) {
        final codeStr = _getFeatureProperty(boundaryFeatures[0], 'code');
        if (codeStr != null && codeStr.isNotEmpty) {
          final code = codeStr.split('/').first;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StationPage(stationCode: code),
          ));
          return;
        }
      }
    } catch (e) {
      print('Error querying boundaries: $e');
    }

    // 3. Check bus stops
    try {
      final stopFeatures = await mapboxMap!.queryRenderedFeatures(
        screenCoord,
        RenderedQueryOptions(layerIds: ['stops_layer', 'stops_circle_layer']),
      );
      if (stopFeatures.isNotEmpty &&
          stopFeatures[0]?.queriedFeature.feature['id'] != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              Stop(stopFeatures[0]!.queriedFeature.feature['id'].toString()),
        ));
        return;
      }
    } catch (e) {
      print('Error querying bus stops: $e');
    }

    // Fall through to page-specific tap handler
    widget.onMapTap?.call(gestureContext);
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

    final targetStyleUri = MapboxStyles.STANDARD;

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

        final layerExists = await style.styleLayerExists('onemap-sat-layer');
        if (!layerExists) {
          await style.addLayer(RasterLayer(
            id: 'onemap-sat-layer',
            sourceId: 'onemap-sat-source',
            slot: LayerSlot.MIDDLE,
            rasterContrast: 0.40,
            rasterSaturation: -0.1,
            rasterEmissiveStrength: 1.0,
          ));
        } else {
          await _setLayerVisibility('onemap-sat-layer', true);
        }
      } else {
        await _setLayerVisibility('onemap-sat-layer', false);
      }

      await _applyStandardStyleConfig();

      // Smoothly animate the pitch
      mapboxMap!.easeTo(
        CameraOptions(pitch: enableSatellite ? 0.0 : 45.0),
        MapAnimationOptions(duration: 1000),
      );

      await _updateLayerTextColors();
    } catch (e, stackTrace) {
      print('Error in _toggleSatelliteMode: $e');
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  // ── Bottom sheet ───────────────────────────────────────────────────────────

  void _showMapTypeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  void toggle(void Function() updateState,
                      void Function(bool) fn, bool value) {
                    setModalState(updateState);
                    fn(value);
                  }

                  final hasLayers = (widget.loadDefaultBusStops &&
                          widget.showBusStopsToggle) ||
                      widget.showTrainLinesToggle ||
                      widget.showStationExitsToggle ||
                      widget.showStationBoundariesToggle;

                  TextStyle? titleStyle(BuildContext ctx) => Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontVariations: [
                        FontVariation('ROND', 100),
                        FontVariation.width(120),
                        FontVariation.weight(1000),
                      ]);

                  TextStyle? subtitleStyle(BuildContext ctx) => Theme.of(ctx)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontVariations: [
                        FontVariation('ROND', 50),
                        FontVariation.width(105),
                        FontVariation.weight(500),
                      ]);

                  return SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            margin:
                                const EdgeInsets.only(top: 16.0, bottom: 8.0),
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Map View',
                                        style: titleStyle(context)),
                                    Opacity(
                                      opacity: 0.8,
                                      child: Text(
                                          'Changes how the map is rendered.',
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
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
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
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                onChanged: (v) {
                                  if (v != null) {
                                    Navigator.pop(context);
                                    _toggleSatelliteMode(v);
                                  }
                                },
                              ),
                              const Divider(height: 32),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Map Theme',
                                        style: titleStyle(context)),
                                    Opacity(
                                      opacity: 0.8,
                                      child: Text(
                                          'Controls the map\'s lighting style.',
                                          style: subtitleStyle(context)),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Dawn'),
                                        avatar: const Icon(Icons.wb_twilight,
                                            size: 18),
                                        showCheckmark: false,
                                        selected: _mapTheme == 'dawn',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setModalState(
                                                () => _mapTheme = 'dawn');
                                            _setMapTheme('dawn');
                                          }
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Day'),
                                        avatar: const Icon(Icons.light_mode,
                                            size: 18),
                                        showCheckmark: false,
                                        selected: _mapTheme == 'day',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setModalState(
                                                () => _mapTheme = 'day');
                                            _setMapTheme('day');
                                          }
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Dusk'),
                                        avatar: const Icon(Icons.wb_twilight,
                                            size: 18),
                                        showCheckmark: false,
                                        selected: _mapTheme == 'dusk',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setModalState(
                                                () => _mapTheme = 'dusk');
                                            _setMapTheme('dusk');
                                          }
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Night'),
                                        avatar: const Icon(Icons.dark_mode,
                                            size: 18),
                                        showCheckmark: false,
                                        selected: _mapTheme == 'night',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setModalState(
                                                () => _mapTheme = 'night');
                                            _setMapTheme('night');
                                          }
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Time of Day'),
                                        avatar: const Icon(Icons.access_time,
                                            size: 18),
                                        showCheckmark: false,
                                        selected: _mapTheme == 'auto',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setModalState(
                                                () => _mapTheme = 'auto');
                                            _setMapTheme('auto');
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (hasLayers) ...[
                                const Divider(height: 32),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16.0, bottom: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Layers',
                                          style: titleStyle(context)),
                                      Opacity(
                                        opacity: 0.8,
                                        child: Text(
                                            'Toggle map data layers on or off.',
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
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (v) => toggle(
                                        () => _showBusStops = v,
                                        _toggleBusStops,
                                        v),
                                  ),
                                if (widget.showTrainLinesToggle)
                                  SwitchListTile(
                                    secondary: const Icon(Icons.train),
                                    title: const Text('Train Line Routes'),
                                    value: _showTrainLines,
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (v) => toggle(
                                        () => _showTrainLines = v,
                                        _toggleTrainLines,
                                        v),
                                  ),
                                if (widget.showStationExitsToggle)
                                  SwitchListTile(
                                    secondary: const Icon(Icons.exit_to_app),
                                    title: const Text('Station Exits'),
                                    value: _showStationExits,
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (v) => toggle(
                                        () => _showStationExits = v,
                                        _toggleStationExits,
                                        v),
                                  ),
                                if (widget.showStationBoundariesToggle)
                                  SwitchListTile(
                                    secondary: const Icon(Icons.crop_square),
                                    title: const Text('Station Boundaries'),
                                    value: _showStationBoundaries,
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (v) => toggle(
                                        () => _showStationBoundaries = v,
                                        _toggleStationBoundaries,
                                        v),
                                  ),
                              ], // Closes `if (hasLayers) ...[`
                            ], // Closes children of inner Column
                          ), // Closes inner Column
                        ), // Closes Padding
                      ], // Closes children of outer Column
                    ), // Closes outer Column
                    ), // Closes SingleChildScrollView
                  ); // Closes SafeArea
                }, // Closes builder for StatefulBuilder
              ), // Closes StatefulBuilder
            ), // Closes Container
          ), // Closes BackdropFilter
        ); // Closes ClipRRect
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
          viewport: _viewportState,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          styleUri: MapboxStyles.STANDARD,
          onScrollListener: _onMapScroll,
          onZoomListener: _onMapZoom,
          onCameraChangeListener: (data) {
            final newPitch = data.cameraState.pitch;
            if (_currentPitch != newPitch) {
              setState(() {
                _currentPitch = newPitch;
              });
            }
          },
        ),
        Positioned(
          bottom: widget.bottomPadding ?? 16.0,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'map_3d_2d_toggle_${widget.hashCode}',
                onPressed: _toggle3d,
                child: Text(
                  _currentPitch == 0.0 ? '3D' : '2D',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.small(
                heroTag: 'map_layer_toggle_${widget.hashCode}',
                onPressed: () => _showMapTypeBottomSheet(context),
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'my_location_${widget.hashCode}',
                onPressed: () async {
                  if (locationError) {
                    setState(() => locationError = false);
                  }

                  final res = await LocationHelper.getUserLocation(context);
                  if (!res.hasError && res.position != null) {
                    setState(() {
                      locationError = false;
                      currLocation = res.position;
                    });

                    if (_gpsState == GpsState.uncentered) {
                      setStateWithViewportAnimation(() {
                        _viewportState = FollowPuckViewportState(
                          zoom: 17.0,
                          bearing: const FollowPuckViewportStateBearingConstant(0.0),
                          pitch: 0.0,
                        );
                        _gpsState = GpsState.centered;
                      }, transition: const EasingViewportTransition(duration: Duration(milliseconds: 1000)));
                    } else if (_gpsState == GpsState.centered) {
                      setStateWithViewportAnimation(() {
                        _viewportState = const FollowPuckViewportState(
                          zoom: 17.0,
                          bearing: FollowPuckViewportStateBearingHeading(),
                          pitch: 45.0,
                        );
                        _gpsState = GpsState.heading;
                      }, transition: const EasingViewportTransition(duration: Duration(milliseconds: 1000)));
                    } else if (_gpsState == GpsState.heading) {
                      setStateWithViewportAnimation(() {
                        _viewportState = FollowPuckViewportState(
                          zoom: 17.0,
                          bearing: const FollowPuckViewportStateBearingConstant(0.0),
                          pitch: 0.0,
                        );
                        _gpsState = GpsState.centered;
                      }, transition: const EasingViewportTransition(duration: Duration(milliseconds: 1000)));
                    }
                  } else {
                    setState(() {
                      locationError = true;
                      _gpsState = GpsState.uncentered;
                      _viewportState = const IdleViewportState();
                    });
                  }
                },
                child: _buildGpsIcon(),
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
          'properties': {
            'type': 'boundary',
            'color': color,
            'code': (station['codes'] as List?)?.join('/') ?? '',
          },
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
