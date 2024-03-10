import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart' as net;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/directionSearchDelegate.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class PlacePage extends StatefulWidget {
  const PlacePage({Key? key, required this.placeData}) : super(key: key);
  final placeData;

  @override
  _PlacePageState createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  bool startPointLoaded = false;
  bool destinationLoaded = false;
  var destPlaceData;

  int bsState = 0;

  List routes = [];

  Map startingData = {"name": "Your location", "ul": true};

  LatLng? destCoords;
  LatLng? startingCoords;

  var startingSessID;
  var destSessID;

  var GPSError;
  var GPSErrorMsg;
  var GPSErrorCode;

  var currLocation;

  String directionsMode = "pt";
  Object? ptMode = "TRANSIT";
  TimeOfDay departureTime = TimeOfDay.now();

  bool isRoutesLoading = true;
  bool routeError = false;
  bool noRoutes = false;
  String routesErrMsg = "";

  var routeToView;

  int mapLocState = 0;
  Stream<gl.Position> gpsStream = gl.Geolocator.getPositionStream();
  bool trackLoc = false;
  bool mapOnPos = false;

  MapboxMap? mapboxMap;
  CircleAnnotationManager? circleManager;
  PolylineAnnotationManager? lineManager;

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    lineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
      // enabled: false,
      marginTop:
          WidgetsBinding.instance.platformDispatcher.implicitView!.padding.top +
              20,
    ));
    await mapboxMap.attribution
        .updateSettings(AttributionSettings(marginBottom: 85));
    await mapboxMap.logo.updateSettings(LogoSettings(marginBottom: 85));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
  }

  @override
  void initState() {
    destPlaceData = widget.placeData["data"];
    destSessID = widget.placeData["sessID"];
    getStartingInfo();
    getDestinationInfo();
    super.initState();
  }

  Future<void> getDestinationInfo() async {
    setState(() {
      destinationLoaded = false;
    });
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/search/searchbox/v1/retrieve/${destPlaceData["mapbox_id"]}?access_token=${mapboxAccessToken}&session_token=${destSessID}');
      net.Response results = await net.get(url).timeout(Duration(seconds: 45));

      var response = jsonDecode(results.body);

      destCoords = LatLng(response["features"][0]["geometry"]["coordinates"][1],
          response["features"][0]["geometry"]["coordinates"][0]);
      setState(() {
        destinationLoaded = true;
      });
      showPointsonMap();
    } catch (err) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(err.toString()),
              ));
    }
  }

  Future<void> getStartingInfo() async {
    if (startingData["ul"] != null && startingData["ul"] == true) {
      getLocation().then((location) {
        startingCoords = LatLng(location.latitude, location.longitude);
        setState(() {
          startPointLoaded = true;
        });
        showPointsonMap();
      }).catchError((err) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  icon: Icon(Icons.warning),
                  title: Text(GPSErrorMsg),
                ));
      });
    } else {
      setState(() {
        startPointLoaded = false;
      });
      try {
        final url = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/retrieve/${startingData["mapbox_id"]}?access_token=${mapboxAccessToken}&session_token=${startingSessID}');
        net.Response results =
            await net.get(url).timeout(Duration(seconds: 45));

        var response = jsonDecode(results.body);

        startingCoords = LatLng(
            response["features"][0]["geometry"]["coordinates"][1],
            response["features"][0]["geometry"]["coordinates"][0]);
        setState(() {
          startPointLoaded = true;
        });
        showPointsonMap();
      } catch (err) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(err.toString()),
                ));
      }
    }
  }

  void showPointsonMap() {
    if (lineManager != null) {
      lineManager!.deleteAll();
    }

    if (circleManager != null) {
      circleManager!.deleteAll();
    }

    if (startPointLoaded && destinationLoaded) {
      List<Position> coords = [
        Position(startingCoords!.longitude, startingCoords!.latitude),
        Position(destCoords!.longitude, destCoords!.latitude),
      ];

      circleManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: coords[0],
          ).toJson(),
          circleColor: Colors.blue.value,
          circleRadius: 8.0,
          circleStrokeColor: Colors.blueGrey.value,
          circleStrokeWidth: 2,
          circleSortKey: 2,
        ),
      );
      circleManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: coords[1],
          ).toJson(),
          circleColor: Colors.blue.value,
          circleRadius: 8.0,
          circleStrokeColor: Colors.blueGrey.value,
          circleStrokeWidth: 2,
          circleSortKey: 2,
        ),
      );

      lineManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords).toJson(),
          lineColor: Colors.grey.value,
          // linePattern: "dot-11", // Mapbox stops rendering all future non-patterned lines if present
          lineWidth: 2,
          lineSortKey: 1,
        ),
      );

      mapboxMap?.cameraForCoordinates(
          [
            Point(
              coordinates: coords[0],
            ).toJson(),
            Point(
              coordinates: coords[1],
            ).toJson()
          ],
          MbxEdgeInsets(
              top: bsState == 0 ? 500 : 300,
              left: 150,
              bottom: bsState == 0 ? 500 : 150,
              right: 150),
          10,
          0).then((value) {
        mapboxMap?.flyTo(value, MapAnimationOptions(duration: 2));
      });
    }
  }

  Future<gl.Position> getLocation() async {
    // Check if GPS is enabled
    bool isGPSEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!isGPSEnabled) {
      GPSError = true;
      GPSErrorMsg = 'GPS is disabled';
      GPSErrorCode = 1;
      return Future.error(GPSErrorMsg);
    }

    //Check is GPS Permission is given
    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      GPSError = true;
      GPSErrorMsg = 'GPS Permissions not given';
      GPSErrorCode = 2;
      return Future.error(GPSErrorMsg);
    }

    //Check if GPS permissions are permenents denied
    if (permission == gl.LocationPermission.deniedForever) {
      GPSError = true;
      GPSErrorMsg = 'GPS Permissions are denied';
      GPSErrorCode = 3;
      return Future.error(GPSErrorMsg);
    }

    currLocation = await gl.Geolocator.getCurrentPosition();
    setState(() {
      currLocation = currLocation;
    });

    return currLocation;
  }

  Future<void> getRoutes() async {
    setState(() {
      isRoutesLoading = true;
      routeError = false;
      noRoutes = false;
    });

    try {
      net.Response tokRes = await net.post(
        Uri.parse('https://www.onemap.gov.sg/api/auth/post/getToken'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            <String, String>{"email": oneMapEmail, "password": oneMapPassword}),
      );

      var tokResJSON = jsonDecode(tokRes.body);

      String oneMapToken = tokResJSON["access_token"];

      String date = DateFormat('MM-dd-yyyy').format(DateTime.now());

      final url = Uri.parse(
          'https://www.onemap.gov.sg/api/public/routingsvc/route?start=${startingCoords!.latitude},${startingCoords!.longitude}&end=${destCoords!.latitude},${destCoords!.longitude}&routeType=pt&date=${date}&time=${departureTime.hour}:${departureTime.minute}:00&mode=${ptMode}&maxWalkDistance=1000&numItineraries=3');

      net.Response results = await net.get(url, headers: {
        "Authorization": oneMapToken
      }).timeout(Duration(seconds: 45));

      var resPar = jsonDecode(results.body);

      if (resPar["plan"] == null) {
        if (resPar["status"] == "error") {
          if (resPar["message"].contains("NOT FOUND")) {
            setState(() {
              routeError = true;
              routesErrMsg = "No Routes found";
              isRoutesLoading = false;
            });
          } else {
            setState(() {
              routeError = true;
              routesErrMsg = resPar["message"];
              isRoutesLoading = false;
            });
          }
        }
        return;
      }

      routes = resPar["plan"]["itineraries"];

      for (var i = 0; i < routes.length; i++) {
        var r = routes[i];
        routes[i]["legsWidgets"] = [];

        r["legs"].forEach((leg) {
          // print(leg["mode"]);
          if (leg["mode"] == "WALK") {
            int dur = 0;
            dur = ((leg["endTime"] - leg["startTime"]) / 1000 / 60).round();

            routes[i]["legsWidgets"].add(DirectionsWalkDisplayWidget(
              duration: dur,
            ));
          }
          if (leg["mode"] == "BUS") {
            routes[i]["legsWidgets"]
                .add(DirectionsBusNumberDisplayWidget(serviceNo: leg["route"]));
          }
          if (leg["mode"] == "SUBWAY") {
            routes[i]["legsWidgets"]
                .add(DirectionsRailRouteDisplayWidget(line: leg["route"]));
          }
        });
      }
    } catch (err) {
      setState(() {
        routeError = true;
        routesErrMsg = err.toString();
      });
    }

    setState(() {
      isRoutesLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: bsState == 0,
      onPopInvoked: (e) {
        if (bsState != 0) {
          if (bsState == 2) {
            showPointsonMap();
            // gpsStream?.cancel();
          }
          setState(() {
            bsState = bsState - 1;
            trackLoc = false;
          });
        }
      },
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.only(
              bottom: (bsState == 0)
                  ? 225
                  : (bsState == 1 || bsState == 2)
                      ? 400
                      : 225),
          child: MapWidget(
            resourceOptions: ResourceOptions(
              accessToken: mapboxAccessToken,
            ),
            onScrollListener: (a) => setState(() {
              trackLoc = false;
              mapLocState = 0;
            }),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(103.8198, 1.290270)).toJson(),
              zoom: 9,
            ),
            onMapCreated: _onMapCreated,
            styleUri: isDark
                ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
                : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m",
          ),
        ),
        floatingActionButton: bsState == 0
            ? FloatingActionButton.extended(
                onPressed: (destinationLoaded && startPointLoaded)
                    ? () {
                        setState(() {
                          bsState = 1;
                        });
                        getRoutes();
                        departureTime = TimeOfDay.now();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          showPointsonMap();
                        });
                      }
                    : null,
                icon: Icon(Icons.directions),
                label: (destinationLoaded && startPointLoaded)
                    ? Text("Get Directions")
                    : Text("Getting data..."),
              )
            : bsState == 2 && startingData["ul"] != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 75),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (mapLocState == 0) {
                          // gpsStream?.cancel();

                          setState(() {
                            mapLocState = 1;
                          });
                          getLocation().then((position) {
                            mapboxMap?.flyTo(
                                CameraOptions(
                                  anchor: ScreenCoordinate(x: 0, y: 0),
                                  zoom: 17,
                                  center: Point(
                                    coordinates: Position(
                                        position.longitude, position.latitude),
                                  ).toJson(),
                                ),
                                MapAnimationOptions(
                                  duration: 2000,
                                  startDelay: 0,
                                ));
                          });
                        } else if (mapLocState == 1) {
                          setState(() {
                            mapLocState = 2;
                            trackLoc = true;
                          });

                          if (!trackLoc) {
                            // gpsStream.;
                            setState(() {
                              trackLoc = false;
                              mapLocState = 0;
                            });
                          }
                          gpsStream.listen((np) {
                            if (trackLoc) {
                              mapboxMap?.flyTo(
                                  CameraOptions(
                                    anchor: ScreenCoordinate(x: 0, y: 0),
                                    zoom: 17,
                                    bearing: np.heading,
                                    center: Point(
                                      coordinates:
                                          Position(np.longitude, np.latitude),
                                    ).toJson(),
                                  ),
                                  MapAnimationOptions(
                                    duration: 100,
                                    startDelay: 0,
                                  ));
                            }
                          });
                        } else if (mapLocState == 2) {
                          setState(() {
                            mapLocState = 0;
                            trackLoc = false;
                          });

                          List<Position> coords = [
                            Position(startingCoords!.longitude,
                                startingCoords!.latitude),
                            Position(
                                destCoords!.longitude, destCoords!.latitude),
                          ];

                          mapboxMap?.cameraForCoordinates(
                              [
                                Point(
                                  coordinates: coords[0],
                                ).toJson(),
                                Point(
                                  coordinates: coords[1],
                                ).toJson()
                              ],
                              MbxEdgeInsets(
                                  top: bsState == 0 ? 500 : 300,
                                  left: 150,
                                  bottom: bsState == 0 ? 500 : 150,
                                  right: 150),
                              10,
                              0).then((value) {
                            mapboxMap?.flyTo(
                                value, MapAnimationOptions(duration: 1000));
                          });
                        }
                      },
                      child: mapLocState == 0
                          ? Icon(Icons.gps_not_fixed_rounded)
                          : mapLocState == 1
                              ? Icon(Icons.gps_fixed_rounded)
                              : Icon(Icons.gps_fixed_rounded,
                                  color: mapLocState == 2
                                      ? Theme.of(context).colorScheme.primary
                                      : null),
                    ),
                  )
                : null,
        bottomSheet: BottomSheet(
          onClosing: () {},
          builder: (context) {
            if (bsState == 0) {
              return Container(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                  child: Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: () async {
                            var res = await showSearch(
                              context: context,
                              delegate: DSearchDelegate(showLoc: true),
                            );

                            if (res != null) {
                              startingData = res["data"];
                              startingSessID = res["sessID"];
                              getStartingInfo();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Skeletonizer(
                              enabled: !startPointLoaded,
                              child: ListTile(
                                title: Text(startingData["name"]),
                                subtitle: Text("Starting Point"),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            var res = await showSearch(
                              context: context,
                              delegate: DSearchDelegate(showLoc: false),
                            );

                            if (res != null) {
                              destPlaceData = res["data"];
                              destSessID = res["sessID"];
                              getDestinationInfo();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Skeletonizer(
                              enabled: !destinationLoaded,
                              child: ListTile(
                                title: Text(destPlaceData['name']),
                                subtitle: Text("Destination"),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 10, left: 5),
                              child: Text(
                                "Mode:",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                              ),
                            ),
                            DropdownButton(
                              // width: 170,
                              // textStyle: TextStyle(fontSize: 12),
                              // initialSelection: "pt",
                              // label: Text("Mode"),
                              // dropdownMenuEntries: [
                              //   DropdownMenuEntry(value: "walk", label: "Walking"),
                              //   DropdownMenuEntry(
                              //       value: "pt", label: "Public Transport"),
                              // ],
                              onChanged: (String? value) =>
                                  setState(() => directionsMode = value!),
                              underline: Container(),
                              value: directionsMode,
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              items: [
                                DropdownMenuItem(
                                  child: Text("Walk (Coming Soon)"),
                                  value: "walk",
                                  enabled: false,
                                ),
                                DropdownMenuItem(
                                  child: Text("Public Transport"),
                                  value: "pt",
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            }
            if (bsState == 1) {
              return Container(
                height: 425,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        destPlaceData["name"],
                      ),
                      subtitle: Text("From: " + startingData["name"]),
                    ),
                    directionsMode == "pt"
                        ? Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Options: ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)),
                                SegmentedButton(
                                  segments: [
                                    ButtonSegment(
                                      value: "TRANSIT",
                                      label: Text("Both"),
                                      icon: Icon(Icons.route_rounded),
                                    ),
                                    ButtonSegment(
                                      value: "BUS",
                                      label: Text("Bus"),
                                      icon: Icon(
                                          Icons.directions_bus_filled_rounded),
                                    ),
                                    ButtonSegment(
                                      value: "RAIL",
                                      label: Text("MRT"),
                                      icon: Icon(
                                          Icons.directions_transit_rounded),
                                    ),
                                  ],
                                  selected: {ptMode},
                                  onSelectionChanged: (mode) {
                                    setState(() {
                                      ptMode = mode.first;
                                    });
                                    getRoutes();
                                  },
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        : Container(),
                    directionsMode == "pt"
                        ? Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  TimeOfDay? res = await showTimePicker(
                                    context: context,
                                    initialTime: departureTime,
                                  );
                                  if (res != null) {
                                    setState(() {
                                      departureTime = res;
                                    });
                                    getRoutes();
                                  }
                                },
                                child: Text("Departs at: " +
                                    departureTime.format(context)),
                              ),
                            ],
                          )
                        : Container(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Skeletonizer(
                            enabled: isRoutesLoading,
                            child: Column(
                              children: [
                                if (routeError)
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.warning_rounded),
                                          Text(routesErrMsg),
                                          TextButton.icon(
                                              onPressed: getRoutes,
                                              icon: Icon(Icons.refresh_rounded),
                                              label: Text("Retry"))
                                        ],
                                      ),
                                    ),
                                  ),
                                if (isRoutesLoading)
                                  ListTile(
                                    // title: Row(
                                    //   children: [
                                    //     DirectionsBusNumberDisplayWidget(),
                                    //     Icon(Icons.navigate_next),
                                    //     DirectionsWalkDisplayWidget(),
                                    //     Icon(Icons.navigate_next),
                                    //     Text("...")
                                    //   ],
                                    // ),
                                    title: Text("Loading..."),
                                    subtitle: Text("??:?? to ??:??"),
                                    trailing: Text("?? mins"),
                                    onTap: () {},
                                  ),
                                if (isRoutesLoading)
                                  ListTile(
                                    title: Text("Loading...."),
                                    subtitle: Text("??:?? to ??:??"),
                                    trailing: Text("?? mins"),
                                    onTap: () {},
                                  ),
                                if (isRoutesLoading)
                                  ListTile(
                                    title: Text("Loading"),
                                    subtitle: Text("??:?? to ??:??"),
                                    trailing: Text("?? mins"),
                                    onTap: () {},
                                  ),
                                if (!isRoutesLoading && !routeError)
                                  for (var r in routes)
                                    ListTile(
                                      title: Row(
                                        children: [
                                          for (var i in r["legsWidgets"])
                                            Row(
                                              children: [
                                                if (r["legsWidgets"]
                                                        .indexOf(i) <
                                                    3)
                                                  Row(
                                                    children: [
                                                      i,
                                                      r["legsWidgets"]
                                                                  .indexOf(i) !=
                                                              r["legsWidgets"]
                                                                      .length -
                                                                  1
                                                          ? Icon(Icons
                                                              .navigate_next)
                                                          : Container(),
                                                    ],
                                                  ),
                                                if (r["legsWidgets"]
                                                        .indexOf(i) ==
                                                    3)
                                                  Text("...")
                                              ],
                                            )
                                        ],
                                      ),
                                      subtitle: Text(DateFormat('hh:mm').format(
                                              DateTime
                                                  .fromMillisecondsSinceEpoch(
                                                      r["startTime"])) +
                                          " to " +
                                          DateFormat('hh:mm').format(DateTime
                                              .fromMillisecondsSinceEpoch(
                                                  r["endTime"]))),
                                      trailing: Text((r["duration"] / 60)
                                              .round()
                                              .toString() +
                                          "min"),
                                      onTap: () {
                                        if (lineManager != null) {
                                          lineManager!.deleteAll();
                                        }

                                        if (circleManager != null) {
                                          circleManager!.deleteAll();
                                        }
                                        setState(() {
                                          routeToView = r;
                                          bsState = 2;
                                        });
                                      },
                                    )
                              ],
                            ),
                          )),
                    )
                  ],
                ),
              );
            }
            if (bsState == 2) {
              return RouteViewSheet(
                route: routeToView,
                gpsStream: gpsStream,
                back: () {
                  showPointsonMap();
                  setState(() {
                    bsState = 1;
                    // gpsStream?.cancel();
                    trackLoc = false;
                  });
                },
                startName: startingData["name"],
                endName: destPlaceData["name"],
                mapController: mapboxMap,
                lineManager: lineManager,
                circleManager: circleManager,
              );
            } else {}
            return Container(
                child: Center(child: Text("An unknown error occured")));
          },
        ),
      ),
    );
  }
}

class DirectionsWalkDisplayWidget extends StatelessWidget {
  const DirectionsWalkDisplayWidget({
    super.key,
    this.duration,
  });

  final duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.directions_walk_rounded),
        Text(
          duration.toString(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class DirectionsBusNumberDisplayWidget extends StatelessWidget {
  const DirectionsBusNumberDisplayWidget({
    super.key,
    required this.serviceNo,
  });

  final serviceNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Icon(Icons.directions_bus_filled_rounded, size: 13),
          Text(serviceNo, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      padding: EdgeInsets.fromLTRB(4, 1.5, 4, 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
    );
  }
}

class DirectionsRailRouteDisplayWidget extends StatelessWidget {
  const DirectionsRailRouteDisplayWidget({
    super.key,
    required this.line,
  });

  final line;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Icon(Icons.directions_transit_filled_rounded, size: 13),
          Text(line, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      padding: EdgeInsets.fromLTRB(4, 1.5, 4, 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
    );
  }
}

class RouteViewSheet extends StatefulWidget {
  const RouteViewSheet({
    Key? key,
    required this.route,
    required this.startName,
    required this.endName,
    required this.back,
    required this.mapController,
    required this.lineManager,
    required this.circleManager,
    required this.gpsStream,
  }) : super(key: key);
  final route;
  final startName;
  final endName;
  final back;
  final MapboxMap? mapController;
  final PolylineAnnotationManager? lineManager;
  final CircleAnnotationManager? circleManager;
  final Stream<gl.Position> gpsStream;

  @override
  _RouteViewSheetState createState() => _RouteViewSheetState();
}

class _RouteViewSheetState extends State<RouteViewSheet> {
  List<List> allPointsWL = [];
  String nearestLegID = "";

  StreamSubscription? locStreamLocal;

  String getStopName(id) {
    try {
      var res = getStopByID(id)["Name"];
      return res;
    } catch (e) {
      return ("a");
    }
  }

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }

  String legTitleGen(leg) {
    if (leg["mode"] == "WALK") {
      var dist = leg["distance"].round();
      var dest =
          ((leg["to"]["stopCode"]) != null && isNumeric(leg["to"]["stopCode"]))
              ? getStopName(leg["to"]["stopCode"])
              : leg["to"]["name"].toString().capitalize();
      return "Walk to ${dest}";
    }
    if (leg["mode"] == "BUS") {
      var dist = leg["distance"].round();
      var dest =
          ((leg["to"]["stopCode"]) != null && isNumeric(leg["to"]["stopCode"]))
              ? getStopName(leg["to"]["stopCode"])
              : leg["to"]["name"].toString().capitalize();
      return "Take bus ${leg["route"]} to ${dest}";
    }
    if (leg["mode"] == "SUBWAY") {
      var dist = leg["distance"].round();
      var dest =
          ((leg["to"]["stopCode"]) != null && isNumeric(leg["to"]["stopCode"]))
              ? getStopName(leg["to"]["stopCode"])
              : leg["to"]["name"].toString().capitalize();
      return "Take the ${leg["route"]} line to ${dest}";
    }

    return "";
  }

  @override
  void initState() {
    mapStuff();
    widget.gpsStream.listen((np) {
      var oldLowestDist;
      var nearestLegID;

      allPointsWL.forEach((x) {
        if (oldLowestDist == null ||
            gl.Geolocator.distanceBetween(
                    x[0].latitude, x[0].longitude, np.latitude, np.longitude) <
                oldLowestDist) {
          // print(gl.Geolocator.distanceBetween(
          //         x[0].latitude, x[0].longitude, np.latitude, np.longitude)
          //     .toString());
          setState(() {
            nearestLegID = x[1];
          });
        }
      });
      print(nearestLegID);
    });
    super.initState();
  }

  @override
  void dispose() {
    locStreamLocal?.cancel();
    super.dispose();
  }

  void mapStuff() {
    List stuffToRender = [];
    List allPoints = [];
    widget.route["legs"].forEach((leg) {
      List<Position> pointsList = [];
      decodePolyline(leg["legGeometry"]["points"]).forEach((points) {
        pointsList.add(Position(points[1], points[0]));
        allPoints.add(Position(points[1], points[0]));
        allPointsWL.add([
          LatLng(points[0].toDouble(), points[1].toDouble()),
          leg["legGeometry"]["points"]
        ]);
      });
      stuffToRender.add({"mode": leg["mode"], "points": pointsList});

      widget.circleManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: pointsList.first,
          ).toJson(),
          circleColor: Colors.blue.value,
          circleRadius: 4.0,
          // circleStrokeColor: Colors.blue.value,
          // circleStrokeWidth: 2,
          circleSortKey: 2,
        ),
      );
      widget.circleManager?.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: pointsList.last,
          ).toJson(),
          circleColor: Colors.blue.value,
          circleRadius: 4.0,
          // circleStrokeColor: Colors.blue.value,
          // circleStrokeWidth: 2,
          circleSortKey: 2,
        ),
      );
    });
    stuffToRender.forEach((x) async {
      Color color = Colors.black;
      if (x["mode"] == "WALK") {
        color = Colors.grey;
      }
      if (x["mode"] == "BUS") {
        color = Colors.blue;
      }
      if (x["mode"] == "SUBWAY") {
        color = Colors.green;
      }

      await widget.lineManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: x["points"]).toJson(),
          lineColor: color.value,
          lineSortKey: 3,
          lineWidth: 2,
        ),
      );
    });

    widget.mapController?.cameraForCoordinates(
        [for (var p in allPoints) Point(coordinates: p).toJson()],
        MbxEdgeInsets(top: 300, left: 150, bottom: 150, right: 150),
        10,
        0).then((value) {
      widget.mapController?.flyTo(value, MapAnimationOptions(duration: 2));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route == null) {
      return Container(
        height: 425,
        child: Center(
          child: Text("An Error Occured"),
        ),
      );
    }
    return Container(
      height: 425,
      child: Column(
        children: [
          ListTile(
            title: Text(widget.endName),
            subtitle: Text("From: ${widget.startName}"),
            leading: IconButton(
                onPressed: widget.back, icon: Icon(Icons.navigate_before)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                children: [
                  for (var i in widget.route["legsWidgets"])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        i,
                        widget.route["legsWidgets"].indexOf(i) !=
                                widget.route["legsWidgets"].length - 1
                            ? Icon(Icons.navigate_next)
                            : Container()
                      ],
                    )
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Text(widget.route.toString()),
                for (var leg in widget.route["legs"])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Icon(
                          leg["mode"] == "WALK"
                              ? Icons.directions_walk_rounded
                              : leg["mode"] == "BUS"
                                  ? Icons.directions_bus_rounded
                                  : leg["mode"] == "SUBWAY"
                                      ? Icons.directions_transit_rounded
                                      : Icons.route_rounded,
                          color: leg["legGeometry"]["points"] == nearestLegID
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(legTitleGen(leg)),
                        subtitle: Text(
                            ((leg["endTime"] - leg["startTime"]) / 60000)
                                    .round()
                                    .toString() +
                                " mins"),
                        trailing: Text(
                            "${(leg["distance"] / 1000).toStringAsFixed(1)}km"),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
