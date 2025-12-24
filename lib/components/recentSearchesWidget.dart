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

class RecentSearchesWidget extends StatefulWidget {
  const RecentSearchesWidget({Key? key}) : super(key: key);

  @override
  _RecentSearchesWidgetState createState() => _RecentSearchesWidgetState();
}

class _RecentSearchesWidgetState extends State<RecentSearchesWidget> {
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
            padding: EdgeInsets.only(left: 15),
          ),
          Expanded(
            child: isRecentsLoaded && error
                ? Padding(
                    padding: const EdgeInsets.only(top: 200.0),
                    child: Center(
                        child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.warning_rounded,
                            color: Theme.of(context).colorScheme.error,
                            size: 50,
                          ),
                        ),
                        Text(
                          "An error occured when fetching recent searches",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.search_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 50,
                                  ),
                                ),
                                Text(
                                  "No Recent searches",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ],
                            )),
                          )
                        : Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
                          child: ClipRRect(
                              borderRadius:
                                  BorderRadius.only(topLeft: Radius.circular(28.0), topRight: Radius.circular(28.0)),
                              child: ListView(
                                children: [
                                  for (var item in recentSearches.reversed
                                      .toList()
                                      .asMap()
                                      .entries)
                                    Container(
                                      margin: EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: item.key == 0
                                              ? Radius.circular(28.0)
                                              : Radius.circular(5),
                                          topRight: item.key == 0
                                              ? Radius.circular(28.0)
                                              : Radius.circular(5),
                                          bottomLeft: item.key ==
                                                  recentSearches.length - 1
                                              ? Radius.circular(28.0)
                                              : Radius.circular(5),
                                          bottomRight: item.key ==
                                                  recentSearches.length - 1
                                              ? Radius.circular(28.0)
                                              : Radius.circular(5),
                                        ),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant
                                            .withOpacity(0.3),
                                      ),
                                      child: ListTile(
                                        title: Text(item.value["Name"]),
                                        subtitle: Text(item.value["subtitle"]),
                                        onTap: () {
                                          if (item.value["type"] == "stop") {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (builder) => Stop(
                                                        item.value["subtitle"])));
                                          } else if (item.value["type"] ==
                                              "svc") {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (builder) =>
                                                        BusRoute(
                                                            item.value["Name"])));
                                          }
                                        },
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                ],
                              ),
                            ),
                        ),
                  ),
          )
        ],
      ),
    );
  }
}
