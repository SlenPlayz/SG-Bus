import 'dart:async';
import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/components/bus_timing_row.dart';
import 'package:http/http.dart';
import 'package:sgbus/pages/stop_spec_map.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Stop extends StatefulWidget {
  final String stopid;
  const Stop(this.stopid);

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
  String road = '';
  var coords;
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
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  DateTime? _lastRefreshed;

  Future<void> getArrTimings() async {
    try {
      final url = Uri.parse('$endpoint/api/${widget.stopid}');
      Response timings = await get(url).timeout(Duration(seconds: 45));
      var response = timings.body;

      if (timings.statusCode == 500) {
        throw response;
      }

      arrivalData = jsonDecode(response);
      _lastRefreshed = DateTime.now();

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
              icon: Icon(
                Icons.warning_amber_rounded,
                size: 48,
              ),
              title: Text(
                'Failed to get arrival timings',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                errMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Dismiss'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                    });
                    getArrTimings();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('Retry'),
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
          print(element);
          name = element['Name'];
          road = element['Road'] ?? '';
          arrTimings = arrTimings;
          coords = element["cords"];
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
      _favouriteStops = [widget.stopid.toString()];
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
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 80;
      if (shouldShow != _showAppBarTitle) {
        setState(() {
          _showAppBarTitle = shouldShow;
        });
      }
    });
    loadStop();
    Timer.periodic(Duration(seconds: 30), (Timer t) {
      if (!isLoading) {
        calcTimings();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: AnimatedOpacity(
          opacity: _showAppBarTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontVariations: [
                    FontVariation('ROND', 100),
                    FontVariation.width(100),
                    FontVariation.weight(800)
                  ],
                ),
              ),
              Text(
                road.isNotEmpty
                    ? '${widget.stopid} \u2022 $road'
                    : widget.stopid,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontVariations: [
                    FontVariation('ROND', 100),
                    FontVariation.width(100),
                    FontVariation.weight(600)
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: _showAppBarTitle
            ? [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (BuildContext context) => StopSpecMap(
                              coords: coords,
                              name: name,
                            )));
                  },
                  icon: Icon(Icons.map_rounded),
                ),
                IconButton(
                  onPressed: favourite,
                  icon: stopIsFavourited
                      ? const Icon(Icons.favorite_rounded)
                      : const Icon(Icons.favorite_outline_rounded),
                ),
              ]
            : null,
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
          AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: LinearProgressIndicatorM3E(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: getArrTimings,
              child: Container(
                padding: EdgeInsets.only(left: 8, bottom: 20, right: 8),
                child: ClipRRect(
                  borderRadius: _showAppBarTitle
                      ? BorderRadius.all(Radius.circular(28.0))
                      : BorderRadius.all(Radius.circular(0.0)),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.left,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium!
                                    .copyWith(
                                  fontVariations: [
                                    FontVariation('ROND', 100),
                                    FontVariation.width(105),
                                    FontVariation.weight(900)
                                  ],
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                road.isNotEmpty
                                    ? '${widget.stopid} • $road'
                                    : widget.stopid,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
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
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.45),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _lastRefreshed != null
                                        ? 'Last refreshed at ${_lastRefreshed!.hour.toString().padLeft(2, '0')}:${_lastRefreshed!.minute.toString().padLeft(2, '0')}'
                                        : 'Loading...',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.45),
                                      fontVariations: [
                                        FontVariation('ROND', 100),
                                        FontVariation.width(100),
                                        FontVariation.weight(600)
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: 16,
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              setState(() => isLoading = true);
                                              getArrTimings();
                                            },
                                      icon: Icon(
                                        Icons.refresh_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 0),
                              Row(
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: favourite,
                                    icon: Icon(
                                      stopIsFavourited
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_outline_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      stopIsFavourited
                                          ? 'Favourited'
                                          : 'Favourite',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (BuildContext context) =>
                                              StopSpecMap(
                                            coords: coords,
                                            name: name,
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
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(top: 5),
                          child: ListView.builder(
                            itemCount: arrTimings.length,
                            padding: EdgeInsets.only(bottom: 80),
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: index == 0
                                        ? Radius.circular(28.0)
                                        : Radius.circular(5),
                                    topRight: index == 0
                                        ? Radius.circular(28.0)
                                        : Radius.circular(5),
                                    bottomLeft: index == arrTimings.length - 1
                                        ? Radius.circular(28.0)
                                        : Radius.circular(5),
                                    bottomRight: index == arrTimings.length - 1
                                        ? Radius.circular(28.0)
                                        : Radius.circular(5),
                                  ),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.3),
                                ),
                                child: BusTiming(arrTimings[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
      ),
    );
  }
}
