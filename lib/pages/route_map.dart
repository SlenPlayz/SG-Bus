import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map/flutter_map.dart';
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

  List<Marker> stops = [];
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
    bstopsList.forEach((element) => {bsids.add(element['id'])});

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

    setState(() => {routeStops = routeStops});
  }

  Future<void> initStops() async {
    loadRoute();
    for (var stop in routeStops) {
      stops.add(Marker(
        point: LatLng(stop["cords"][1], stop["cords"][0]),
        builder: (context) => const CircleAvatar(
          child: Icon(Icons.directions_bus, color: Colors.white,),
          backgroundColor: Colors.black,
        ),
      ));
    }
    setState(() {
      stops = stops;
    });
  }

  Future<void> openStopByPos(pos) async {
    List data = getStops();

    for (var element in data) {
      if ((element['cords'][1] == pos.latitude) &&
          element['cords'][0] == pos.longitude) {
        openStop(element['id']);
      }
    }
  }

  void openStop(id) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Stop(id)));
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
                    child: FlutterMap(
                      options: MapOptions(
                        plugins: [
                          MarkerClusterPlugin(),
                          const LocationMarkerPlugin()
                        ],
                        center: LatLng(1.420270, 103.811959),
                        zoom: 10,
                        maxZoom: 19.4,
                        minZoom: 2,
                        maxBounds: LatLngBounds.fromPoints([
                          LatLng(2.150830, 103.361056),
                          LatLng(0.667249, 104.368245)
                        ]),
                      ),
                      nonRotatedChildren: [
                        Container(
                          height: height,
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: isDark
                                ? const Image(
                                    image: AssetImage(
                                        'assets/mapbox-logo-white.png'),
                                    width: 100,
                                  )
                                : const Image(
                                    image: AssetImage(
                                        'assets/mapbox-logo-black.png'),
                                    width: 100,
                                  ),
                          ),
                        ),
                        AttributionWidget(attributionBuilder: ((BuildContext context) {
                          return Container(
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: GestureDetector(
                                child: Icon(Icons.info_outline),
                                onTap: (() => showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return SimpleDialog(
                                        title: Text("Map credits"),
                                        children: [
                                          SimpleDialogOption(
                                            child: TextButton(
                                              onPressed: () => launchUrl(Uri.parse(
                                                  "https://www.mapbox.com/about/maps/"), mode: LaunchMode.externalApplication),
                                              child: Text("© Mapbox"),
                                            ),
                                          ),
                                          SimpleDialogOption(
                                            child: TextButton(
                                              onPressed: () => launchUrl(Uri.parse(
                                                  "https://www.openstreetmap.org/about/"), mode: LaunchMode.externalApplication),
                                              child: Text("© OpenStreetMap"),
                                            ),
                                          ),
                                          SimpleDialogOption(
                                            child: TextButton(
                                              onPressed: () => launchUrl(Uri.parse(
                                                  "https://www.mapbox.com/map-feedback/"), mode: LaunchMode.externalApplication),
                                              child: Text("Improve this map"),
                                            ),
                                          ),
                                        ],
                                      );
                                    })),
                              ),
                            ),
                          );
                        }))
                      ],
                      layers: [
                        TileLayerOptions(
                          maxZoom: 19,
                          urlTemplate: isDark
                              ? "https://api.mapbox.com/styles/v1/slen/cl4p0y50c000a15qhcozehloa/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}"
                              : "https://api.mapbox.com/styles/v1/slen/clb64djkx000014pcw46b1h9m/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
                          additionalOptions: {
                            "access_token": mapboxAccessToken,
                          },
                          userAgentPackageName: 'com.slen.sgbus',
                        ),
                        LocationMarkerLayerOptions(),
                        // MarkerLayerOptions(markers: stops, ),
                        // PolylineLayerOptions(
                        //   polylines: [
                        //     Polyline(
                        //         points: routeAsLatLng,
                        //         color: Colors.blue,
                        //         strokeWidth: 2),
                        //   ],
                        // ),
                        MarkerClusterLayerOptions(
                          markers: stops,
                          maxClusterRadius: 25,
                          onMarkerTap: (e) {
                            openStopByPos(e.point);
                          },
                          builder: (context, markers) {
                            return CircleAvatar(
                              child: Text(markers.length.toString(), style: TextStyle(color: Colors.white),),
                              backgroundColor: Colors.black,
                            );
                          },
                        ),
                      ],
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
