import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:sgbus/components/directionSearchDelegate.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/directions_route_view.dart';
import 'package:skeletonizer/skeletonizer.dart';

class DirectionsPage extends StatefulWidget {
  const DirectionsPage({Key? key, required this.placeData}) : super(key: key);
  final placeData;

  @override
  _DirectionsPageState createState() => _DirectionsPageState();
}

class _DirectionsPageState extends State<DirectionsPage> {
  Map? startingData = {"name": "Your location", "ul": true};
  Map? destData;

  String startingSessID = "";
  String destSessID = "";

  LatLng? startingCoords;
  LatLng? destCoords;

  bool startLoaded = false;
  bool destLoaded = false;

  Future<Position> getLocation() async {
    bool GPSError = false;
    String GPSErrorMsg = "Unknown Error";
    int GPSErrorCode = 0;

    // Check if GPS is enabled
    bool isGPSEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGPSEnabled) {
      GPSError = true;
      GPSErrorMsg = 'GPS is disabled';
      GPSErrorCode = 1;
      return Future.error({"msg": GPSErrorMsg, "code": GPSErrorCode});
    }

    //Check is GPS Permission is given
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      GPSError = true;
      GPSErrorMsg = 'GPS Permissions not given';
      GPSErrorCode = 2;
      return Future.error({"msg": GPSErrorMsg, "code": GPSErrorCode});
    }

    //Check if GPS permissions are permenents denied
    if (permission == LocationPermission.deniedForever) {
      GPSError = true;
      GPSErrorMsg = 'GPS Permissions are denied';
      GPSErrorCode = 3;
      return Future.error({"msg": GPSErrorMsg, "code": GPSErrorCode});
    }

    var currLocation = await Geolocator.getCurrentPosition();

    return currLocation;
  }

  Future<void> getStartingInfo() async {
    setState(() {
      startLoaded = false;
      startingCoords = null;
    });
    if (startingData?["ul"] != null && startingData?["ul"] == true) {
      getLocation().then((location) {
        startingCoords = LatLng(location.latitude, location.longitude);
      }).catchError((err) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  icon: Icon(Icons.warning),
                  title: Text(err["msg"] != null ? err["msg"] : err.toString()),
                  actions: [
                    (err["code"] != null && err["code"] == 2)
                        ? TextButton(
                            onPressed: () async {
                              await Geolocator.requestPermission();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Request permission'))
                        : (err["code"] != null && err["code"] == 2)
                            ? TextButton(
                                onPressed: () async {
                                  await Geolocator.openLocationSettings();
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Request permission'))
                            : Container()
                  ],
                ));
      }).whenComplete(() {
        setState(() {
          startLoaded = true;
        });
      });
    } else {
      setState(() {
        startLoaded = false;
      });
      try {
        final url = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/retrieve/${startingData?["mapbox_id"]}?access_token=${mapboxAccessToken}&session_token=${startingSessID}');
        Response results = await get(url).timeout(Duration(seconds: 45));

        var response = jsonDecode(results.body);

        startingCoords = LatLng(
            response["features"][0]["geometry"]["coordinates"][1],
            response["features"][0]["geometry"]["coordinates"][0]);
        setState(() {
          startLoaded = true;
        });
      } catch (err) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(err.toString()),
                ));
      }
    }
  }

  Future<void> getDestinationInfo() async {
    setState(() {
      destLoaded = false;
    });
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/search/searchbox/v1/retrieve/${destData?["mapbox_id"]}?access_token=${mapboxAccessToken}&session_token=${destSessID}');
      Response results = await get(url).timeout(Duration(seconds: 45));

      var response = jsonDecode(results.body);

      destCoords = LatLng(response["features"][0]["geometry"]["coordinates"][1],
          response["features"][0]["geometry"]["coordinates"][0]);
      setState(() {
        destLoaded = true;
      });
    } catch (err) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(err.toString()),
              ));
    }
  }

  @override
  void initState() {
    destData = widget.placeData["data"];
    destSessID = widget.placeData["sessID"];
    getStartingInfo();
    getDestinationInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Directions"),
      ),
      body: Column(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
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
                        // color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Skeletonizer(
                        enabled: !startLoaded,
                        child: ListTile(
                          dense: true,
                          // contentPadding: EdgeInsets.zero,
                          leading: startingData?["ul"] != null &&
                                  startingData?["ul"] &&
                                  startingCoords != null
                              ? Icon(Icons.gps_fixed_rounded)
                              : Icon(Icons.circle_outlined),
                          title: Text(startingCoords != null
                              ? (startingData?["name"])
                              : "Select"),
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
                        destData = res["data"];
                        destSessID = res["sessID"];
                        await getDestinationInfo();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Skeletonizer(
                        enabled: !destLoaded,
                        child: ListTile(
                          dense: true,
                          // contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.location_pin),
                          title: Text(destData?['name']),
                          subtitle: Text("Destination"),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
              child: DefaultTabController(
            length: 2,
            child: Scaffold(
              primary: false,
              appBar: AppBar(
                toolbarHeight: 0,
                bottom: TabBar(
                  indicatorColor:
                      (startLoaded && destLoaded) ? null : Colors.transparent,
                  tabs: [
                    Tab(
                      child: Text("Public Transport"),
                    ),
                    Tab(
                      child: Text("Walk"),
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  (startLoaded && destLoaded)
                      ? startingCoords != null && destCoords != null
                          ? PublicTransportRoutesDisplay(
                              startingCoords: startingCoords!,
                              destCoords: destCoords!,
                              startName: startingData?["name"],
                              destName: destData?["name"],
                            )
                          : Center(
                              child: Text(
                                  "Select the start and destination to view directions"),
                            )
                      : Center(
                          child: CircularProgressIndicator(),
                        ),
                  Center(
                    child: Text(
                      "Coming Soon",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
          ))
        ],
      ),
    );
  }
}

class PublicTransportRoutesDisplay extends StatefulWidget {
  const PublicTransportRoutesDisplay({
    Key? key,
    required this.startingCoords,
    required this.destCoords,
    required this.startName,
    required this.destName,
  }) : super(key: key);
  final LatLng startingCoords;
  final LatLng destCoords;
  final String startName;
  final String destName;

  @override
  _PublicTransportRoutesDisplayState createState() =>
      _PublicTransportRoutesDisplayState();
}

class _PublicTransportRoutesDisplayState
    extends State<PublicTransportRoutesDisplay> {
  Object? ptMode = "TRANSIT";

  TimeOfDay departureTime = TimeOfDay.now();

  bool isRoutesLoading = true;
  bool routeError = false;
  String routesErrMsg = "";
  List routes = [];

  Future<void> getDirections() async {
    setState(() {
      isRoutesLoading = true;
      routeError = false;
      routesErrMsg = "";
      routes = [];
    });
    _getRoutes(ptMode, widget.startingCoords, widget.destCoords, departureTime)
        .then((res) {
      setState(() {
        routes = res!;
        isRoutesLoading = false;
      });
    }).catchError((err) {
      print("err");
      print(err.toString());
      setState(() {
        routeError = true;
        isRoutesLoading = false;
        routesErrMsg = err.toString();
      });
    });
  }

  @override
  void initState() {
    getDirections();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mode: ",
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary)),
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
                    icon: Icon(Icons.directions_bus_filled_rounded),
                  ),
                  ButtonSegment(
                    value: "RAIL",
                    label: Text("MRT"),
                    icon: Icon(Icons.directions_transit_rounded),
                  ),
                ],
                selected: {ptMode},
                onSelectionChanged: (mode) {
                  setState(() {
                    ptMode = mode.first;
                  });
                  getDirections();
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
        ),
        Row(
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
                  getDirections();
                }
              },
              child: Text("Leave at: " + departureTime.format(context)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                if (isRoutesLoading)
                  Skeletonizer(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text("Loading"),
                          subtitle: Text("00min"),
                          trailing: Text("\$0.00"),
                        ),
                        ListTile(
                          title: Text("Loading......"),
                          subtitle: Text("00min"),
                          trailing: Text("\$0.00"),
                        ),
                        ListTile(
                          title: Text("Loading..."),
                          subtitle: Text("000min"),
                          trailing: Text("0.0km"),
                        ),
                      ],
                    ),
                  ),
                if (!isRoutesLoading && routeError)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.warning_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          Text(
                            routesErrMsg,
                            textAlign: TextAlign.center,
                          ),
                          TextButton.icon(
                              onPressed: getDirections,
                              icon: Icon(Icons.refresh_rounded),
                              label: Text("Retry"))
                        ],
                      ),
                    ),
                  ),
                if (!isRoutesLoading && !routeError)
                  for (var r in routes)
                    ListTile(
                      title: Row(
                        children: [
                          for (var i in r["legsWidgets"])
                            Row(
                              children: [
                                if (r["legsWidgets"].indexOf(i) < 3)
                                  Row(
                                    children: [
                                      i,
                                      r["legsWidgets"].indexOf(i) !=
                                              r["legsWidgets"].length - 1
                                          ? Icon(Icons.navigate_next)
                                          : Container(),
                                    ],
                                  ),
                                if (r["legsWidgets"].indexOf(i) == 3)
                                  Text("...")
                              ],
                            )
                        ],
                      ),
                      subtitle: Text("Takes " +
                          (r["duration"] / 60).round().toString() +
                          " mins"),
                      trailing: r["fare"] != "info unavailable"
                          ? Text("\$${r["fare"]}")
                          : Text("Unknown"),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DirectionsRouteView(
                            startName: widget.startName,
                            destName: widget.destName,
                            route: r,
                          ),
                        ),
                      ),
                    )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<List> _getRoutes(Object? ptMode, LatLng startingCoords,
    LatLng destCoords, TimeOfDay departureTime) async {
  try {
    Response tokRes = await post(
      Uri.parse('https://www.onemap.gov.sg/api/auth/post/getToken'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(
          <String, String>{"email": oneMapEmail, "password": oneMapPassword}),
    );

    var tokResJSON = jsonDecode(tokRes.body);

    String oneMapToken = tokResJSON["access_token"];

    String date = DateFormat('MM-dd-yyyy').format(DateTime.now());

    final url = Uri.parse(
        'https://www.onemap.gov.sg/api/public/routingsvc/route?start=${startingCoords!.latitude},${startingCoords!.longitude}&end=${destCoords!.latitude},${destCoords!.longitude}&routeType=pt&date=${date}&time=${departureTime.hour}:${departureTime.minute}:00&mode=${ptMode}');

    Response results = await get(url, headers: {"Authorization": oneMapToken})
        .timeout(Duration(seconds: 45));

    var resPar = jsonDecode(results.body);

    if (resPar["plan"] == null) {
      if (resPar["status"] == "error") {
        if (resPar["message"].contains("NOT FOUND")) {
          Future.error("No Routes Found");
        } else {
          Future.error(resPar["message"].toString());
        }
      }
    }

    var routes;

    if (resPar != null &&
        resPar["plan"] != null &&
        resPar["plan"]["itineraries"] != null) {
      routes = resPar["plan"]["itineraries"];
    } else {
      return Future.error(
          "No routes found.\n Make sure that points selected are in SG");
    }

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
          routes[i]["legsWidgets"].add(DirectionsRailRouteDisplayWidget(
            line: leg["route"],
          ));
        }
      });
    }
    return routes;
  } catch (err) {
    return Future.error(err.toString());
  }
  // return Future.error(
  //     "Failed to get routes. Check that wifi/mobile data is enabled and try again.");
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

  Color lineColor() {
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

  Color lineForeColor() {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          Icon(
            Icons.directions_transit_filled_rounded,
            size: 13,
            color: lineForeColor(),
          ),
          Text(line,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: lineForeColor())),
        ],
      ),
      padding: EdgeInsets.fromLTRB(4, 1.5, 4, 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        // color: Theme.of(context).colorScheme.surfaceVariant,
        color: lineColor(),
      ),
    );
  }
}
