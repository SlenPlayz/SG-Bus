import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:sgbus/components/busTimingsView.dart';
import 'package:sgbus/scripts/utils.dart';

class DirectionsRouteViewWalkLeg extends StatefulWidget {
  const DirectionsRouteViewWalkLeg({Key? key, required this.leg, this.nextLeg})
      : super(key: key);
  final Map leg;
  final Map? nextLeg;

  @override
  _DirectionsRouteViewWalkLegState createState() =>
      _DirectionsRouteViewWalkLegState();
}

class _DirectionsRouteViewWalkLegState
    extends State<DirectionsRouteViewWalkLeg> {
  // List steps = [];

  // void generateSteps() {
  //   steps = [];
  //   var oldHead = 0.0;
  //   for (var i = 2;
  //       i < decodePolyline(widget.leg["legGeometry"]["points"]).length - 1;
  //       i++) {
  //     List currPoint = decodePolyline(widget.leg["legGeometry"]["points"])[i];
  //     List prevPoint =
  //         decodePolyline(widget.leg["legGeometry"]["points"])[i - 1];
  //     // var a = Geolocator.bearingBetween(
  //     //     currPoint[1], currPoint[0], prevPoint[1], prevPoint[0]);
  //     var bearing = Geolocator.bearingBetween(
  //       prevPoint[0],
  //       prevPoint[1],
  //       currPoint[0],
  //       currPoint[1],
  //     );
  //     String headingText = "somewhere";

  //     var nb = ((bearing - oldHead) % 360);

  //     if ((nb < 22.5 && nb > -22.5) || (nb < 360 && nb > 337.5)) {
  //       headingText = "Walk straight";
  //     }
  //     if (nb < 67.5 && nb > 22.5) {
  //       headingText = "Turn left slightly";
  //     }
  //     if (nb < 112.5 && nb > 67.5) {
  //       headingText = "Turn left";
  //     }
  //     if (nb < 157.5 && nb > 112.5) {
  //       headingText = "Turn sharp left";
  //     }
  //     if (nb < 202.5 && nb > 157.5) {
  //       headingText = "Turn around";
  //     }
  //     if (nb < 247.5 && nb > 202.5) {
  //       headingText = "Turn right slightly";
  //     }
  //     if (nb < 292.5 && nb > 247.5) {
  //       headingText = "Turn right";
  //     }
  //     if (nb < 337.5 && nb > 292.5) {
  //       headingText = "Turn sharp right";
  //     }

  //     oldHead = nb;

  //     steps.add({
  //       "heading": nb,
  //       "headingText": headingText,
  //       "dist": Geolocator.distanceBetween(
  //         currPoint[0],
  //         currPoint[1],
  //         prevPoint[0],
  //         prevPoint[1],
  //       )
  //     });
  //   }
  // }

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }

  String getStopName(id) {
    try {
      var res = getStopByID(id)["Name"];
      return res;
    } catch (e) {
      return ("Unknown Stop");
    }
  }

  @override
  void initState() {
    // generateSteps();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
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
                    "Walk to ${widget.leg["to"]["stopCode"] != null && isNumeric(widget.leg["to"]["stopCode"]) ? getStopName(widget.leg["to"]["stopCode"]) : widget.leg["to"]["name"].toString().capitalize()}"),
                subtitle: Text("${widget.leg["distance"].round().toString()}m" +
                    ", " +
                    "about ${((widget.leg["endTime"] - widget.leg["startTime"]) / 60000).round().toString()} mins"),
              ),
            ),
          ),
          widget.leg["to"] != null &&
                  widget.nextLeg != null &&
                  widget.leg["to"]["stopCode"] != null &&
                  isNumeric(widget.leg["to"]["stopCode"])
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: BusTimingsView(
                          stopid: widget.leg["to"]["stopCode"],
                          buses: widget.nextLeg?["route"].split(" / "),
                        ),
                      ),
                    ),
                  ],
                )
              : Container()
        ],
      ),
    );
  }
}
