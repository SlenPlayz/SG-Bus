import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class StopsMap extends StatefulWidget {
  const StopsMap({Key? key}) : super(key: key);
  // final updatePos;

  @override
  _StopsMapState createState() => _StopsMapState();
}

class _StopsMapState extends State<StopsMap> {
  bool isLoaded = false;
  bool error = false;
  int errorCode = 0;
  String errorMsg = '';
  var currLocation;
  var mapController = MapController();
  List<Marker> stops = [];
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Future<void> requestGPSPermission() async {
    await Geolocator.requestPermission();
    initMap();
  }

  Future<void> enableGPSInSettings() async {
    await Geolocator.openLocationSettings();
    initMap();
  }

  Future<Position> getLocation() async {
    // Check if GPS is enabled
    bool isGPSEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGPSEnabled) {
      error = true;
      errorMsg = 'GPS is disabled';
      errorCode = 1;
      return Future.error(errorMsg);
    }

    //Check is GPS Permission is given
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      error = true;
      errorMsg = 'GPS Permissions not given';
      errorCode = 2;
      return Future.error(errorMsg);
    }

    //Check if GPS permissions are permenents denied
    if (permission == LocationPermission.deniedForever) {
      error = true;
      errorMsg = 'GPS Permissions are denied';
      errorCode = 3;
      return Future.error(errorMsg);
    }

    currLocation = await Geolocator.getCurrentPosition();
    setState(() {
      currLocation = currLocation;
    });

    return currLocation;
  }

  Future<void> initStops() async {
    List data = getStops();

    for (var element in data) {
      stops.add(Marker(
        point: LatLng(element["cords"][1], element["cords"][0]),
        builder: (context) => const CircleAvatar(
          child: Icon(Icons.directions_bus),
        ),
      ));
    }
    setState(() {
      stops = stops;
    });
  }

  Future<void> initMap() async {
    isLoaded = false;
    getLocation().then((postion) {
      setState(() {
        isLoaded = true;
      });
      if (LatLngBounds.fromPoints(
              [LatLng(2.150830, 103.361056), LatLng(0.667249, 104.368245)])
          .contains(LatLng(postion.latitude, postion.longitude))) {
        mapController.onReady.then((value) => mapController.move(
            LatLng(postion.latitude, postion.longitude), 18));
      }
    }).catchError((err) {
      setState(() {
        isLoaded = true;
      });
    });
    // setState(() {
    //   isLoaded = true;
    // });
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

  @override
  void initState() {
    super.initState();
    initStops();
    initMap();
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: isLoaded
          ? Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () async {
                  getLocation().then((position) {
                    if (LatLngBounds.fromPoints([
                      LatLng(2.150830, 103.361056),
                      LatLng(0.667249, 104.368245)
                    ]).contains(
                        LatLng(position.latitude, position.longitude))) {
                      mapController.move(
                          LatLng(position.latitude, position.longitude), 18);
                    } else {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              icon: Icon(Icons.warning),
                              title: Text('Unable to move to current location'),
                              content: Text(
                                  "Seems like you aren't in SG. Sorry but the map can only show places in singapore."),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Dismiss'))
                              ],
                            );
                          });
                    }
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
                                          child:
                                              const Text('Request permission'))
                                      : (errorCode == 2)
                                          ? TextButton(
                                              onPressed: () {
                                                enableGPSInSettings();
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text(
                                                  'Request permission'))
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
              body: FlutterMap(
                mapController: mapController,
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
                      child: isDarkMode
                          ? const Image(
                              image: AssetImage('assets/mapbox-logo-white.png'),
                              width: 100,
                            )
                          : const Image(
                              image: AssetImage('assets/mapbox-logo-black.png'),
                              width: 100,
                            ),
                    ),
                  ),
                ],
                layers: [
                  TileLayerOptions(
                    maxZoom: 19,
                    urlTemplate: isDarkMode
                        ? "https://api.mapbox.com/styles/v1/slen/cl4p0y50c000a15qhcozehloa/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}"
                        : "https://api.mapbox.com/styles/v1/slen/clb64djkx000014pcw46b1h9m/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
                    additionalOptions: {
                      "access_token": mapboxAccessToken,
                    },
                    userAgentPackageName: 'com.slen.sgbus',
                  ),
                  LocationMarkerLayerOptions(),
                  MarkerClusterLayerOptions(
                    markers: stops,
                    onMarkerTap: (e) {
                      openStopByPos(e.point);
                    },
                    builder: (context, markers) {
                      return CircleAvatar(
                        child: Text(markers.length.toString()),
                      );
                    },
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
