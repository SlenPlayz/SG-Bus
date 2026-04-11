import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart'
    as gl; // Alias for differentiating with Mapbox Position if needed, though Mapbox uses Position w/ lnglat
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewBusLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewTrainLeg.dart';
import 'package:sgbus/components/directions/DirectionsRouteViewWalkLeg.dart';
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
  bool hasArrived = false;

  StreamSubscription<gl.Position>? gpsStream;
  StreamSubscription? compassStream;

  gl.Position? currLocation; // From Geolocator
  double? currHeading;
  Timer? centerMapTimer;
  Timer? elapsedTimer;
  DateTime? tripStartTime;
  Duration tripElapsed = Duration.zero;

  // Destination coordinates extracted from last leg's last polyline point
  Position? destPosition;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

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

    // Extract destination coordinates from the last polyline point
    if (allPoints.isNotEmpty) {
      destPosition = allPoints.last.coordinates;
    }

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
    // Haptic feedback on start
    HapticFeedback.mediumImpact();

    setState(() {
      startedDirections = true;
      trackUserLoc = true;
      hasArrived = false;
      tripStartTime = DateTime.now();
      tripElapsed = Duration.zero;
      // Auto-select first leg
      if (widget.route["legs"] != null &&
          (widget.route["legs"] as List).isNotEmpty) {
        shownLeg = widget.route["legs"][0];
      }
    });

    // Start elapsed timer
    elapsedTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (tripStartTime != null && mounted) {
        setState(() {
          tripElapsed = DateTime.now().difference(tripStartTime!);
        });
      }
    });

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
      checkArrival();
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

  void checkArrival() {
    if (!startedDirections || hasArrived || currLocation == null || destPosition == null) return;

    double dist = gl.Geolocator.distanceBetween(
      currLocation!.latitude,
      currLocation!.longitude,
      destPosition!.lat.toDouble(),
      destPosition!.lng.toDouble(),
    );

    if (dist < 50) {
      setState(() {
        hasArrived = true;
      });

      // Stop tracking
      gpsStream?.cancel();
      compassStream?.cancel();
      elapsedTimer?.cancel();
      centerMapTimer?.cancel();
      WakelockPlus.disable();

      HapticFeedback.heavyImpact();

      // Show arrival dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.celebration_rounded, size: 48, color: Theme.of(ctx).colorScheme.primary),
          title: Text("You've arrived!"),
          content: Text(
            "Welcome to ${widget.destName}\n\nTrip took ${_formatDuration(tripElapsed)}",
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text("Done"),
            ),
          ],
        ),
      );
    }
  }

  void _showEndTripConfirmation() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stop_circle_outlined,
                size: 48,
                color: Theme.of(ctx).colorScheme.error,
              ),
              SizedBox(height: 12),
              Text(
                "End this trip?",
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              SizedBox(height: 8),
              Text(
                "You've been navigating for ${_formatDuration(tripElapsed)}",
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _endTrip();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                        foregroundColor: Theme.of(ctx).colorScheme.onError,
                      ),
                      child: Text("End Trip"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _endTrip() {
    final elapsed = tripElapsed;

    gpsStream?.cancel();
    compassStream?.cancel();
    centerMapTimer?.cancel();
    elapsedTimer?.cancel();

    setState(() {
      trackUserLoc = false;
      startedDirections = false;
      hasArrived = false;
      shownLeg = null;
      _viewport = null;
      tripStartTime = null;
      tripElapsed = Duration.zero;
    });
    centerMap();

    // Show summary snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("Trip ended — ${_formatDuration(elapsed)}"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes.remainder(60)}min";
    }
    if (d.inMinutes > 0) {
      return "${d.inMinutes} min";
    }
    return "${d.inSeconds}s";
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    gpsStream?.cancel();
    compassStream?.cancel();
    centerMapTimer?.cancel();
    elapsedTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WakelockPlus.enable();
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Map fills the whole screen
          MapWidget(
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

          // FAB positioned above the sheet
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.35 + 16,
            child: _buildFab(),
          ),
        ],
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  Widget _buildFab() {
    if (!startedDirections) {
      // "Go" button — green
      return FloatingActionButton.extended(
        onPressed: startRoute,
        label: Text("Go"),
        icon: Icon(Icons.navigation_rounded),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      );
    } else if (!trackUserLoc) {
      // "Recentre" button
      return FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            trackUserLoc = true;
            _viewport = FollowPuckViewportState(
              zoom: 15.0,
              pitch: 45.0,
              bearing: FollowPuckViewportStateBearingHeading(),
            );
          });
        },
        icon: Icon(Icons.gps_fixed_rounded),
        label: Text("Recentre"),
      );
    } else {
      // "End" button — red/destructive
      return FloatingActionButton.extended(
        onPressed: _showEndTripConfirmation,
        icon: Icon(Icons.stop_rounded),
        label: Text("End"),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      );
    }
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: [0.15, 0.35, 0.7],
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Navigation elapsed bar (only during active navigation)
              if (startedDirections && !hasArrived)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Navigating",
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        "  •  ${_formatDuration(tripElapsed)}",
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                      Spacer(),
                      Text(
                        "to ${widget.destName}",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // Header
              ListTile(
                title: Text(
                  widget.destName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                subtitle: Text("From: ${widget.startName}"),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    if (startedDirections) {
                      _showEndTripConfirmation();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),

              // Leg chips row
              Container(
                height: 75,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 4),
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
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: shownLeg?["legGeometry"]["points"] ==
                                      leg["legGeometry"]["points"]
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: shownLeg?["legGeometry"]["points"] ==
                                      leg["legGeometry"]["points"]
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.5),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(3, 8, 15, 8),
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

              // Leg detail content
              shownLeg != null
                  ? _buildLegDetail()
                  : _buildEmptyState(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegDetail() {
    if (shownLeg?["mode"] == "WALK") {
      return DirectionsRouteViewWalkLeg(
        leg: shownLeg!,
        nextLeg: widget.route["legs"].indexOf(shownLeg) !=
                widget.route["legs"].length - 1
            ? widget.route["legs"]
                [widget.route["legs"].indexOf(shownLeg) + 1]
            : null,
      );
    } else if (shownLeg?["mode"] == "BUS") {
      return DirectionsRouteViewBusLeg(
        leg: shownLeg!,
        startedRouting: startedDirections,
      );
    } else if (shownLeg?["mode"] == "SUBWAY") {
      return DirectionsRouteViewTrainLeg(
        leg: shownLeg!,
        startedRouting: startedDirections,
      );
    }
    return Container();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            startedDirections
                ? Icons.near_me_rounded
                : Icons.touch_app_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(height: 12),
          Text(
            startedDirections
                ? "Finding your current step..."
                : "Tap a step above to preview details",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          if (!startedDirections) ...[
            SizedBox(height: 4),
            Text(
              "or tap Go to start navigating",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
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
