import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/components/floating_ad.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({Key? key, required this.sno}) : super(key: key);
  final sno;

  @override
  _RouteMapState createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  bool isLoaded = false;
  bool _adFailedToLoad = false;

  List<LatLng> routeAsLatLng = [];
  List bsids = [];
  String routeType = '';
  List routeStops = [];
  var currRoute;
  bool _isFirstLoad = true;
  MapboxMap? mapboxMap;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void loadRoute() {
    List bstopsList = getStops();
    bstopsList.forEach((e) => bsids.add(e['id']));

    var svcsParsed = getSvcs();
    currRoute = svcsParsed[widget.sno];
    if (currRoute['name'].contains('⇄')) {
      routeType = 'PTP';
      currRoute['routes'][0]
          .forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
      currRoute['routes'][1]
          .forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
    } else {
      currRoute['routes'][0]
          .forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
    }
    setState(() => routeStops = routeStops);
  }

  /// Dims all pre-existing map layers so the route stands out.
  Future<void> _dimBaseLayers(MapboxMap map) async {
    const double dimOpacity = 0.3;
    final layers = await map.style.getStyleLayers();
    for (var layer in layers) {
      if (layer == null) continue;
      try {
        switch (layer.type) {
          case 'fill':
            await map.style
                .setStyleLayerProperty(layer.id, 'fill-opacity', dimOpacity);
            break;
          case 'line':
            await map.style
                .setStyleLayerProperty(layer.id, 'line-opacity', dimOpacity);
            break;
          case 'circle':
            await map.style.setStyleLayerProperty(
                layer.id, 'circle-opacity', dimOpacity - 0.3);
            break;
          case 'symbol':
            await map.style
                .setStyleLayerProperty(layer.id, 'icon-opacity', dimOpacity);
            await map.style
                .setStyleLayerProperty(layer.id, 'text-opacity', dimOpacity);
            break;
          // case 'raster':
          //   await map.style
          //       .setStyleLayerProperty(layer.id, 'raster-opacity', dimOpacity);
          //   break;
          // case 'background':
          //   await map.style.setStyleLayerProperty(
          //       layer.id, 'background-opacity', dimOpacity);
          //   break;
        }
      } catch (_) {
        // Some layers may not support opacity — safe to skip
      }
    }
  }

  /// Adds only the route-specific layers: route stops source + route line.
  /// BaseMap already provides the full stops + MRT layers.
  Future<void> _initRouteLayers(MapboxMap map) async {
    mapboxMap = map;

    // Dim the base map so the route visually pops
    await _dimBaseLayers(map);

    final routeGeoJson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'number': widget.sno},
          'geometry': {
            'type': 'LineString',
            'coordinates': routeStops
                .where((s) => s['cords'] != null && s['cords'].length == 2)
                .map((s) => s['cords'])
                .toList(),
          },
        }
      ],
    };

    await map.style.addSource(
        GeoJsonSource(id: 'routeLine', data: jsonEncode(routeGeoJson)));
    await map.style.addLayer(LineLayer(
      id: 'stops_line_layer',
      sourceId: 'routeLine',
      slot: LayerSlot.TOP,
      lineWidth: 4.0,
      lineColor: Colors.blue.toARGB32(),
      lineEmissiveStrength: 1.0,
    ));

    final stopsGeoJson = {
      'type': 'FeatureCollection',
      'features': routeStops
          .where((stop) => stop['cords'] != null && stop['cords'].length == 2)
          .map((stop) => {
                'type': 'Feature',
                'id': stop['id'],
                'properties': {
                  'number': stop['id'],
                  'name': stop['Name'],
                  'road': stop['Road'],
                },
                'geometry': {'type': 'Point', 'coordinates': stop['cords']},
              })
          .toList(),
    };

    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

    await map.style.addSource(
        GeoJsonSource(id: 'route_stops', data: jsonEncode(stopsGeoJson)));

    await map.style.addStyleLayer(
      json.encode({
        'id': 'route_stops_layer',
        'type': 'symbol',
        'source': 'route_stops',
        'slot': 'top',
      }),
      null,
    );
    await map.style.setStyleLayerProperties(
      'route_stops_layer',
      json.encode({
        'text-field': ['get', 'name'],
        'text-size': 11,
        'text-offset': [0, 1.2],
        'text-color': (isSat || isDark) ? '#ffffff' : '#000000',
        'text-halo-color': (isSat || isDark) ? '#000000' : '#ffffff',
        'text-halo-width': 1.5,
        'text-emissive-strength': 1,
      }),
    );
    await map.style.addLayer(CircleLayer(
      id: 'route_stops_circle_layer',
      sourceId: 'route_stops',
      slot: LayerSlot.TOP,
      circleRadius: 4.0,
      // maxZoom: 15.0,
      circleColor: Colors.blue.value,
      circleStrokeWidth: 1.5,
      circleStrokeColor: Colors.white.value,
      circleEmissiveStrength: 1.0,
    ));

    // Fit camera to route bounds on first load
    if (_isFirstLoad) {
      _isFirstLoad = false;
      _fitCameraToRoute();
    }
  }

  Future<void> _fitCameraToRoute() async {
    if (mapboxMap == null || routeStops.isEmpty) return;

    // Give layout a brief moment to settle
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var stop in routeStops) {
      if (stop['cords'].length != 2) continue;
      final lng = (stop['cords'][0] as num).toDouble();
      final lat = (stop['cords'][1] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (minLat < maxLat && minLng < maxLng) {
      try {
        final cam = await mapboxMap!.cameraForCoordinateBounds(
          CoordinateBounds(
              southwest: Point(coordinates: Position(minLng, minLat)),
              northeast: Point(coordinates: Position(maxLng, maxLat)),
              infiniteBounds: false),
          MbxEdgeInsets(top: 70.0, left: 25.0, bottom: 70.0, right: 25.0),
          null,
          null,
          null,
          null,
        );
        mapboxMap?.flyTo(cam, MapAnimationOptions(duration: 2000));
      } catch (e) {
        print('Error fitting camera to route: $e');
      }
    }
  }

  Future<void> onTapListener(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) return;
    final conv = gestureContext.touchPosition;
    try {
      final features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry(
          value: jsonEncode({'x': conv.x, 'y': conv.y}),
          type: Type.SCREEN_COORDINATE,
        ),
        RenderedQueryOptions(layerIds: ['route_stops_layer']),
      );
      if (features.isNotEmpty &&
          features[0]?.queriedFeature.feature['id'] != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                Stop(features[0]!.queriedFeature.feature['id'].toString())));
      }
    } catch (e) {
      print('Error querying map: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadRoute();
    setState(() => isLoaded = true);
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
            'Bus ${widget.sno}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.width(120),
                FontVariation.weight(1000)
              ],
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BaseMap(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.8198, 1.290270)),
                zoom: 9,
              ),
              onStyleLoaded: _initRouteLayers,
              onMapTap: onTapListener,
              showCompass: true,
              showScaleBar: true,
              topPadding: MediaQuery.paddingOf(context).top + kToolbarHeight,
              bottomPadding: MediaQuery.paddingOf(context).bottom +
                  (_adFailedToLoad ? 16 : 65),
              loadDefaultBusStops: false,
              showBusStopsToggle: false,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: FloatingAd(
                margin: const EdgeInsets.only(
                  bottom: 8,
                  // left: 3,
                ),
                onAdFailedToLoad: () {
                  if (mounted) {
                    setState(() {
                      _adFailedToLoad = true;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
