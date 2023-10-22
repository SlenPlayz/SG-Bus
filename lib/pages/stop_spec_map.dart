import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:url_launcher/url_launcher.dart';

class StopSpecMap extends StatefulWidget {
  final coords;
  final name;
  const StopSpecMap({Key? key, this.coords, this.name}) : super(key: key);
  // final updatePos;

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
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    initMap();
    initStops();
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
      // stops.add(
      //   Marker(
      //     // point: LatLng(element["cords"][1], element["cords"][0]),
      //     builder: (context) => const CircleAvatar(
      //       child: Icon(Icons.directions_bus, color: Colors.white),
      //       backgroundColor: Colors.black,
      //     ),
      //   ),
      // );
    }
    await mapboxMap?.style.addSource(
        GeoJsonSource(id: "stops", data: jsonEncode(stopsGeoJsonMap)));
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
      "text-color": "#fff",
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

    mapboxMap?.setOnMapTapListener(onTapListener);
  }

  Future<void> onTapListener(ScreenCoordinate coord) async {
    // need to convert coord to real ScreenCoordinate for querying features.
    final ScreenCoordinate conv = await mapboxMap!.pixelForCoordinate(
      Point(
        coordinates: Position(
          coord.y,
          coord.x,
        ),
      ).toJson(),
    );

    final List<QueriedFeature?> features =
        await mapboxMap!.queryRenderedFeatures(
      RenderedQueryGeometry(
        value: jsonEncode(conv.encode()),
        type: Type.SCREEN_COORDINATE,
      ),
      RenderedQueryOptions(
        layerIds: ["stops_layer"],
      ),
    );

    if (features[0] != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (builder) => Stop(features[0]!.feature["id"].toString())));
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

  Future<void> initMap() async {
    if (mapboxMap != null) {
      print(widget.coords[1]);
      mapboxMap?.flyTo(
          CameraOptions(
            anchor: ScreenCoordinate(x: 0, y: 0),
            zoom: 18,
            center: Point(
              coordinates: Position(widget.coords[0], widget.coords[1]),
            ).toJson(),
          ),
          MapAnimationOptions(
            duration: 2000,
            startDelay: 0,
          ));
    }
  }

  @override
  void initState() {
    // initMap();
    // if (adsEnabled) loadAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // var brightness = MediaQuery.of(context).platformBrightness;
    // bool isDarkMode = brightness == Brightness.dark;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
        body: Column(
      children: [
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.name),
            ),
            body: MapWidget(
              resourceOptions: ResourceOptions(
                accessToken: mapboxAccessToken,
              ),
              cameraOptions: CameraOptions(
                center:
                    Point(coordinates: Position(103.8198, 1.290270)).toJson(),
                zoom: 9,
              ),
              onMapCreated: _onMapCreated,
              styleUri: isDark
                  ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
                  : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m",
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
