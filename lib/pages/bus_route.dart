import 'package:flutter/material.dart';
import 'package:sgbus/pages/route_map.dart';
import 'package:sgbus/pages/route_tracker.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class BusRoute extends StatefulWidget {
  final String sno;
  const BusRoute(this.sno);

  @override
  _BusRouteState createState() => _BusRouteState();
}

class _BusRouteState extends State<BusRoute> {
  List bsids = [];
  String routeType = '';
  var currRoute;
  List routeStops = [];

  Future<void> loadRoute() async {
    List bstopsList = getStops();
    bstopsList.forEach((element) => bsids.add(element['id']));

    var svcsParsed = getSvcs();
    var localCurrRoute = svcsParsed[widget.sno];
    if (localCurrRoute == null) {
      // Handle case where service number is not found
      if (mounted) {
        setState(() {
          currRoute = {}; // To stop loading indicator and show empty state
        });
      }
      return;
    }
    String localRouteType = '';
    List localRouteStops = [];

    if (localCurrRoute['name'].contains('⇄')) {
      localRouteType = 'PTP';
      List route1 = [];
      localCurrRoute['routes'][0].forEach((element) {
        route1.add(bstopsList[bsids.indexOf(element)]);
      });
      localRouteStops.add(route1);

      List route2 = [];
      localCurrRoute['routes'][1].forEach((element) {
        route2.add(bstopsList[bsids.indexOf(element)]);
      });
      localRouteStops.add(route2);
    } else {
      localCurrRoute['routes'][0].forEach((element) {
        localRouteStops.add(bstopsList[bsids.indexOf(element)]);
      });
    }

    if (mounted) {
      setState(() {
        currRoute = localCurrRoute;
        routeType = localRouteType;
        routeStops = localRouteStops;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadRoute();
  }

  Widget _buildRouteListView(List stops) {
    if (stops.isEmpty) {
      return const Center(child: Text('No stops found for this route.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 3, 8.0, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28.0), topRight: Radius.circular(28.0)),
        child: ListView.builder(
            itemCount: stops.length,
            itemBuilder: (context, index) {
              var stop = stops[index];
              return InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Stop(stop["id"])));
                  },
                  onLongPress: () {
                    stops.indexOf(stop) == 0
                        ? null
                        : showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return SimpleDialog(
                                title: Text(stop['Name']),
                                children: [
                                  SimpleDialogOption(
                                    child: TextButton(
                                        child: const Text('Go here'),
                                        onPressed: () {
                                          Navigator.pop(
                                              context); // Close dialog
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RouteTracker(
                                                serviceNo: widget.sno,
                                                destStopID: stop["id"],
                                                route: stops,
                                                isLoopSvc: (routeType != 'PTP'),
                                              ),
                                            ),
                                          );
                                        }),
                                  )
                                ],
                              );
                            });
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: index == 0
                            ? Radius.circular(28.0)
                            : Radius.circular(5),
                        topRight: index == 0
                            ? Radius.circular(28.0)
                            : Radius.circular(5),
                        bottomLeft: index == stops.length - 1
                            ? Radius.circular(28.0)
                            : Radius.circular(5),
                        bottomRight: index == stops.length - 1
                            ? Radius.circular(28.0)
                            : Radius.circular(5),
                      ),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                    ),
                    child: ListTile(
                      title: Text(stop['Name']),
                      subtitle: Text(stop["id"]),
                    ),
                  ));
            }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currRoute == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.sno)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (routeStops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.sno)),
        body: Center(
          child: Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.warning_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 50,
                ),
              ),
              Text(
                "Route information not avaliable or invalid service number",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          )),
        ),
      );
    }

    int tabCount = (routeType == 'PTP') ? 2 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sno),
          actions: [
            IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: ((context) => RouteMap(
                          sno: widget.sno,
                        )))),
                icon: const Icon(Icons.map_rounded)),
          ],
          bottom: TabBar(
            dividerHeight: 0,
            tabs: (routeType == 'PTP')
                ? [
                    Tab(text: 'To ${routeStops[0].last['Name']}'),
                    Tab(text: 'To ${routeStops[1].last['Name']}'),
                  ]
                : [
                    Tab(text: currRoute['name']),
                  ],
          ),
        ),
        body: TabBarView(
          children: (routeType == 'PTP')
              ? [
                  _buildRouteListView(routeStops[0]),
                  _buildRouteListView(routeStops[1]),
                ]
              : [
                  _buildRouteListView(routeStops),
                ],
        ),
      ),
    );
  }
}
