import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sgbus/components/searchBar.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

class Search extends StatefulWidget {
  const Search({Key? key}) : super(key: key);

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  bool isRecentsLoaded = false;
  bool error = false;
  Map svcs = getSvcs();
  List recentSearches = [];
  Random random = new Random();

  Future<void> loadRecents() async {
    recentSearches = List.generate(10, (index) {
      return {
        "Type": "stop",
        "Name": "Loading" +
            List.generate(random.nextInt(15), (index) => ".").join(),
        "subtitle": "00000",
      };
    });

    try {
      var prefs = await SharedPreferences.getInstance();
      List newRecentSearches = [];

      String recentSearchesJson = (prefs.getString("recentSearches") ?? "[]");

      var recentSearchesRaw = jsonDecode(recentSearchesJson);
      recentSearchesRaw.forEach((i) {
        if (i != null && i["type"] != null) {
          if (i["id"] != null && i["type"] == "stop") {
            var stop = getStopByID(i["id"]);
            if (stop["Name"] != null && stop["id"] != null) {
              newRecentSearches.add({
                "Name": stop["Name"],
                "subtitle": stop["id"],
                "type": "stop",
              });
            }
          } else if (i["svc"] != null && i["type"] == "svc") {
            var svc = svcs[i["svc"]];
            if (svc["name"] != null) {
              newRecentSearches.add({
                "Name": i["svc"],
                "subtitle": svc["name"],
                "type": "svc",
              });
            }
          }
        }
      });

      setState(() {
        recentSearches = newRecentSearches;
        isRecentsLoaded = true;
      });
    } catch (e) {
      setState(() {
        error = true;
        isRecentsLoaded = true;
      });
    }
  }

  Future<void> clearRecentSearches() async {
    var prefs = await SharedPreferences.getInstance();

    prefs.remove("recentSearches");
    setState(() {
      recentSearches = [];
    });
  }

  @override
  void initState() {
    loadRecents();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Column(
        children: [
          SearchBarWidget(callback: loadRecents),
          Container(
            child: Row(
              children: [
                Text(
                  "Recents",
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Spacer(),
                TextButton(
                  child: Text(
                    "Clear",
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  onPressed: clearRecentSearches,
                ),
              ],
            ),
            width: width,
            padding: EdgeInsets.only(left: 10),
          ),
          Expanded(
            child: isRecentsLoaded && error
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
                        Text("An error occured when fetching recent searches"),
                      ],
                    )),
                  )
                : Skeletonizer(
                    enabled: !isRecentsLoaded,
                    child: isRecentsLoaded && recentSearches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 200.0),
                            child: Center(
                                child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.search,
                                    size: 50,
                                  ),
                                ),
                                Text("No Recent searches"),
                              ],
                            )),
                          )
                        : ListView(
                            children: [
                              for (var item in recentSearches.reversed)
                                ListTile(
                                  title: Text(item["Name"]),
                                  subtitle: Text(item["subtitle"]),
                                  onTap: () {
                                    if (item["type"] == "stop") {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (builder) =>
                                                  Stop(item["subtitle"])));
                                    } else if (item["type"] == "svc") {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (builder) =>
                                                  BusRoute(item["Name"])));
                                    }
                                  },
                                )
                            ],
                          ),
                  ),
          )
        ],
      ),
    );
  }
}
