import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart'
    as gl; // Alias for differentiating with Mapbox Position if needed, though Mapbox uses Position w/ lnglat
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewBusLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewTrainLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewWalkLeg.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  List allPointsWL = []; // With Leg info
  List<Point> allPoints = [];

  Map? shownLeg;

  bool startedDirections = false;
  bool trackUserLoc = false;

  StreamSubscription<gl.Position>? gpsStream;
  StreamSubscription? compassStream;

  gl.Position? currLocation; // From Geolocator
  double? currHeading;
  Timer? centerMapTimer;

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Enable Location Component
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
      // puckBearingSource: PuckBearingSource.HEADING, // Commented out due to error
    ));

    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    lineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(marginTop: 45));
    await mapboxMap.attribution
        .updateSettings(AttributionSettings(marginBottom: 30));
    await mapboxMap.logo.updateSettings(LogoSettings(marginBottom: 30));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

    showRouteOnMap();
  }

  Future<void> showRouteOnMap() async {
    List stuffToRender = [];
    allPoints = [];
    widget.route["legs"].forEach((leg) {
      List<Point> pointsList = [];
      decodePolyline(leg["legGeometry"]["points"]).forEach((points) {
        var lat = points[0];
        var lng = points[1];

        pointsList.add(Point(coordinates: Position(lng, lat)));
        allPoints.add(Point(coordinates: Position(lng, lat)));
        allPointsWL.add([Position(lng, lat), leg["legGeometry"]["points"]]);
      });
      stuffToRender.add(
          {"mode": leg["mode"], "points": pointsList, "route": leg["route"]});

      circleManager?.create(
        CircleAnnotationOptions(
          geometry: pointsList.first,
          circleColor: Colors.blue.value,
          circleRadius: 4.0,
          circleSortKey: 2,
        ),
      );
      circleManager?.create(
        CircleAnnotationOptions(
          geometry: pointsList.last,
          circleColor: Colors.blue.value,
          circleRadius: 4.0,
          circleSortKey: 2,
        ),
      );
    });
    for (var x in stuffToRender) {
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
          geometry: LineString(
              coordinates: (x["points"] as List)
                  .map<Position>((e) => e.coordinates)
                  .toList()),
          lineColor: color.value,
          lineSortKey: 3,
          lineWidth: 5,
        ),
      );
    }

    centerMap();
  }

  void centerMap() {
    if (allPoints.isEmpty) return;

    mapboxMap
        ?.cameraForCoordinates(allPoints,
            MbxEdgeInsets(top: 80, left: 30, bottom: 60, right: 30), 10, 0)
        .then((value) {
      mapboxMap?.flyTo(value, MapAnimationOptions(duration: 750));
    });
  }

  ViewportState? _viewport;

  void startRoute() {
    setState(() {
      startedDirections = true;
      trackUserLoc = true;
    });

    // Use Flutter Compass + Geolocator for logic (showing nearest leg)
    // But Mapbox handles the display of Puck.

    // centerMapTimer = Timer.periodic(Duration(milliseconds: 100), updateLoc);

    // compassStream = FlutterCompass.events?.listen((nc) {
    //   currHeading = nc.heading;
    // });

    setState(() {
      _viewport = FollowPuckViewportState(
        zoom: 15.0,
        pitch: 45.0,
        bearing: FollowPuckViewportStateBearingHeading(),
      );
    });

    gpsStream = gl.Geolocator.getPositionStream(
      locationSettings: gl.AndroidSettings(
        intervalDuration: Duration(milliseconds: 10),
      ),
    ).listen((np) {
      currLocation = np;
      showNearestLeg();
    });
  }

  void updateLoc(t) {
    if (trackUserLoc && currLocation != null && currHeading != null) {
      mapboxMap?.easeTo(
        CameraOptions(
          bearing: currHeading,
          center: Point(
              coordinates: Position(currLocation!.longitude,
                  currLocation!.latitude)), // Removed .toJson()
          zoom: 17.5,
          pitch: 45,
        ),
        MapAnimationOptions(duration: 0),
      );
    }
  }

  void showNearestLeg() {
    if (currLocation == null || allPointsWL.isEmpty) return;

    // Logic to find nearest segment
    // allPointsWL is [ [Position(lng,lat), original_encoded_string], ... ]

    List sortedPoints = List.from(allPointsWL);
    sortedPoints.sort((a, b) {
      // a[0] is Position(lng, lat)
      Position pa = a[0];
      Position pb = b[0];
      // measure distance
      var distA = gl.Geolocator.distanceBetween(currLocation!.latitude,
          currLocation!.longitude, pa.lat.toDouble(), pa.lng.toDouble());
      var distB = gl.Geolocator.distanceBetween(currLocation!.latitude,
          currLocation!.longitude, pb.lat.toDouble(), pb.lng.toDouble());
      return distA.compareTo(distB);
    });

    var nearestPointEntry = sortedPoints[0];
    var nearestPolylineString = nearestPointEntry[1];

    widget.route["legs"].forEach((leg) {
      if (leg["legGeometry"]["points"] == nearestPolylineString) {
        // Found the leg.
        if (shownLeg != leg) {
          // Only update if changed
          if (mounted) setState(() => shownLeg = leg);
        }
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    gpsStream?.cancel();
    compassStream?.cancel();
    centerMapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WakelockPlus.enable();
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 400,
        ),
        child: MapWidget(
          viewport: _viewport,
          onScrollListener: (e) {
            // User interacted with map, stop tracking
            if (startedDirections && trackUserLoc) {
              setState(() {
                trackUserLoc = false;
                _viewport = null;
              });
            }
          },
          cameraOptions: CameraOptions(
            center: Point(
                coordinates: Position(103.8198, 1.290270)), // Removed .toJson()
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
                        // Force the map to snap back to the user
                        _viewport = FollowPuckViewportState(
                          zoom: 15.0,
                          pitch: 45.0,
                          bearing: FollowPuckViewportStateBearingHeading(),
                        );
                      });
                    },
                    icon: Icon(Icons.gps_fixed_rounded),
                    label: Text("Recentre"),
                  )
                : FloatingActionButton.extended(
                    onPressed: () {
                      gpsStream?.cancel();
                      compassStream?.cancel();
                      centerMapTimer?.cancel();
                      setState(() {
                        trackUserLoc = false;
                        startedDirections = false;
                        shownLeg = null;
                        _viewport = null;
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

                                      // Fly to leg
                                      List<Point> pts = [];
                                      decodePolyline(
                                              leg["legGeometry"]["points"])
                                          .forEach((p) {
                                        pts.add(Point(
                                            coordinates: Position(p[1], p[0])));
                                      });

                                      mapboxMap
                                          ?.cameraForCoordinates(
                                              pts,
                                              MbxEdgeInsets(
                                                top: 80,
                                                left: 30,
                                                bottom: 60,
                                                right: 30,
                                              ),
                                              10,
                                              0)
                                          .then((value) {
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
