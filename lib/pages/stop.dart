import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/components/bus_timing_row.dart';
import 'package:http/http.dart';
import 'package:sgbus/scripts/data.dart';
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

  List services = [];
  String name = '';
  List arrTimings = [];
  var _favouriteStops;
  var prefs;
  var stopIsFavourited = false;
  bool isLoading = true;
  bool error = false;
  String errMsg = '';
  static const String endpoint = serverURL;

  Future<void> getArrTimings() async {
    try {
      final url = Uri.parse('$endpoint/${widget.stopid}');
      Response timings = await get(url);
      var response = timings.body;

      var arrivalData = jsonDecode(response);

      arrivalData['Services'].forEach((x) {
        arrTimings.forEach((element) {
          var index = arrTimings.indexOf(element);
          if (element['ServiceNo'] == x['ServiceNo']) {
            arrTimings[index] = x;
          }
        });
      });

      setState(() {
        arrTimings = arrTimings;
        isLoading = false;
      });
    } catch (e) {
      error = true;
      errMsg = e.toString();
      if (errMsg.startsWith('Failed host lookup:')) {
        errMsg = 'Unable to connect to server';
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
    getArrTimings();
  }

  Future<void> favourite() async {
    if (_favouriteStops == null) {
      await prefs
          .setStringList('favourites', <String>[widget.stopid.toString()]);
      setState(() => {stopIsFavourited = true});
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

  @override
  void initState() {
    super.initState();
    loadStop();
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
            // IconButton(
            //     onPressed: () {}, icon: const CircularProgressIndicator()),
            IconButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  getArrTimings();
                },
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: Column(
          children: [
            isLoading ? const LinearProgressIndicator() : Container(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: getArrTimings,
                child: ListView.builder(
                  itemCount: arrTimings.length,
                  itemBuilder: (context, index) {
                    return BusTiming(arrTimings[index]);
                  },
                ),
              ),
            ),
          ],
        ));
  }
}
