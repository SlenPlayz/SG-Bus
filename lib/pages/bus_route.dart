import 'package:flutter/material.dart';
import 'package:sgbus/pages/route_map.dart';
import 'package:sgbus/pages/route_tracker.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';

class BusRoute extends StatefulWidget {
  final String sno;
  const BusRoute(this.sno);

  @override
  _BusRouteState createState() => _BusRouteState();
}

class _BusRouteState extends State<BusRoute> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  List bsids = [];
  String routeType = '';
  var currRoute;
  List routeStops = [];

  var sno;
  var subtitle;

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

    if (localCurrRoute['routes'].length > 1) {
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
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 40;
      if (shouldShow != _showAppBarTitle) {
        setState(() {
          _showAppBarTitle = shouldShow;
        });
      }
    });

    if (widget.sno.toString().contains(" - ")) {
      sno = widget.sno.toString().split(" - ")[0];
      subtitle = widget.sno.toString().split(" - ")[1];
    } else {
      sno = widget.sno;
    }

    if (subtitle != null && subtitle.toString().startsWith("RWS")) {
      sno = widget.sno.toString().split(" - ")[0];
      subtitle = widget.sno.toString().split(" - ")[1];
    }
    loadRoute();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    IconData? typeIcon;
    String? typeName;

    switch (currRoute['type']) {
      case 'SHUTTLEATTRACTIONS':
        typeIcon = Icons.attractions_rounded;
        typeName = 'Shuttle Bus Services to Attraction';
        break;
      case 'SHUTTLEHOSPITALS':
        typeIcon = Icons.local_hospital_rounded;
        typeName = 'Shuttle Bus Services to Hospital';
        break;
      case 'PREMIUM':
        typeIcon = Icons.corporate_fare_rounded;
        typeName = 'Premium Bus (Private)';
        break;
      default:
        if (currRoute['fare'] != null || currRoute['schedule'] != null) {
          typeIcon = Icons.directions_bus_rounded;
          typeName = 'Information';
        }
    }

    final bool isPublicBus = ['TRUNK', 'FEEDER', 'EXPRESS', 'INDUSTRIAL', 'CITY_LINK'].contains(currRoute['type']);
    final String titleText = isPublicBus ? 'Bus $sno' : sno.toString();

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: AnimatedOpacity(
            opacity: _showAppBarTitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              titleText,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontVariations: [
                  FontVariation('ROND', 100),
                  FontVariation.width(100),
                  FontVariation.weight(800)
                ],
              ),
            ),
          ),
          actions: _showAppBarTitle
              ? [
                  IconButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: ((context) => RouteMap(
                                    sno: widget.sno,
                                  )))),
                      icon: const Icon(Icons.map_rounded)),
                ]
              : null,
        ),
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(left: 10, bottom: 20, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        textAlign: TextAlign.left,
                        style:
                            Theme.of(context).textTheme.displayMedium!.copyWith(
                          fontVariations: [
                            FontVariation('ROND', 100),
                            FontVariation.width(105),
                            FontVariation.weight(900)
                          ],
                        ),
                      ),
                      SizedBox(height: 2),
                      if (subtitle != null || currRoute['name'] != null)
                        Text(
                          subtitle ?? currRoute['name'],
                          style:
                              Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                            fontVariations: [
                              FontVariation('ROND', 100),
                              FontVariation.width(120),
                              FontVariation.weight(700)
                            ],
                          ),
                        ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (BuildContext context) => RouteMap(
                                    sno: widget.sno,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.map_rounded,
                              size: 18,
                            ),
                            label: Text('View Map'),
                          ),
                        ],
                      ),
                      if (currRoute['fare'] != null ||
                          currRoute['schedule'] != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 24.0, bottom: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                if (typeIcon != null && typeName != null) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(26),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 10.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(typeIcon, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            typeName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                              fontVariations: [
                                                FontVariation('ROND', 100),
                                                FontVariation.width(120),
                                                FontVariation.weight(900),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withOpacity(0.2),
                                  ),
                                ],
                                Table(
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: FlexColumnWidth(),
                                  },
                                  children: [
                                    if (currRoute['fare'] != null)
                                      TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              'Fare',
                                              style: TextStyle(
                                                fontVariations: [
                                                  FontVariation('ROND', 100),
                                                  FontVariation.width(110),
                                                  FontVariation.weight(900),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(currRoute['fare']),
                                          ),
                                        ],
                                      ),
                                    if (currRoute['schedule'] != null)
                                      TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              'Schedule',
                                              style: TextStyle(
                                                fontVariations: [
                                                  FontVariation('ROND', 100),
                                                  FontVariation.width(110),
                                                  FontVariation.weight(900),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(currRoute['schedule']),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: Theme.of(context).colorScheme.surface,
                scrolledUnderElevation: 0,
                toolbarHeight: 0,
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
            ];
          },
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
      ),
    );
  }
}
