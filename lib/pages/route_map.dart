import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
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
  bool isAdLoaded = false;
  List<LatLng> routeAsLatLng = [];
  List bsids = [];
  String routeType = '';
  List routeStops = [];
  late AdWidget adWidget;
  var currRoute;
  bool _isFirstLoad = true;
  MapboxMap? mapboxMap;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  void loadRoute() {
    List bstopsList = getStops();
    bstopsList.forEach((e) => bsids.add(e['id']));

    var svcsParsed = getSvcs();
    currRoute = svcsParsed[widget.sno];
    if (currRoute['name'].contains('⇄')) {
      routeType = 'PTP';
      currRoute['routes'][0].forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
      currRoute['routes'][1].forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
    } else {
      currRoute['routes'][0].forEach((e) => routeStops.add(bstopsList[bsids.indexOf(e)]));
    }
    setState(() => routeStops = routeStops);
  }

  /// Adds only the route-specific layers: route stops source + route line.
  /// BaseMap already provides the full stops + MRT layers.
  Future<void> _initRouteLayers(MapboxMap map) async {
    mapboxMap = map;

    final stopsGeoJson = {
      'type': 'FeatureCollection',
      'features': routeStops.map((stop) => {
        'type': 'Feature',
        'id': stop['id'],
        'properties': {
          'number': stop['id'],
          'name': stop['Name'],
          'road': stop['Road'],
        },
        'geometry': {'type': 'Point', 'coordinates': stop['cords']},
      }).toList(),
    };

    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

    await map.style.addSource(
        GeoJsonSource(id: 'route_stops', data: jsonEncode(stopsGeoJson)));

    await map.style.addStyleLayer(
      json.encode({'id': 'route_stops_layer', 'type': 'symbol', 'source': 'route_stops'}),
      null,
    );
    await map.style.setStyleLayerProperties(
      'route_stops_layer',
      json.encode({
        'text-field': ['get', 'name'],
        'icon-image': 'bus',
        'text-size': 10,
        'text-offset': [0, 2],
        'text-color': (isSat || isDark) ? '#fff' : '#000',
      }),
    );
    await map.style.addLayer(CircleLayer(
      id: 'route_stops_circle_layer',
      sourceId: 'route_stops',
      circleRadius: 1.5,
      maxZoom: 15.0,
      circleColor: Colors.blue.value,
    ));

    final routeGeoJson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'number': widget.sno},
          'geometry': {
            'type': 'LineString',
            'coordinates': routeStops.map((s) => s['cords']).toList(),
          },
        }
      ],
    };

    await map.style.addSource(
        GeoJsonSource(id: 'routeLine', data: jsonEncode(routeGeoJson)));
    await map.style.addLayer(LineLayer(
      id: 'stops_line_layer',
      sourceId: 'routeLine',
      lineWidth: 4.0,
      linePattern: 'oneway-small',
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
          null, null, null, null,
        );
        mapboxMap?.flyTo(cam, MapAnimationOptions(duration: 1000));
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

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      setState(() => isAdLoaded = true);
    } catch (err, stackTrace) {
      await Sentry.captureException(err, stackTrace: stackTrace);
      if (!kReleaseMode) print(err);
    }
  }

  @override
  void initState() {
    super.initState();
    loadRoute();
    if (adsEnabled) loadAd();
    setState(() => isLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoaded
          ? Scaffold(
              appBar: AppBar(
                title: Text('Bus ${widget.sno} route map'),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: BaseMap(
                      cameraOptions: CameraOptions(
                        center: Point(coordinates: Position(103.8198, 1.290270)),
                        zoom: 9,
                      ),
                      onStyleLoaded: _initRouteLayers,
                      onMapTap: onTapListener,
                      showCompass: true,
                      showScaleBar: true,
                      topPadding: 10,
                      loadDefaultBusStops: false,
                      showBusStopsToggle: false,
                    ),
                  ),
                  isAdLoaded
                      ? Container(
                          alignment: Alignment.center,
                          child: adWidget,
                          width: Ad.size.width.toDouble(),
                          height: Ad.size.height.toDouble(),
                        )
                      : Container()
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
