import 'package:flutter/material.dart';
import 'package:sgbus/pages/route_map.dart';
import 'package:sgbus/pages/route_tracker.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class BusRoute extends StatefulWidget {
  final String sno;
  const BusRoute(this.sno);
  // const Route({Key? key}) : super(key: key);

  @override
  _BusRouteState createState() => _BusRouteState();
}

class _BusRouteState extends State<BusRoute> {
  List bsids = [];
  List bsnos = [];
  String routeType = '';
  var currRoute;
  List shownRoute = [];
  int currRI = 0;
  List routeStops = [];

  Future<void> loadRoute() async {
    List bstopsList = getStops();
    bstopsList.forEach((element) => bsids.add(element['id']));

    var svcsParsed = getSvcs();
    currRoute = svcsParsed[widget.sno];
    if (currRoute['name'].contains('⇄')) {
      routeType = 'PTP';
      routeStops.add([]);
      currRoute['routes'][0].forEach((element) {
        routeStops[0].add(bstopsList[bsids.indexOf(element)]);
      });
      routeStops.add([]);
      currRoute['routes'][1].forEach((element) {
        routeStops[1].add(bstopsList[bsids.indexOf(element)]);
      });
      setState(() {
        shownRoute = routeStops[currRI];
      });
    } else {
      currRoute['routes'][0].forEach((element) {
        routeStops.add(bstopsList[bsids.indexOf(element)]);
      });
      setState(() {
        shownRoute = routeStops;
      });
    }
  }

  void switchRoute() {
    if (routeType == 'PTP') {
      if (currRI == 0) {
        currRI = 1;
      } else {
        currRI = 0;
      }
      setState(() {
        shownRoute = routeStops[currRI];
      });
    }
  }

  @override
  void initState() {
    loadRoute();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sno), actions: [
        IconButton(
            onPressed: () => {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: ((context) => RouteMap(
                            sno: widget.sno,
                          ))))
                },
            icon: const Icon(Icons.map_rounded)),
        (routeType == 'PTP')
            ? IconButton(
                onPressed: switchRoute, icon: const Icon(Icons.swap_vert))
            : Container()
      ]),
      body: ((currRoute != null) && (currRoute['name'] != null))
          ? ListView(children: [
              for (var stop in shownRoute)
                InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Stop(stop["id"])));
                    },
                    onLongPress: () {
                      shownRoute.indexOf(stop) == 0
                          ? null
                          : showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return SimpleDialog(
                                  title: Text(stop['Name']),
                                  children: [
                                    SimpleDialogOption(
                                      child: TextButton(
                                        child: Text('Go here'),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RouteTracker(
                                              serviceNo: widget.sno,
                                              destStopID: stop["id"],
                                              route: shownRoute,
                                              isLoopSvc: (routeType != 'PTP'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                );
                              });
                    },
                    child: ListTile(
                      title: Text(stop['Name']),
                      subtitle: Text(stop["id"]),
                    ))
            ])
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
    // ;
  }
}
