import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/components/bus_timing_row.dart';
import 'package:http/http.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BusTimingsView extends StatefulWidget {
  const BusTimingsView({Key? key, required this.stopid, required this.buses})
      : super(key: key);
  final String stopid;
  final List buses;

  @override
  _BusTimingsViewState createState() => _BusTimingsViewState();
}

class _BusTimingsViewState extends State<BusTimingsView> {
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  List services = [];
  String name = '';
  List arrTimings = [];
  bool isLoading = true;
  bool error = false;
  String errMsg = '';
  static const String endpoint = serverURL;
  Map arrivalData = {};
  Timer? reCalcTimer;

  Future<void> getArrTimings() async {
    setState(() {
      isLoading = true;
    });
    try {
      final url = Uri.parse('$endpoint/api/${widget.stopid}');
      Response timings = await get(url).timeout(Duration(seconds: 45));
      var response = timings.body;

      arrivalData = jsonDecode(response);

      try {
        calcTimings();
      } catch (err) {
        throw err;
      }
      ;
    } catch (err, stackTrace) {
      error = true;
      bool unknownError = true;
      try {
        errMsg = err.toString();
      } catch (e) {
        errMsg = 'Failed to get arrival timings';
      }
      if (errMsg.startsWith('Failed host lookup:') ||
          errMsg.startsWith('Connection failed')) {
        errMsg =
            'Unable to connect to server. Make sure that Wifi or Mobile data is enabled.';
        unknownError = false;
      }
      if (errMsg.startsWith('Software caused connection abort')) {
        errMsg =
            'Failed to get arrival timings due to change of network status. Please retry.';
        unknownError = false;
      }
      if (errMsg.startsWith('TimeoutException after')) {
        errMsg = 'Failed to get timings from server.';
      }
      if (unknownError) {
        await Sentry.captureException(
          err,
          stackTrace: stackTrace,
        );
      }
      setState(() {
        isLoading = false;
      });
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(Icons.warning_amber_rounded),
              title: Text('Failed to get arrival timings'),
              content: Text(errMsg),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                    });
                    getArrTimings();
                    Navigator.of(context).pop();
                  },
                  child: Text('Retry'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Dismiss'),
                ),
              ],
            );
          });
    }
  }

  Future<void> loadStop() async {
    List data = getStops();

    for (var element in data) {
      if (element['id'].toLowerCase().contains((widget.stopid).toLowerCase())) {
        services = element["Services"];

        services.sort((a, b) => int.parse(a.replaceAll(RegExp(r"\D"), ''))
            .compareTo(int.parse(b.replaceAll(RegExp(r"\D"), ''))));
        services.forEach((s) {
          if (widget.buses.contains(s.toString())) {
            arrTimings.add({"ServiceNo": s});
          }
        });
        setState(() {
          name = element['Name'];
          arrTimings = arrTimings;
        });
      }
    }
  }

  void calcTimings() {
    if (arrivalData["Services"] != null) {
      arrivalData['Services'].forEach((x) {
        bool multiple = false;

        arrivalData["Services"].forEach((c) {
          if (x["ServiceNo"] != null &&
              c["ServiceNo"] != null &&
              x["ServiceNo"] == c["ServiceNo"] &&
              x["NextBus"]["DestinationCode"] !=
                  c["NextBus"]["DestinationCode"]) {
            multiple = true;

            List arrTimingsCopy = List.from(arrTimings);

            arrTimingsCopy.forEach((element) {
              var index = arrTimings.indexOf(element);
              if (element['ServiceNo'] == x['ServiceNo'] &&
                  element["NextBus"] == null) {
                x["to"] = getStopByID(x["NextBus"]["DestinationCode"])["Name"];
                c["to"] = getStopByID(c["NextBus"]["DestinationCode"])["Name"];
                arrTimings[index] = x;
                arrTimings.add(c);
              }
            });
          }
        });
        if (!multiple) {
          arrTimings.forEach((element) {
            var index = arrTimings.indexOf(element);
            if (element['ServiceNo'] == x['ServiceNo']) {
              arrTimings[index] = x;
            }
          });
        }
      });
      arrTimings.sort((a, b) =>
          int.parse(a["ServiceNo"].replaceAll(RegExp(r"\D"), '')).compareTo(
              int.parse(b["ServiceNo"].replaceAll(RegExp(r"\D"), ''))));
      setState(() {
        arrTimings = arrTimings;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadStop();

    getArrTimings();
    reCalcTimer = Timer.periodic(Duration(seconds: 30), (Timer t) {
      if (!isLoading) {
        calcTimings();
      }
    });
  }

  @override
  void dispose() {
    reCalcTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                name,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            TextButton.icon(
              onPressed: getArrTimings,
              icon: Icon(Icons.refresh),
              label: Text("Refresh"),
              style: ButtonStyle(
                textStyle: MaterialStateProperty.all(
                    Theme.of(context).textTheme.labelSmall),
                iconSize: MaterialStatePropertyAll(17.0),
              ),
            )
          ],
        ),
        Skeletonizer(
          enabled: isLoading,
          child: Column(
            children: [for (var x in arrTimings) BusTiming(x, false)],
          ),
        )
      ],
    );
  }
}
