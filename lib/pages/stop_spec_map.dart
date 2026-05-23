import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopSpecMap extends StatefulWidget {
  final coords;
  final name;
  const StopSpecMap({Key? key, this.coords, this.name}) : super(key: key);

  @override
  _StopSpecMapState createState() => _StopSpecMapState();
}

class _StopSpecMapState extends State<StopSpecMap> {
  bool isAdLoaded = false;
  bool error = false;
  int errorCode = 0;
  String errorMsg = '';
  var currLocation;
  late AdWidget adWidget;
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    initMap();
  }

  Future<void> initStops() async {
    List data = getStops();
    Map stopsGeoJsonMap = {
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
    await mapboxMap?.style.addSource(
        GeoJsonSource(id: "stops", data: jsonEncode(stopsGeoJsonMap)));
    var stopsLayerJSON = {
      "id": "stops_layer",
      "type": "symbol",
      "source": "stops"
    };
    await mapboxMap?.style.addStyleLayer(json.encode(stopsLayerJSON), null);

    final prefs = await SharedPreferences.getInstance();
    final isSat = prefs.getBool('isSatelliteView') ?? false;

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
      adWidget = AdWidget(
        ad: Ad,
      );
      await Ad.load();
      setState(() => isAdLoaded = true);
    } catch (err, stackTrace) {
      await Sentry.captureException(
        err,
        stackTrace: stackTrace,
      );
      if (!kReleaseMode) print(err);
    }
  }

  Future<void> initMap() async {
    if (mapboxMap != null) {
      print(widget.coords[1]);
      mapboxMap?.flyTo(
          CameraOptions(
            anchor: ScreenCoordinate(x: 0, y: 0),
            zoom: 18,
            center: Point(
              coordinates: Position(widget.coords[0], widget.coords[1]),
            ),
          ),
          MapAnimationOptions(
            duration: 2000,
            startDelay: 0,
          ));
    }
  }

  @override
  void initState() {
    if (adsEnabled) loadAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.name),
            ),
            body: BaseMap(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.8198, 1.290270)),
                zoom: 9,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoaded: (map) {
                initStops();
              },
              onMapTap: onTapListener,
              showCompass: true,
              showScaleBar: true,
              topPadding: 10,
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
    ));
  }
}
