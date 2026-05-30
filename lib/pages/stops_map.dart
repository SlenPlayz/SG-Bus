import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopsMap extends StatefulWidget {
  const StopsMap({Key? key}) : super(key: key);

  @override
  _StopsMapState createState() => _StopsMapState();
}

class _StopsMapState extends State<StopsMap> {
  bool isLoaded = false;
  bool isAdLoaded = false;
  gl.Position? currLocation;
  late AdWidget adWidget;
  String? _stopsGeoJson;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }

  Future<void> initStops() async {
    if (_stopsGeoJson == null) return;
    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

    await mapboxMap?.style
        .addSource(GeoJsonSource(id: "stops", data: _stopsGeoJson!));
    var stopsLayerJSON = {
      "id": "stops_layer",
      "type": "symbol",
      "source": "stops"
    };
    await mapboxMap?.style.addStyleLayer(json.encode(stopsLayerJSON), null);
    var stopsLayerProperties = {
      'text-field': ['get', 'name'],
      "icon-image": "bus",
      "text-size": 10,
      "text-offset": [0, 2],
      "text-color": (isSat || isDark) ? "#fff" : "#000",
    };
    await mapboxMap?.style.setStyleLayerProperties(
        "stops_layer", json.encode(stopsLayerProperties));

    await mapboxMap?.style.addLayer(CircleLayer(
      id: "stops_circle_layer",
      sourceId: "stops",
      circleRadius: 0.5,
      maxZoom: 15.0,
      circleColor: Colors.blue.value.toInt(),
    ));
  }

  Future<void> onTapListener(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) return;

    final ScreenCoordinate conv = gestureContext.touchPosition;

    try {
      final List<QueriedRenderedFeature?> features =
          await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry(
          value: jsonEncode({
            "x": conv.x,
            "y": conv.y,
          }),
          type: Type.SCREEN_COORDINATE,
        ),
        RenderedQueryOptions(
          layerIds: ["stops_layer"],
        ),
      );

      if (features.isNotEmpty &&
          features[0]?.queriedFeature.feature["id"] != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (builder) =>
                Stop(features[0]!.queriedFeature.feature["id"].toString())));
      }
    } catch (e) {
      print("Error querying map: $e");
    }
  }

  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      isAdLoaded = true;
    } catch (err, stackTrace) {
      await Sentry.captureException(
        err,
        stackTrace: stackTrace,
      );
      if (!kReleaseMode) print(err);
    }
  }

  Future<void> _loadAllDependencies() async {
    setState(() {
      isLoaded = false;
    });

    final List<Future<dynamic>> futures = [
      LocationHelper.getUserLocation(context).then((res) {
        if (!res.hasError) {
          currLocation = res.position;
        }
      }),
      compute(_generateStopsGeoJson, getStops()).then((geoJson) {
        _stopsGeoJson = geoJson;
      }),
    ];

    if (adsEnabled) {
      futures.add(loadAd());
    }

    try {
      await Future.wait(futures);
    } catch (e, stackTrace) {
      print("Error loading dependencies: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }

    setState(() {
      isLoaded = true;
    });
  }

  @override
  void initState() {
    _loadAllDependencies();
    super.initState();
  }

  @override
  void dispose() {
    Ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoaded
          ? Column(
              children: [
                Expanded(
                  child: Scaffold(
                    body: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18)),
                      child: BaseMap(
                        cameraOptions: CameraOptions(
                          center: Point(
                            coordinates: currLocation != null
                                ? Position(currLocation!.longitude,
                                    currLocation!.latitude)
                                : Position(103.8198, 1.290270),
                          ),
                          zoom: currLocation != null ? 17 : 9,
                        ),
                        onMapCreated: _onMapCreated,
                        onStyleLoaded: (map) {
                          initStops();
                        },
                        onMapTap: onTapListener,
                        fabBottomPadding: 50.0,
                        showScaleBar: true,
                        showCompass: true,
                        topPadding: MediaQuery.paddingOf(context).top,
                      ),
                    ),
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
            )
          : const Center(child: ExpressiveLoadingIndicator()),
    );
  }
}

String _generateStopsGeoJson(List data) {
  final Map stopsGeoJsonMap = {
    "type": "FeatureCollection",
    "features": [],
  };

  for (var stop in data) {
    stopsGeoJsonMap["features"].add({
      "type": "Feature",
      "id": stop["id"],
      "properties": {
        "number": stop["id"],
        "name": stop["Name"],
        "road": stop["Road"],
      },
      "geometry": {"type": "Point", "coordinates": stop["cords"]}
    });
  }
  return jsonEncode(stopsGeoJsonMap);
}
