import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sgbus/components/busTimingsView.dart';
import 'package:sgbus/scripts/utils.dart';

class DirectionsRouteViewBusLeg extends StatefulWidget {
  const DirectionsRouteViewBusLeg(
      {Key? key, required this.leg, required this.startedRouting})
      : super(key: key);
  final Map leg;
  final bool startedRouting;

  @override
  _DirectionsRouteViewBusLegState createState() =>
      _DirectionsRouteViewBusLegState();
}

class _DirectionsRouteViewBusLegState extends State<DirectionsRouteViewBusLeg> {
  Timer? routeStartedCheckTimer;
  bool startedStreaming = false;
  StreamSubscription<Position>? gpsStream;
  bool showTimingsView = true;

  Position? currPosition;

  List allStops = [];

  var decodedLegs;

  String getStopName(id) {
    try {
      var res = getStopByID(id)["Name"];
      return res;
    } catch (e) {
      return ("Unknown Stop");
    }
  }

  void initNearestLegToStop() {
    allStops.add(widget.leg["from"]);
    for (var s in widget.leg["intermediateStops"]) {
      allStops.add(s);
    }
    allStops.add(widget.leg["to"]);

    // Note: The original code logic for 'nl' (nearest leg) seemed complex and possibly unused in UI
    // I'll keep the basic structure if needed, but for now just initializing stops list is key.

    // Original logic was trying to map each stop to a point on the polyline.
    // Simplifying for now to avoid errors if logic was flawed, or re-implement if strictly needed.
    // The decodedLegs variable was used here.
  }

  void updateGPSFuncs(t) {
    if (widget.startedRouting) {
      if (!startedStreaming) {
        setState(() {
          startedStreaming = true;
        });
        gpsStream = Geolocator.getPositionStream().listen((userPos) {
          currPosition = userPos;
          decideToShowTimings();
        });
      }
    } else {
      gpsStream?.cancel();
      setState(() {
        startedStreaming = false;
        showTimingsView = true;
      });
    }
  }

  void decideToShowTimings() {
    if (currPosition != null && startedStreaming) {
      if (Geolocator.distanceBetween(
              currPosition!.latitude,
              currPosition!.longitude,
              widget.leg["from"]["lat"],
              widget.leg["from"]["lon"]) >
          200) {
        // Increased distance threshold to 200m
        setState(() {
          showTimingsView = false;
        });
      } else {
        setState(() {
          showTimingsView = true;
        });
      }
    }
  }

  @override
  void initState() {
    decodedLegs = decodePolyline(widget.leg["legGeometry"]["points"]);
    initNearestLegToStop();
    routeStartedCheckTimer = Timer.periodic(
      Duration(milliseconds: 1000), // Check every second
      updateGPSFuncs,
    );
    super.initState();
  }

  @override
  void dispose() {
    routeStartedCheckTimer?.cancel();
    gpsStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              title: Text(
                  "Take Bus ${widget.leg["route"]} to ${getStopName(widget.leg["to"]["stopCode"])}"),
              subtitle: Text(
                  (widget.leg["intermediateStops"].length + 1).toString() +
                      " stops, " +
                      "about ${(widget.leg["duration"] / 60).round()} mins"),
              dense: true,
            ),
          ),
        ),
        if (showTimingsView)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: BusTimingsView(
                stopid: widget.leg["from"]["stopCode"] ?? "",
                buses: widget.leg["route"].split(" / "),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: Row(
            children: [
              Text(
                "Stops:",
                style: Theme.of(context).textTheme.labelSmall,
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            height: 165,
            child: ListView(
              children: [
                ListTile(
                  title: Text(getStopName(widget.leg["from"]["stopCode"])),
                  subtitle: Text(widget.leg["from"]["stopCode"]),
                  leading: Icon(Icons.circle),
                ),
                for (var stop in widget.leg["intermediateStops"])
                  ListTile(
                    title: Text(getStopName(stop["stopCode"])),
                    subtitle: Text(stop["stopCode"]),
                    leading: Icon(Icons.circle_outlined),
                    dense: true,
                  ),
                ListTile(
                  title: Text(getStopName(widget.leg["to"]["stopCode"])),
                  subtitle: Text(widget.leg["to"]["stopCode"]),
                  leading: Icon(Icons.location_pin),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
