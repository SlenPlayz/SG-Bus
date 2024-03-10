import 'package:flutter/material.dart';
import 'package:sgbus/scripts/utils.dart';

class DirectionsRouteViewTrainLeg extends StatefulWidget {
  const DirectionsRouteViewTrainLeg(
      {Key? key, required this.leg, required this.startedRouting})
      : super(key: key);
  final Map leg;
  final bool startedRouting;

  @override
  _DirectionsRouteViewTrainLegState createState() =>
      _DirectionsRouteViewTrainLegState();
}

class _DirectionsRouteViewTrainLegState
    extends State<DirectionsRouteViewTrainLeg> {
  Color lineColor(line) {
    if (line == "EW" || line == "CG") {
      return Colors.green;
    } else if (line == "DT") {
      return const Color.fromARGB(255, 26, 112, 183);
    } else if (line == "NS") {
      return Colors.red;
    } else if (line == "CC") {
      return Colors.yellow;
    } else if (line == "TE") {
      return Colors.brown;
    } else if (line == "NE") {
      return Color.fromARGB(255, 131, 32, 148);
    } else if (line == "SE" || line == "PE" || line == "BP") {
      return Colors.grey;
    } else {
      return Colors.blueGrey;
    }
  }

  Color lineForeColor(line) {
    if (line == "EW" || line == "CG") {
      return Colors.white;
    } else if (line == "DT") {
      return Colors.white;
    } else if (line == "NS") {
      return Colors.white;
    } else if (line == "CC") {
      return Colors.black;
    } else if (line == "TE") {
      return Colors.white;
    } else if (line == "NE") {
      return Colors.white;
    } else if (line == "SE" || line == "PE" || line == "BP") {
      return Colors.white;
    } else {
      return Colors.white;
    }
  }

  String lineText(line) {
    if (line == "EW" || line == "CG") {
      return "EWL";
    } else if (line == "DT") {
      return "DTL";
    } else if (line == "NS") {
      return "NSL";
    } else if (line == "CC") {
      return "CCL";
    } else if (line == "TE") {
      return "TEL";
    } else if (line == "NE") {
      return "NEL";
    } else if (line == "SE" || line == "PE" || line == "BP") {
      return line;
    } else {
      return "MRT";
    }
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
                    "Take the ${widget.leg["routeLongName"].toString().capitalize()} to ${widget.leg["to"]["name"].toString().capitalize()}"),
                subtitle: Text(
                    (widget.leg["intermediateStops"].length + 1).toString() +
                        " stops, " +
                        "about ${(widget.leg["duration"] / 60).round()} mins"),
                dense: true,
                leading: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: lineColor(widget.leg["route"]),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
                    child: Text(
                      lineText(widget.leg["route"]),
                      style: TextStyle(
                        color: lineForeColor(widget.leg["route"]),
                      ),
                    ),
                  ),
                ),
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
              height: 160,
              child: ListView(
                children: [
                  ListTile(
                    title: Text(
                        widget.leg["from"]["name"].toString().capitalize()),
                    subtitle: Text(widget.leg["from"]["stopCode"]),
                    leading: Icon(Icons.circle),
                  ),
                  for (var stop in widget.leg["intermediateStops"])
                    ListTile(
                      title: Text(stop["name"].toString().capitalize()),
                      subtitle: Text(stop["stopCode"]),
                      leading: Icon(Icons.circle_outlined),
                      dense: true,
                    ),
                  ListTile(
                    title:
                        Text(widget.leg["to"]["name"].toString().capitalize()),
                    subtitle: Text(widget.leg["to"]["stopCode"]),
                    leading: Icon(Icons.location_pin),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
