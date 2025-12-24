import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:math';

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

  Random random = new Random();

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
    setState(() => isLoaded = false);
    getNearbyStops();
  }

  Future<void> enableGPSInSettings() async {
    await Geolocator.openLocationSettings();
    setState(() => isLoaded = false);
    getNearbyStops();
  }

  @override
  void initState() {
    getNearbyStops();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List nearbyStopsW;

    isLoaded
        ? nearbyStopsW = nearbyStops
        : nearbyStopsW = List.generate(10, (index) {
            return {
              "Name": "Loading" +
                  List.generate(random.nextInt(15), (index) => ".").join(),
              "id": "00000",
              "dist": "0" +
                  List.generate(random.nextInt(2) + 1, (index) => "0").join()
            };
          });

    return RefreshIndicator(
        onRefresh: getNearbyStops,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.0),
            // color:
            //     Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
          child: error
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                      child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.warning_rounded,
                            size: 50,
                            color: Theme.of(context).colorScheme.error),
                      ),
                      Text(
                        errorMsg,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: ButtonBar(
                          alignment: MainAxisAlignment.center,
                          children: [
                            (errorCode == 1)
                                ? Container()
                                : (errorCode == 2)
                                    ? FilledButton.icon(
                                        onPressed: () {
                                          requestGPSPermission();
                                        },
                                        icon: const Icon(
                                            Icons.location_searching),
                                        label: const Text('Request GPS'))
                                    : FilledButton.icon(
                                        onPressed: () {
                                          enableGPSInSettings();
                                        },
                                        icon: const Icon(
                                            Icons.location_searching),
                                        label: const Text('Request GPS'))
                          ],
                        ),
                      )
                    ],
                  )),
                )
              : nearbyStopsW.isNotEmpty
                  ? Skeletonizer(
                      enabled: !isLoaded,
                      // child: ListView.builder(
                      //     padding: EdgeInsets.zero,
                      //     itemCount: nearbyStopsW.length,
                      //     itemBuilder: (BuildContext context, int index) {
                      //       var stop = nearbyStopsW[index];
                      //       return ListTile(
                      //         title: Text(stop['Name']),
                      //         subtitle: Text(stop['id']),
                      //         trailing: Text('${stop['dist']}m'),
                      //         onTap: () {
                      //           Navigator.push(
                      //               context,
                      //               MaterialPageRoute(
                      //                   builder: (context) =>
                      //                       Stop(stop['id'])));
                      //         },
                      //       );
                      //     }),
                      child: Column(
                        children: [
                          for (var stop in nearbyStopsW.asMap().entries)
                            Container(
                              margin: EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topLeft: stop.key == 0
                                      ? Radius.circular(28.0)
                                      : Radius.circular(5),
                                  topRight: stop.key == 0
                                      ? Radius.circular(28.0)
                                      : Radius.circular(5),
                                  bottomLeft:
                                      stop.key == nearbyStopsW.length - 1
                                          ? Radius.circular(28.0)
                                          : Radius.circular(5),
                                  bottomRight:
                                      stop.key == nearbyStopsW.length - 1
                                          ? Radius.circular(28.0)
                                          : Radius.circular(5),
                                ),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                              ),
                              child: ListTile(
                                title: Text(
                                  stop.value['Name'],
                                  // style: TextStyle(
                                  //   fontWeight: FontWeight.w900,
                                  //   fontVariations: [
                                  //     FontVariation('ROND', 100),
                                  //     FontVariation('wdth', 170),
                                  //   ],
                                  // ),
                                ),
                                subtitle: Text(
                                      stop.value['id'],
                                      // style: TextStyle(
                                      //     fontWeight: FontWeight.w900),
                                    ),
                                trailing: Text('${stop.value['dist']}m'),
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              Stop(stop.value['id'])));
                                },
                              ),
                            )
                        ],
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(50.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 10.0),
                              child: Icon(Icons.warning_rounded,
                                  size: 50,
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            Text(
                              "There doesn't seem to be any stops near you.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ));
  }
}
