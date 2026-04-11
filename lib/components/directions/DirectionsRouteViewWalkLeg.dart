import 'package:flutter/material.dart';
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
  String getStopName(id) {
    try {
      var res = getStopByID(id)["Name"];
      return res;
    } catch (e) {
      return ("Unknown Stop");
    }
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
    );
  }
}
