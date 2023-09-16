import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List bsnos = [];
  String routeType = '';
  List shownRoute = [];
  List routeStops = [];
  late AdWidget adWidget;
  var currRoute;
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  Future<void> loadRoute() async {
    List bstopsList = getStops();
    bstopsList.forEach((element) => bsids.add(element['id']));

    var svcsParsed = getSvcs();
    currRoute = svcsParsed[widget.sno];
    if (currRoute['name'].contains('⇄')) {
      routeType = 'PTP';
      currRoute['routes'][0].forEach((element) {
        routeStops.add(bstopsList[bsids.indexOf(element)]);
      });
      currRoute['routes'][1].forEach((element) {
        routeStops.add(bstopsList[bsids.indexOf(element)]);
      });
    } else {
      currRoute['routes'][0].forEach((element) {
        routeStops.add(bstopsList[bsids.indexOf(element)]);
      });
    }

    setState(() => routeStops = routeStops);
  }

  // Future<void> initStops() async {
  //   loadRoute();
  //   for (var stop in routeStops) {
  //     // stops.add(Marker(
  //     //   point: LatLng(stop["cords"][1], stop["cords"][0]),
  //     //   builder: (context) => const CircleAvatar(
  //     //     child: Icon(
  //     //       Icons.directions_bus,
  //     //       color: Colors.white,
  //     //     ),
  //     //     backgroundColor: Colors.black,
  //     //   ),
  //     // ));
  //   }
  //   setState(() {
  //     stops = stops;
  //   });
  // }

  // Future<void> openStopByPos(pos) async {
  //   List data = getStops();

  //   for (var element in data) {
  //     if ((element['cords'][1] == pos.latitude) &&
  //         element['cords'][0] == pos.longitude) {
  //       openStop(element['id']);
  //     }
  //   }
  // }

  // void openStop(id) {
  //   Navigator.push(context, MaterialPageRoute(builder: (context) => Stop(id)));
  // }

  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    initStops();
  }

  Future<void> initStops() async {
    loadRoute();
    Map stopsGeoJsonMap = {
      "type": "FeatureCollection",
      "features": [],
    };

    Map busRouteGeoJsonMap = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"number": widget.sno},
          "geometry": {"type": "LineString", "coordinates": []}
        }
      ],
    };

    for (var stop in routeStops) {
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

      busRouteGeoJsonMap["features"][0]["geometry"]["coordinates"]
          .add(stop["cords"]);
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
      circleRadius: 1.5,
      maxZoom: 15.0,
      circleColor: Colors.blue.value,
    ));

    await mapboxMap?.style.addSource(
        GeoJsonSource(id: "routeLine", data: jsonEncode(busRouteGeoJsonMap)));

    await mapboxMap?.style.addLayer(LineLayer(
      id: "stops_line_layer",
      sourceId: "routeLine",
      lineWidth: 4.0,
      linePattern: "oneway-small",
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

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      setState(() {
        isAdLoaded = true;
      });
    } catch (err, stackTrace) {
      await Sentry.captureException(
        err,
        stackTrace: stackTrace,
      );
      if (!kReleaseMode) print(err);
    }
  }

  void initRouteLine() {
    // var routes = getRoutes();
    // List routeArrayRaw = [];

    // for (var route in routes) {
    //   if (route['properties']['number'] == widget.sno) {
    //     routeArrayRaw = route['geometry']['coordinates'];
    //     break;
    //   }
    // }

    // routeArrayRaw.forEach((coordinate) {
    //   routeAsLatLng.add(LatLng(coordinate[1], coordinate[0]));
    // });
  }

  @override
  void initState() {
    super.initState();
    initStops();
    initRouteLine();
    if (adsEnabled) loadAd();
    setState(() {
      stops = stops;
      isLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // var brightness = MediaQuery.of(context).platformBrightness;
    // bool isDarkMode = brightness == Brightness.dark;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: isLoaded
          ? Scaffold(
              appBar: AppBar(
                title: Text('${'Service ' + widget.sno} route map'),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: MapWidget(
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
