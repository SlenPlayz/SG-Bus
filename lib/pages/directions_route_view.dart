import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewBusLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewTrainLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewWalkLeg.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:wakelock/wakelock.dart';

class DirectionsRouteView extends StatefulWidget {
  const DirectionsRouteView({
    Key? key,
    required this.startName,
    required this.destName,
    required this.route,
  }) : super(key: key);
  final String startName;
  final String destName;
  final Map route;

  @override
  _DirectionsRouteViewState createState() => _DirectionsRouteViewState();
}

class _DirectionsRouteViewState extends State<DirectionsRouteView> {
  MapboxMap? mapboxMap;
  CircleAnnotationManager? circleManager;
  PolylineAnnotationManager? lineManager;

  List allPointsWL = [];
  List allPoints = [];

  Map? shownLeg;

  bool startedDirections = false;
  bool trackUserLoc = false;

  StreamSubscription<gl.Position>? gpsStream;
  StreamSubscription? compassStream;

  gl.Position? currLocation;
  double? currHeading;
  CompassEvent? latestCompassEvent;
  Timer? centerMapTimer;

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    lineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    mapboxMap.location.updateSettings(
      LocationComponentSettings(puckBearingSource: PuckBearingSource.HEADING),
    );
    // await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
    //   // enabled: false,
    //   marginTop:
    //       WidgetsBinding.instance.platformDispatcher.implicitView!.padding.top +
    //           20,
    // ));
    // await mapboxMap.attribution
    //     .updateSettings(AttributionSettings(marginBottom: 85));
    // await mapboxMap.logo.updateSettings(LogoSettings(marginBottom: 85));
    // await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
        // enabled: false,
        marginTop: 45));
    await mapboxMap.attribution
        .updateSettings(AttributionSettings(marginBottom: 30));
    await mapboxMap.logo.updateSettings(LogoSettings(marginBottom: 30));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

    showRouteOnMap();
  }

  void showRouteOnMap() {
    List stuffToRender = [];
    allPoints = [];
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
      stuffToRender.add(
          {"mode": leg["mode"], "points": pointsList, "route": leg["route"]});

      circleManager?.create(
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
      circleManager?.create(
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
        if (x["route"] == "EW" || x["route"] == "CG") {
          color = Colors.green;
        } else if (x["route"] == "DT") {
          color = const Color.fromARGB(255, 26, 112, 183);
        } else if (x["route"] == "NS") {
          color = Colors.red;
        } else if (x["route"] == "CC") {
          color = Colors.yellow;
        } else if (x["route"] == "TE") {
          color = Colors.brown;
        } else if (x["route"] == "NE") {
          color = Color.fromARGB(255, 131, 32, 148);
        } else if (x["route"] == "SE" ||
            x["route"] == "PE" ||
            x["route"] == "BP") {
          color = Colors.grey;
        } else {
          color = Colors.blueGrey;
        }
      }

      await lineManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: x["points"]).toJson(),
          lineColor: color.value,
          lineSortKey: 3,
          lineWidth: 2,
        ),
      );
    });

    centerMap();
  }

  void centerMap() {
    mapboxMap?.cameraForCoordinates(
        [for (var p in allPoints) Point(coordinates: p).toJson()],
        // MbxEdgeInsets(top: 300, left: 150, bottom: 150, right: 150),
        MbxEdgeInsets(top: 80, left: 30, bottom: 60, right: 30),
        10,
        0).then((value) {
      mapboxMap?.flyTo(value, MapAnimationOptions(duration: 750));
    });
  }

  void showNearestLeg() {
    var ldp;
    var ldp2;
    // var _lAllPointsWL = [...allPointsWL];
    if (currLocation != null) {
      allPointsWL.sort((a, b) {
        var distA = gl.Geolocator.distanceBetween(currLocation!.latitude,
            currLocation!.longitude, a[0].latitude, a[0].longitude);
        var distB = gl.Geolocator.distanceBetween(currLocation!.latitude,
            currLocation!.longitude, b[0].latitude, b[0].longitude);
        return distA.compareTo(distB);
      });
      ldp = allPointsWL[0];
      ldp2 = allPointsWL[1];
      // allPointsWL.forEach((e) {
      //   var dist = gl.Geolocator.distanceBetween(currLocation!.latitude,
      //       currLocation!.longitude, e[0].latitude, e[0].longitude);
      //   if (ld == null || dist < ld) {
      //     ld = dist;
      //     ldp = e[1];
      //   }
      //   if (ld == null || dist < ld) {
      //     ld = dist;
      //     ldp = e[1];
      //   }
      // });
    }
    widget.route["legs"].forEach((leg) {
      if (leg["legGeometry"]["points"] == ldp[1]) {
        var lastPoint = decodePolyline(leg["legGeometry"]["points"]).last;
        if (ldp[0].longitude != lastPoint[1] &&
            ldp[0].latitude != lastPoint[0]) {
          if (shownLeg != leg) {
            setState(() {
              shownLeg = leg;
            });
          }
        } else {
          if (widget.route["legs"].indexOf(leg) < widget.route["legs"].length) {
            setState(() {
              shownLeg =
                  widget.route["legs"][widget.route["legs"].indexOf(leg) + 1];
            });
          } else {}
        }
      }
    });
  }

  void startRoute() {
    setState(() {
      startedDirections = true;
      trackUserLoc = true;
    });
    centerMapTimer = Timer.periodic(Duration(milliseconds: 25), updateLoc);
    compassStream = FlutterCompass.events?.listen((nc) {
      currHeading = nc.heading;
      // if (trackUserLoc && oldHead != currHeading && currLocation != null) {
      //   mapboxMap?.easeTo(
      //     CameraOptions(
      //       bearing: nc.heading,
      //       center: Point(
      //         coordinates: currLocation != null
      //             ? Position(currLocation!.longitude, currLocation!.latitude)
      //             : Position(103.8198, 1.290270),
      //       ).toJson(),
      //       zoom: 17.5,
      //       pitch: 45,
      //     ),
      //     MapAnimationOptions(duration: 0),
      //   );
      // }
    });
    gpsStream = gl.Geolocator.getPositionStream(
      locationSettings: gl.AndroidSettings(
        intervalDuration: Duration(milliseconds: 10),
      ),
    ).listen((np) {
      currLocation = np;
      // if (trackUserLoc) {
      //   mapboxMap?.flyTo(
      //     CameraOptions(
      //       // bearing: currHeading ?? 0,
      //       center: Point(
      //         coordinates: Position(np.longitude, np.latitude),
      //       ).toJson(),
      //       zoom: 17.5,
      //       pitch: 45,
      //     ),
      //     MapAnimationOptions(duration: 100),
      //   );
      // }
      showNearestLeg();
    });
  }

  void updateLoc(t) {
    if (trackUserLoc && currLocation != null && currHeading != null) {
      mapboxMap?.easeTo(
        CameraOptions(
          bearing: currHeading,
          center: Point(
            coordinates: currLocation != null
                ? Position(currLocation!.longitude, currLocation!.latitude)
                : Position(103.8198, 1.290270),
          ).toJson(),
          zoom: 17.5,
          pitch: 45,
        ),
        MapAnimationOptions(duration: 0),
      );
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    Wakelock.disable();
    gpsStream?.cancel();
    compassStream?.cancel();
    centerMapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Wakelock.enable();
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 400,
        ),
        child: MapWidget(
          resourceOptions: ResourceOptions(
            accessToken: mapboxAccessToken,
          ),
          onScrollListener: (e) {
            setState(() {
              trackUserLoc = false;
            });
          },
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75),
        child: !startedDirections
            ? FloatingActionButton.extended(
                onPressed: startRoute,
                label: Text("Go"),
                icon: Icon(Icons.directions_rounded),
              )
            : !trackUserLoc
                ? FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        trackUserLoc = true;
                      });
                    },
                    icon: Icon(Icons.gps_fixed_rounded),
                    label: Text("Recentre"),
                  )
                : FloatingActionButton.extended(
                    onPressed: () {
                      gpsStream?.cancel();
                      compassStream?.cancel();
                      setState(() {
                        trackUserLoc = false;
                        startedDirections = false;
                        shownLeg = null;
                      });
                      centerMap();
                    },
                    icon: Icon(Icons.close_rounded),
                    label: Text("End"),
                  ),
      ),
      bottomSheet: BottomSheet(
          onClosing: () {},
          enableDrag: false,
          showDragHandle: false,
          builder: (context) {
            return Container(
              height: 425,
              child: Column(
                children: [
                  ListTile(
                    title: Text(widget.destName),
                    subtitle: Text("From: ${widget.startName}"),
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Container(
                    height: 75,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var leg in widget.route["legs"])
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              onTap: !(shownLeg?["legGeometry"]["points"] ==
                                      leg["legGeometry"]["points"])
                                  ? () {
                                      setState(() {
                                        shownLeg = leg;
                                      });

                                      mapboxMap?.cameraForCoordinates(
                                          [
                                            for (var p in decodePolyline(
                                                leg["legGeometry"]["points"]))
                                              Point(
                                                      coordinates:
                                                          Position(p[1], p[0]))
                                                  .toJson()
                                          ],
                                          // MbxEdgeInsets(
                                          //     top: 300,
                                          //     left: 150,
                                          //     bottom: 150,
                                          //     right: 150),
                                          MbxEdgeInsets(
                                            top: 80,
                                            left: 30,
                                            bottom: 60,
                                            right: 30,
                                          ),
                                          10,
                                          0).then((value) {
                                        mapboxMap?.flyTo(
                                            value,
                                            MapAnimationOptions(
                                                duration: 1000));
                                      });
                                    }
                                  : () {
                                      if (!startedDirections) {
                                        setState(() => shownLeg = null);
                                        centerMap();
                                      }
                                    },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  // color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                  color: shownLeg?["legGeometry"]["points"] ==
                                          leg["legGeometry"]["points"]
                                      ? Theme.of(context).colorScheme.surface
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant
                                          .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.fromLTRB(3, 8, 15, 8),
                                child: leg["mode"] == "WALK"
                                    ? DirectionsRouteViewWalkChip(leg: leg)
                                    : leg["mode"] == "BUS"
                                        ? DirectionsRouteViewBusChip(leg: leg)
                                        : leg["mode"] == "SUBWAY"
                                            ? DirectionsRouteViewTrainChip(
                                                leg: leg)
                                            : Container(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  shownLeg != null
                      ? (shownLeg?["mode"]) == "WALK"
                          ? DirectionsRouteViewWalkLeg(
                              leg: shownLeg!,
                              nextLeg: widget.route["legs"].indexOf(shownLeg) !=
                                      widget.route["legs"].length - 1
                                  ? widget.route["legs"][
                                      widget.route["legs"].indexOf(shownLeg) +
                                          1]
                                  : null,
                            )
                          : (shownLeg?["mode"]) == "BUS"
                              ? DirectionsRouteViewBusLeg(
                                  leg: shownLeg!,
                                  startedRouting: startedDirections,
                                )
                              : (shownLeg?["mode"]) == "SUBWAY"
                                  ? DirectionsRouteViewTrainLeg(
                                      leg: shownLeg!,
                                      startedRouting: startedDirections,
                                    )
                                  : Container()
                      : Expanded(
                          child: Center(
                            child: startedDirections
                                ? CircularProgressIndicator()
                                : Text("Click on a chip to view more info"),
                          ),
                        )
                ],
              ),
            );
          }),
    );
  }
}

class DirectionsRouteViewBusChip extends StatelessWidget {
  const DirectionsRouteViewBusChip({Key? key, required this.leg})
      : super(key: key);
  final leg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.directions_bus_filled_rounded),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Bus " + leg["route"]),
            Text(
              leg["intermediateStops"] != null
                  ? (leg["intermediateStops"].length + 1).toString() + " stops"
                  : (leg["duration"] / 60).round().toString() + " min",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ],
        )
      ],
    );
  }
}

class DirectionsRouteViewTrainChip extends StatelessWidget {
  const DirectionsRouteViewTrainChip({Key? key, required this.leg})
      : super(key: key);
  final leg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.directions_transit_filled_rounded),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(leg["route"] + " line"),
            Text(
              leg["intermediateStops"] != null
                  ? (leg["intermediateStops"].length + 1).toString() + " stops"
                  : (leg["duration"] / 60).round().toString() + " min",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ],
        )
      ],
    );
  }
}

class DirectionsRouteViewWalkChip extends StatelessWidget {
  const DirectionsRouteViewWalkChip({Key? key, required this.leg})
      : super(key: key);
  final leg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.directions_walk_rounded),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Walk"),
            Text(
              (leg["distance"] / 1000).toStringAsFixed(1) + "km",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
          ],
        )
      ],
    );
  }
}
