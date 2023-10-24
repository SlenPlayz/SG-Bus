import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class StopsMap extends StatefulWidget {
  const StopsMap({Key? key}) : super(key: key);

  @override
  _StopsMapState createState() => _StopsMapState();
}

class _StopsMapState extends State<StopsMap> {
  bool isLoaded = false;
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

  Future<void> requestGPSPermission() async {
    await gl.Geolocator.requestPermission();
    initMap();
  }

  Future<void> enableGPSInSettings() async {
    await gl.Geolocator.openLocationSettings();
    initMap();
  }

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

  Future getLocation() async {
    // Check if GPS is enabled
    bool isGPSEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!isGPSEnabled) {
      error = true;
      errorMsg = 'GPS is disabled';
      errorCode = 1;
      return Future.error(errorMsg);
    }

    //Check is GPS Permission is given
    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      error = true;
      errorMsg = 'GPS Permissions not given';
      errorCode = 2;
      return Future.error(errorMsg);
    }

    //Check if GPS permissions are permenents denied
    if (permission == gl.LocationPermission.deniedForever) {
      error = true;
      errorMsg = 'GPS Permissions are denied';
      errorCode = 3;
      return Future.error(errorMsg);
    }

    currLocation = await gl.Geolocator.getCurrentPosition();
    setState(() {
      currLocation = currLocation;
    });

    return currLocation;
  }

  Future<void> initMap() async {
    isLoaded = false;
    getLocation().then((postion) {
      setState(() {
        isLoaded = true;
      });
      if (mapboxMap != null) {
        mapboxMap?.flyTo(
            CameraOptions(
              anchor: ScreenCoordinate(x: 0, y: 0),
              zoom: 17,
              center: Point(
                coordinates: Position(postion.longitude, postion.latitude),
              ).toJson(),
            ),
            MapAnimationOptions(
              duration: 2000,
              startDelay: 0,
            ));
      }
    }).catchError((err) {
      setState(() {
        isLoaded = true;
      });
    });
  }

  @override
  void initState() {
    initMap();
    if (adsEnabled) loadAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: FloatingActionButton(
          onPressed: () async {
            getLocation().then((position) {
              mapboxMap?.flyTo(
                  CameraOptions(
                    anchor: ScreenCoordinate(x: 0, y: 0),
                    zoom: 17,
                    center: Point(
                      coordinates:
                          Position(position.longitude, position.latitude),
                    ).toJson(),
                  ),
                  MapAnimationOptions(
                    duration: 2000,
                    startDelay: 0,
                  ));
            }).catchError((err) {
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      icon: const Icon(Icons.warning),
                      title: (err.runtimeType == String)
                          ? Text(errorMsg)
                          : Text(
                              'An unknown error occured while trying to move to your location'),
                      actions: [
                        (errorCode == 1)
                            ? TextButton(
                                onPressed: () {
                                  initMap();
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Retry'))
                            : (errorCode == 2)
                                ? TextButton(
                                    onPressed: () {
                                      requestGPSPermission();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Request permission'))
                                : (errorCode == 2)
                                    ? TextButton(
                                        onPressed: () {
                                          enableGPSInSettings();
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Request permission'))
                                    : Container()
                      ],
                    );
                  });
            });
          },
          child: (currLocation != null)
              ? const Icon(Icons.my_location)
              : const Icon(Icons.location_disabled_rounded),
        ),
      ),
      body: isLoaded
          ? Column(
              children: [
                Expanded(
                  child: Scaffold(
                    body: MapWidget(
                      resourceOptions: ResourceOptions(
                        accessToken: mapboxAccessToken,
                      ),
                      cameraOptions: CameraOptions(
                        center: Point(coordinates: Position(103.8198, 1.290270))
                            .toJson(),
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
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
