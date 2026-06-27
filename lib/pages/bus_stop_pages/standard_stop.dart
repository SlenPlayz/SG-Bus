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
import 'package:sgbus/components/floating_ad.dart';
import 'package:sgbus/components/special_bus_tiles/premium_bus_tile.dart';
import 'package:sgbus/components/special_bus_tiles/shuttle_attraction_tile.dart';
import 'package:sgbus/components/special_bus_tiles/shuttle_hospital_tile.dart';
import 'package:http/http.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/pages/stop_spec_map.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _publicBusTypes = {
  'TRUNK',
  'FEEDER',
  'EXPRESS',
  'INDUSTRIAL',
  'CITY_LINK'
};

String _getServiceType(String serviceNo) {
  final svcs = getSvcs();
  if (svcs != null) {
    if (svcs.containsKey(serviceNo)) {
      return svcs[serviceNo]['type'] ?? 'TRUNK';
    }
    final splitCode = serviceNo.split(" - ");
    if (splitCode.isNotEmpty && svcs.containsKey(splitCode[0])) {
      return svcs[splitCode[0]]['type'] ?? 'TRUNK';
    }
  }
  return 'TRUNK';
}

String _getDisplayGroup(String type) {
  if (_publicBusTypes.contains(type)) return 'PUBLIC_BUS';
  return type;
}

String _getGroupDisplayName(String group) {
  switch (group) {
    case 'PUBLIC_BUS':
      return 'Public Buses';
    case 'PREMIUM':
      return 'Premium Buses (Private)';
    case 'SHUTTLEATTRACTIONS':
      return 'Shuttle Bus Services to Attractions';
    case 'SHUTTLEHOSPITALS':
      return 'Shuttle Bus Services to Hospitals';
    default:
      return group;
  }
}

class StandardStop extends StatefulWidget {
  final String stopid;
  const StandardStop(this.stopid);

  @override
  _StandardStopState createState() => _StandardStopState();
}

class _StandardStopState extends State<StandardStop> {
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  List services = [];
  String name = '';
  String road = '';
  var coords;
  List arrTimings = [];
  var _favouriteStops;
  var prefs;
  var stopIsFavourited = false;
  bool isLoading = true;
  bool error = false;
  String errMsg = '';
  static const String endpoint = serverURL;
  Map arrivalData = {};
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  DateTime? _lastRefreshed;

  late bool isSpecialStop;

  Future<void> getArrTimings() async {
    if (widget.stopid.startsWith("-")) {
      setState(() => isLoading = false);
      return;
    }
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
      if (element['id'].toLowerCase() == (widget.stopid).toLowerCase()) {
        services = element["Services"];

        services.sort((a, b) {
          final aNum = a.replaceAll(RegExp(r"\D"), '');
          final bNum = b.replaceAll(RegExp(r"\D"), '');
          return int.parse(aNum.isEmpty ? '0' : aNum)
              .compareTo(int.parse(bNum.isEmpty ? '0' : bNum));
        });
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

    if (widget.stopid.startsWith("-")) {
      setState(() {
        isLoading = false;
      });
    } else {
      getArrTimings();
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
      arrTimings.sort((a, b) {
        final aNum = a["ServiceNo"].replaceAll(RegExp(r"\D"), '');
        final bNum = b["ServiceNo"].replaceAll(RegExp(r"\D"), '');
        return int.parse(aNum.isEmpty ? '0' : aNum)
            .compareTo(int.parse(bNum.isEmpty ? '0' : bNum));
      });
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

  Widget _buildGroupedServices(BuildContext context) {
    // Group services by display group
    final Map<String, List<dynamic>> grouped = {};
    for (var timing in arrTimings) {
      final serviceNo = timing['ServiceNo'] ?? '';
      final type = _getServiceType(serviceNo);
      final group = _getDisplayGroup(type);
      grouped.putIfAbsent(group, () => []);
      grouped[group]!.add(timing);
    }

    // Define the order of groups
    final groupOrder = [
      'PUBLIC_BUS',
      'PREMIUM',
      'SHUTTLEATTRACTIONS',
      'SHUTTLEHOSPITALS',
    ];

    final orderedGroups = <String>[];
    for (var group in groupOrder) {
      if (grouped.containsKey(group)) {
        orderedGroups.add(group);
      }
    }
    for (var group in grouped.keys) {
      if (!orderedGroups.contains(group)) {
        orderedGroups.add(group);
      }
    }

    final bool showGroupLabels = orderedGroups.length > 1 ||
        (orderedGroups.isNotEmpty && orderedGroups.first != 'PUBLIC_BUS');

    return Container(
      padding: EdgeInsets.only(top: 5, bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var group in orderedGroups) ...[
            if (showGroupLabels)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 5),
                child: Text(
                  "${_getGroupDisplayName(group)}:",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            if (group == 'PUBLIC_BUS')
              _buildPublicBusSection(context, grouped[group]!)
            else
              _buildOtherTypeSection(context, grouped[group]!, group),
          ],
        ],
      ),
    );
  }

  Widget _buildPublicBusSection(BuildContext context, List<dynamic> services) {
    return Column(
      children: [
        for (var entry in services.asMap().entries)
          Container(
            margin: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft:
                    entry.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                topRight:
                    entry.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                bottomLeft: entry.key == services.length - 1
                    ? Radius.circular(28.0)
                    : Radius.circular(5),
                bottomRight: entry.key == services.length - 1
                    ? Radius.circular(28.0)
                    : Radius.circular(5),
              ),
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            child: BusTiming(entry.value),
          ),
      ],
    );
  }

  Widget _buildOtherTypeSection(
      BuildContext context, List<dynamic> services, String group) {
    return Column(
      children: [
        for (var entry in services.asMap().entries)
          Container(
            margin: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft:
                    entry.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                topRight:
                    entry.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                bottomLeft: entry.key == services.length - 1
                    ? Radius.circular(28.0)
                    : Radius.circular(5),
                bottomRight: entry.key == services.length - 1
                    ? Radius.circular(28.0)
                    : Radius.circular(5),
              ),
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            child: _buildTileForGroup(group, entry.value),
          ),
      ],
    );
  }

  Widget _buildTileForGroup(String group, dynamic data) {
    final String serviceNo = data['ServiceNo'] ?? '';
    final onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusRoute(serviceNo)),
      );
    };

    switch (group) {
      case 'SHUTTLEATTRACTIONS':
        return ShuttleAttractionTile(data, onTap: onTap);
      case 'SHUTTLEHOSPITALS':
        return ShuttleHospitalTile(data, onTap: onTap);
      case 'PREMIUM':
        return PremiumBusTile(data, onTap: onTap);
      default:
        return ListTile(
          title: Text(serviceNo),
          onTap: onTap,
        );
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading
            ? null
            : () {
                setState(() {
                  isLoading = true;
                });
                getArrTimings();
              },
        child: Icon(Icons.refresh),
      ),
      body: Stack(
        children: [
          Column(
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
                                  if (!widget.stopid.startsWith("-")) ...[
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
                                                    setState(
                                                        () => isLoading = true);
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
                                  ],
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
                            _buildGroupedServices(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          FloatingAd(
            margin: EdgeInsets.only(
              bottom: 20,
              left: 8,
            ),
          ),
        ],
      ),
    );
  }
}
