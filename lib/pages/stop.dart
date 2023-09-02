import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/components/bus_timing_row.dart';
import 'package:http/http.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Stop extends StatefulWidget {
  final String stopid;
  const Stop(this.stopid);
  // const Stop({Key? key}) : super(key: key);

  @override
  _StopState createState() => _StopState();
}

class _StopState extends State<Stop> {
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  List services = [];
  String name = '';
  List arrTimings = [];
  var _favouriteStops;
  var prefs;
  var stopIsFavourited = false;
  bool isLoading = true;
  bool isAdLoaded = false;
  bool error = false;
  String errMsg = '';
  static const String endpoint = serverURL;
  late AdWidget adWidget;
  Map arrivalData = {};

  Future<void> getArrTimings() async {
    try {
      final url = Uri.parse('$endpoint/api/${widget.stopid}');
      Response timings = await get(url).timeout(Duration(seconds: 45));
      var response = timings.body;

      arrivalData = jsonDecode(response);

      if (arrivalData != null) {
        calcTimings();
      } else {
        throw "Failed to get arrival timings";
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
    prefs = await SharedPreferences.getInstance();
    _favouriteStops = prefs.getStringList('favourites');

    if (_favouriteStops != null) {
      if (_favouriteStops.contains(widget.stopid.toString())) {
        stopIsFavourited = true;
      }
    }
    List data = getStops();

    for (var element in data) {
      if (element['id'].toLowerCase().contains((widget.stopid).toLowerCase())) {
        services = element["Services"];

        services.sort((a, b) => int.parse(a.replaceAll(RegExp(r"\D"), ''))
            .compareTo(int.parse(b.replaceAll(RegExp(r"\D"), ''))));
        services.forEach((s) {
          arrTimings.add({"ServiceNo": s});
        });
        setState(() {
          name = element['Name'];
          arrTimings = arrTimings;
        });
      }
    }

    if (adsEnabled) loadAd();
    getArrTimings();
  }

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      isAdLoaded = true;
    } catch (err, stackTrace) {
      await Sentry.captureException(
        err,
        stackTrace: stackTrace,
      );
      if (!kReleaseMode) print(err);
    }
  }

  Future<void> favourite() async {
    if (_favouriteStops == null) {
      await prefs
          .setStringList('favourites', <String>[widget.stopid.toString()]);
      setState(() => stopIsFavourited = true);
    } else {
      if (_favouriteStops.contains(widget.stopid.toString())) {
        _favouriteStops.removeWhere((item) => item == widget.stopid.toString());
      } else {
        _favouriteStops.add(widget.stopid.toString());
      }
      if (_favouriteStops != null) {
        if (_favouriteStops.contains(widget.stopid.toString())) {
          stopIsFavourited = true;
        } else {
          stopIsFavourited = false;
        }
      }
      setState(() {
        stopIsFavourited = stopIsFavourited;
      });
      await prefs.setStringList('favourites', _favouriteStops);
    }
  }

  void calcTimings() {
    if (arrivalData != null && arrivalData["Services"] != null) {
      arrivalData['Services'].forEach((x) {
        bool multiple = false;

        arrivalData["Services"].forEach((c) {
          if (x["ServiceNo"] != null &&
              c["ServiceNo"] != null &&
              x["ServiceNo"] == c["ServiceNo"] &&
              x["NextBus"]["DestinationCode"] !=
                  c["NextBus"]["DestinationCode"]) {
            multiple = true;
            // Map multipleDat = {
            //   "ServiceNo": x["ServiceNo"],
            //   "D1Timings": {x["NextBus"], x["NextBus2"], x["NextBus3"]},
            //   "D2Timings": {c["NextBus"], c["NextBus2"], c["NextBus3"]},
            // };

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
    var timer = Timer.periodic(Duration(seconds: 2), (Timer t) {
      if (!isLoading) {
        calcTimings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            IconButton(
                onPressed: favourite,
                icon: stopIsFavourited
                    ? const Icon(Icons.favorite)
                    : const Icon(Icons.favorite_outline)),
          ],
        ),
        floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: FloatingActionButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        isLoading = true;
                      });
                      getArrTimings();
                    },
              child: Icon(Icons.refresh),
            )),
        body: Column(
          children: [
            isLoading ? const LinearProgressIndicator() : Container(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: getArrTimings,
                child: ListView.builder(
                  itemCount: arrTimings.length,
                  padding: EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    return BusTiming(arrTimings[index]);
                  },
                ),
              ),
            ),
            isAdLoaded
                ? Container(
                    alignment: Alignment.center,
                    child: adWidget,
                    width: Ad.size.width.toDouble(),
                    height: Ad.size.height.toDouble(),
                  )
                : Container(),
          ],
        ));
  }
}
