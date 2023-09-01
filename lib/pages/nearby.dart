import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class Nearby extends StatefulWidget {
  const Nearby({Key? key}) : super(key: key);

  @override
  _NearbyState createState() => _NearbyState();
}

class _NearbyState extends State<Nearby> {
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  bool isLoaded = false;
  bool error = false;
  int errorCode = 0;
  String errorMsg = '';
  List nearbyStops = [];
  var currLocation;

  Future<Position> getLocation() async {
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

    currLocation = await Geolocator.getCurrentPosition();
    setState(() {
      currLocation = currLocation;
    });

    return currLocation;
  }

  Future<void> getNearbyStops() async {
    List newNearbyStops = [];
    setState(() {
      error = false;
      errorCode = 0;
      errorMsg = '';
    });
    getLocation().then((position) async {
      List stops = getStops();

      for (var stop in stops) {
        stop['dist'] = Geolocator.distanceBetween(position.latitude,
                position.longitude, stop['cords'][1], stop['cords'][0])
            .round();

        if (stop['dist'] < 500) {
          newNearbyStops.add(stop);
        }
      }
      newNearbyStops.sort((a, b) => a['dist'].compareTo(b['dist']));

      setState(() {
        isLoaded = true;
        nearbyStops = newNearbyStops;
      });
    }).catchError((err) {
      setState(() {
        error = true;
        errorMsg = err;
        isLoaded = true;
      });
    });
  }

  Future<void> requestGPSPermission() async {
    await Geolocator.requestPermission();
    getNearbyStops();
  }

  Future<void> enableGPSInSettings() async {
    await Geolocator.openLocationSettings();
    getNearbyStops();
  }

  @override
  void initState() {
    getNearbyStops();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: isLoaded
            ? (() {
                setState(() {
                  isLoaded = false;
                });
                getNearbyStops();
              })
            : null,
        child: const Icon(Icons.my_location),
      ),
      body: RefreshIndicator(
        onRefresh: getNearbyStops,
        child: isLoaded
            ? error
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
                                    : TextButton.icon(
                                        onPressed: () {
                                          enableGPSInSettings();
                                        },
                                        icon: const Icon(
                                            Icons.location_searching),
                                        label: const Text('Request GPS'))
                          ],
                        )
                      ],
                    )),
                  )
                : nearbyStops.isNotEmpty
                    ? ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: nearbyStops.length,
                        itemBuilder: (BuildContext context, int index) {
                          var stop = nearbyStops[index];
                          return ListTile(
                            title: Text(stop['Name']),
                            subtitle: Text(stop['id']),
                            trailing: Text('${stop['dist']}m'),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Stop(stop['id'])));
                            },
                          );
                        })
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20.0),
                              child: Icon(Icons.warning, size: 50),
                            ),
                            const Text(
                                "There doesn't seem to be any stops near you."),
                          ],
                        ),
                      )
            : const Padding(
                padding: EdgeInsets.all(15.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
      ),
    );

    // return Column(children: [
    //   Expanded(child: NearbyMap()),
    //   _nearbyStops.isNotEmpty
    //       ? Expanded(
    //           child: RefreshIndicator(
    //               onRefresh: getNearby,
    //               child: ListView.builder(
    //                 itemCount: _nearbyStops.length,
    //                 physics: const AlwaysScrollableScrollPhysics(),
    //                 padding: EdgeInsets.zero,
    //                 itemBuilder: (context, index) {
    //                   return InkWell(
    //                     onTap: () {
    //                       Navigator.push(
    //                           context,
    //                           MaterialPageRoute(
    //                               builder: (context) =>
    //                                   Stop(_nearbyStops[index]["id"])));
    //                     },
    //                     child: ListTile(
    //                       title: Text(_nearbyStops[index]['Name']),
    //                       subtitle: Text(_nearbyStops[index]["id"]),
    //                       trailing: Text(_nearbyStops[index]["distance"]
    //                               .round()
    //                               .toString() +
    //                           'm away'),
    //                     ),
    //                   );
    //                 },
    //               )),
    //         )
    //       : Padding(
    //           padding: const EdgeInsets.all(20.0),
    //           child: !error
    //               ? const Center(child: CircularProgressIndicator())
    //               : Text(locationPermsAllowed),
    //         )
    // ]);
    // ((locationPermsAllowed != ''))
    // ?
    // : Column(
    //     children: [
    //       Text(locationPermsAllowed),
    //       (locationPermsAllowed ==
    //               'Location services are not turned on.')
    //           ? const Text('Please enable GPS')
    //           : (locationPermsAllowed == 'GPS permissions not given')
    //               ? TextButton(
    //                   onPressed: getNearby, child: const Text('Retry'))
    //               : (locationPermsAllowed ==
    //                       'GPS permissions are disabled in settings')
    //                   ? TextButton(
    //                       onPressed: openLocationSettings,
    //                       child: const Text('Launch settings'))
    //                   : Container()
    //     ],
    //   );
  }
}
