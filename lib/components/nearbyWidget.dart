import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/location_helper.dart';
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
  List nearbyStops = [];
  Position? currLocation;

  Random random = Random();

  Future<void> getNearbyStops() async {
    setState(() {
      isLoaded = false;
    });

    try {
      final LocationResult result =
          await LocationHelper.getUserLocation(context);
      if (result.hasError || result.position == null) {
        setState(() {
          currLocation = null;
          isLoaded = true;
        });
        return;
      }

      final position = result.position!;
      final List stops = getStops();

      final List sortedStops = await compute(
        _calculateNearbyStops,
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'stops': stops,
        },
      );

      setState(() {
        currLocation = position;
        nearbyStops = sortedStops;
        isLoaded = true;
      });
    } catch (e) {
      setState(() {
        currLocation = null;
        isLoaded = true;
      });
    }
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
          child: !isLoaded
              ? Skeletonizer(
                  enabled: true,
                  child: Column(
                    children: [
                      for (var stop in nearbyStopsW.asMap().entries)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: stop.key == 0
                                  ? const Radius.circular(28.0)
                                  : const Radius.circular(5),
                              topRight: stop.key == 0
                                  ? const Radius.circular(28.0)
                                  : const Radius.circular(5),
                              bottomLeft:
                                  stop.key == nearbyStopsW.length - 1
                                      ? const Radius.circular(28.0)
                                      : const Radius.circular(5),
                              bottomRight:
                                  stop.key == nearbyStopsW.length - 1
                                      ? const Radius.circular(28.0)
                                      : const Radius.circular(5),
                            ),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.3),
                          ),
                          child: ListTile(
                            title: Text(stop.value['Name']),
                            subtitle: Text(stop.value['id']),
                            trailing: Text('${stop.value['dist']}m'),
                            onTap: () {},
                          ),
                        )
                    ],
                  ),
                )
              : currLocation == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(50.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Icon(Icons.location_off_rounded,
                                  size: 50,
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            Text(
                              "Location access is required to find nearby bus stops.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: getNearbyStops,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : nearbyStops.isNotEmpty
                      ? Column(
                          children: [
                            for (var stop in nearbyStops.asMap().entries)
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: stop.key == 0
                                        ? const Radius.circular(28.0)
                                        : const Radius.circular(5),
                                    topRight: stop.key == 0
                                        ? const Radius.circular(28.0)
                                        : const Radius.circular(5),
                                    bottomLeft:
                                        stop.key == nearbyStops.length - 1
                                            ? const Radius.circular(28.0)
                                            : const Radius.circular(5),
                                    bottomRight:
                                        stop.key == nearbyStops.length - 1
                                            ? const Radius.circular(28.0)
                                            : const Radius.circular(5),
                                  ),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.3),
                                ),
                                child: ListTile(
                                  title: Text(stop.value['Name']),
                                  subtitle: Text(stop.value['id']),
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
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(50.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
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

List<dynamic> _calculateNearbyStops(Map<String, dynamic> args) {
  final double latitude = args['latitude'] as double;
  final double longitude = args['longitude'] as double;
  final List<dynamic> stops = args['stops'] as List<dynamic>;

  final List<dynamic> nearbyStops = [];

  for (var stop in stops) {
    final Map<String, dynamic> stopCopy =
        Map<String, dynamic>.from(stop as Map);
    final double stopLat = stopCopy['cords'][1] as double;
    final double stopLon = stopCopy['cords'][0] as double;

    stopCopy['dist'] = Geolocator.distanceBetween(
      latitude,
      longitude,
      stopLat,
      stopLon,
    ).round();

    if (stopCopy['dist'] < 500) {
      nearbyStops.add(stopCopy);
    }
  }
  nearbyStops.sort((a, b) => (a['dist'] as num).compareTo(b['dist'] as num));

  return nearbyStops;
}
