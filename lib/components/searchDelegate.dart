import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SBSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 15,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [IconButton(onPressed: () => query = "", icon: Icon(Icons.close))];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
        onPressed: () => close(context, null), icon: Icon(Icons.arrow_back));
  }

  @override
  Widget buildResults(BuildContext context) {
    return searchResultsWidget(
      query: query,
      close: close,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return searchResultsWidget(
      query: query,
      close: close,
    );
  }
}

class searchResultsWidget extends StatefulWidget {
  const searchResultsWidget(
      {super.key, required this.query, required this.close});
  final String query;
  final close;

  @override
  State<searchResultsWidget> createState() => _searchResultsWidgetState();
}

class _searchResultsWidgetState extends State<searchResultsWidget> {
  List stops = getStops();
  List svcs = [];
  Map svcsRaw = getSvcs();
  var recentSearches;
  var prefs;

  @override
  void initState() {
    (() async {
      try {
        prefs = await SharedPreferences.getInstance();

        String recentSearchesJson = (prefs.getString("recentSearches") ?? "[]");

        recentSearches = jsonDecode(recentSearchesJson);
      } catch (e) {}
    })();
    svcsRaw.forEach((key, value) {
      svcs.add({"svc": key, "route": value["name"]});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'Stops',
              ),
              Tab(
                text: 'Buses',
              ),
            ],
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              children: [
                for (var stop in stops)
                  if (stop["Name"] != null &&
                      stop["id"] != null &&
                      stop["Road"] != null &&
                      (stop['Name']
                              .toString()
                              .toLowerCase()
                              .contains(widget.query.toLowerCase()) ||
                          stop['id']
                              .toString()
                              .toLowerCase()
                              .contains(widget.query.toLowerCase()) ||
                          stop["Road"]
                              .toString()
                              .toLowerCase()
                              .contains(widget.query.toLowerCase())))
                    ListTile(
                      title: Text(stop["Name"]),
                      subtitle: Text(stop["id"]),
                      onTap: (() async {
                        if (recentSearches != null && prefs != null) {
                          recentSearches.add(
                            {
                              "type": "stop",
                              "id": stop["id"],
                            },
                          );

                          await prefs.setString(
                              'recentSearches', jsonEncode(recentSearches));
                        }
                        widget.close(context, null);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Stop(stop["id"])));
                      }),
                    )
              ],
            ),
            ListView(
              children: [
                for (var svc in svcs)
                  if (svc["svc"] != null &&
                      svc["route"] != null &&
                      svc["svc"]
                          .toString()
                          .toLowerCase()
                          .contains(widget.query.toLowerCase()))
                    ListTile(
                        title: Text(svc["svc"]),
                        subtitle: Text(svc["route"]),
                        onTap: (() async {
                          if (recentSearches != null && prefs != null) {
                            var dataToAdd = {
                              "type": "svc",
                              "svc": svc["svc"],
                            };
                            if (!recentSearches.contains(dataToAdd)) {
                              recentSearches.add(dataToAdd);
                            }

                            await prefs.setString(
                                'recentSearches', jsonEncode(recentSearches));
                          }
                          widget.close(context, null);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BusRoute(svc["svc"])));
                        }))
              ],
            )
          ],
        ),
      ),
    );
  }
}
