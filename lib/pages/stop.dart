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
  bool isRefreshing = false;
  static const String endpoint = serverURL;

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
        setState(() {
          name = element['Name'];
        });
      }
    }

    // setState(() {
    //   arrTimings = [];
    // });

    final url = Uri.parse('$endpoint/${widget.stopid}');
    Response timings = await get(url);
    var pd = timings.body;

    var pdd = jsonDecode(pd);

    setState(() {
      arrTimings = pdd['Services'];
    });
  }

  Future<void> refresh() async {
    final url = Uri.parse('$endpoint/${widget.stopid}');
    Response timings = await get(url);
    var pd = timings.body;

    var pdd = jsonDecode(pd);

    setState(() {
      arrTimings = pdd['Services'];
      isRefreshing = false;
    });
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
                    isRefreshing = true;
                  });
                  refresh();
                },
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: arrTimings.isNotEmpty
            ? Column(
                children: [
                  isRefreshing ? const LinearProgressIndicator() : Container(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView.builder(
                        itemCount: arrTimings.length,
                        itemBuilder: (context, index) {
                          return BusTiming(arrTimings[index]);
                        },
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()));
  }
}
