import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class RouteTracker extends StatefulWidget {
  const RouteTracker(
      {Key? key,
      required this.serviceNo,
      required this.destStopID,
      required this.route})
      : super(key: key);
  final serviceNo;
  final destStopID;
  final route;

  @override
  _RouteTrackerState createState() => _RouteTrackerState();
}

class _RouteTrackerState extends State<RouteTracker> {
  bool isLoading = true;
  var destStop;
  var currLocation;
  bool error = false;
  String errorMsg = '';
  int errorCode = 0;
  var nearestStop;
  List route = [];
  var posStream;
  String message = 'Loading...';
  ScrollController scrollController = ScrollController();

  Future<void> requestGPSPermission() async {
    await Geolocator.requestPermission();
    loadTracker();
  }

  Future<void> enableGPSInSettings() async {
    await Geolocator.openLocationSettings();
    loadTracker();
  }

  Map getNearest(lat, long) {
    var nearest;
    widget.route.forEach((s) {
      var dist =
          Geolocator.distanceBetween(lat, long, s['cords'][1], s['cords'][0]);
      s['dist'] = dist;
      if (nearest == null) {
        nearest = s;
      } else if (nearest['dist'] > dist) {
        nearest = s;
      }
    });
    return nearest;
  }

  Future<bool> checkGPSPerms() async {
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

    return true;
  }

  bool checkIfFollowingRoute() {
    if (widget.route.indexOf(nearestStop) < widget.route.indexOf(route[0])) {
      return false;
    }
    return true;
  }

  List getRouteFromNearest(nearestStopID) {
    var routeFromNearest = [];
    bool x = false;

    widget.route.forEach((s) {
      if (s['id'] == nearestStopID && routeFromNearest.isEmpty) {
        x = true;
      }
      if (x == true) {
        if (x) {
          routeFromNearest.add(s);
        }
      }
      if (s['id'] == widget.destStopID) {
        x = false;
      }
    });
    return routeFromNearest;
  }

  void loadTracker() {
    isLoading = true;
    checkGPSPerms().then((b) async {
      if (b == true) {
        widget.route.forEach((s) {
          if (s['id'] == widget.destStopID) {
            destStop = s;
          }
        });
        var pos = await Geolocator.getCurrentPosition();
        nearestStop = getNearest(pos.latitude, pos.longitude);
        route = getRouteFromNearest(nearestStop['id']);
        setState(() {
          isLoading = false;
        });
        posStream = Geolocator.getPositionStream().listen((position) {
          nearestStop = getNearest(position.latitude, position.longitude);
          if (!checkIfFollowingRoute()) {
            setState(() {
              error = true;
              errorMsg = 'Not following bus route';
              errorCode = 4;
            });
          } else if (error) {
            setState(() {
              error = false;
              errorMsg = '';
              errorCode = 0;
            });
          }
          if (nearestStop['dist'] < 100) {
            if (route.contains(nearestStop)) {
              scrollController.animateTo(60.0 * route.indexOf(nearestStop),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeIn);
              var stopsLeft = getRouteFromNearest(nearestStop['id']).length;
              if (nearestStop['id'] == widget.destStopID) {
                setState(() {
                  message = "You've reached your stop!";
                });
              } else if (stopsLeft == 2) {
                setState(() {
                  message = 'Get off at the next stop';
                });
              } else {
                setState(() {
                  message =
                      'Get off in ' + (stopsLeft - 1).toString() + ' stops';
                });
              }
            } else {
              error = true;
              errorCode = 4;
              errorMsg = 'Not following route!';
            }
          } else if (message == 'Loading...') {
            if (widget.route.indexOf(nearestStop) != 0) {
              var routeFromStopBeforeNearest = getRouteFromNearest(
                  widget.route[widget.route.indexOf(nearestStop) - 1]['id']);
              setState(() {
                message = 'Get off in ' +
                    (routeFromStopBeforeNearest.length - 2).toString() +
                    ' stops';
              });
            } else {
              var routeFromStopBeforeNearest =
                  getRouteFromNearest(nearestStop['id']);
              setState(() {
                message = 'Get off in ' +
                    (routeFromStopBeforeNearest.length - 2).toString() +
                    ' stops';
              });
            }
          }
        });
      }
    }).catchError((err) => setState(() => isLoading = false));
  }

  @override
  void initState() {
    loadTracker();
    super.initState();
  }

  @override
  void dispose() {
    posStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(
            child: CircularProgressIndicator(),
          )
        : Scaffold(
            appBar: AppBar(
              title: Text(widget.serviceNo + ' to ' + destStop['Name']),
              elevation: 0.0,
              scrolledUnderElevation: 0,
            ),
            body: error
                ? Padding(
                    padding: const EdgeInsets.only(top: 200.0),
                    child: Center(
                        child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.warning,
                            size: 50,
                          ),
                        ),
                        Text(errorMsg),
                        ButtonBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            (errorCode == 1)
                                ? Container()
                                : (errorCode == 2)
                                    ? TextButton.icon(
                                        onPressed: () {
                                          requestGPSPermission();
                                        },
                                        icon: const Icon(
                                            Icons.location_searching),
                                        label: const Text('Request GPS'))
                                    : (errorCode == 2)
                                        ? TextButton.icon(
                                            onPressed: () {
                                              enableGPSInSettings();
                                            },
                                            icon: const Icon(
                                                Icons.location_searching),
                                            label: const Text('Request GPS'))
                                        : Container()
                          ],
                        )
                      ],
                    )),
                  )
                : Column(
                    children: [
                      Text(
                          'This feature is still in beta and may not work as intended'),
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Center(
                            child: Text(
                          message,
                          style: Theme.of(context).textTheme.headlineSmall,
                        )),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.only(
                            top: 10,
                            bottom: 540,
                            right: 8,
                            left: 8,
                          ),
                          children: [
                            for (var stop in route)
                              Row(
                                children: [
                                  Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: 10.0,
                                          left: 10.0,
                                        ),
                                        child: Container(
                                          height: 20,
                                          width: 2,
                                          decoration: BoxDecoration(
                                              border: Border.all(
                                                color: nearestStop['id'] ==
                                                        stop['id']
                                                    ? Theme.of(context)
                                                        .indicatorColor
                                                    : Theme.of(context)
                                                        .hintColor,
                                              ),
                                              borderRadius: (route[0] == stop)
                                                  ? BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(100),
                                                      topRight:
                                                          Radius.circular(100))
                                                  : BorderRadius.zero),
                                        ),
                                      ),
                                      Icon(
                                        nearestStop['id'] == stop['id']
                                            ? Icons.gps_fixed
                                            : Icons.gps_not_fixed,
                                        color: nearestStop['id'] == stop['id']
                                            ? Theme.of(context).indicatorColor
                                            : Theme.of(context).hintColor,
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: 10.0,
                                          left: 10.0,
                                        ),
                                        child: Container(
                                          height: 20,
                                          width: 2,
                                          decoration: BoxDecoration(
                                              border: Border.all(
                                                color: nearestStop['id'] ==
                                                        stop['id']
                                                    ? Theme.of(context)
                                                        .indicatorColor
                                                    : Theme.of(context)
                                                        .hintColor,
                                              ),
                                              borderRadius: (route[0] == stop)
                                                  ? BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(100),
                                                      topRight:
                                                          Radius.circular(100))
                                                  : BorderRadius.zero),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 5,
                                  ),
                                  Text(
                                    stop['Name'],
                                    style: TextStyle(
                                      color: nearestStop['id'] == stop['id']
                                          ? Theme.of(context).indicatorColor
                                          : Theme.of(context).hintColor,
                                      fontSize: nearestStop['id'] == stop['id']
                                          ? 20
                                          : 15,
                                    ),
                                  ),
                                ],
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
          );
  }
}
