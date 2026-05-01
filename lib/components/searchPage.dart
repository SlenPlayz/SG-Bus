import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sgbus/components/recentSearchesWidget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data.dart';

class CustomSearchPage extends StatefulWidget {
  const CustomSearchPage({Key? key}) : super(key: key);

  @override
  State<CustomSearchPage> createState() => _CustomSearchPageState();
}

class _CustomSearchPageState extends State<CustomSearchPage> {
  String query = "";
  final TextEditingController _controller = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  List stops = [];
  List svcs = [];
  Map svcsRaw = {};
  List<dynamic> recentSearches = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    stops = getStops();
    svcsRaw = getSvcs();
    svcsRaw.forEach((key, value) {
      svcs.add({"svc": key, "route": value["name"]});
    });

    _loadRecents();
  }

  Future<void> _loadRecents() async {
    try {
      prefs = await SharedPreferences.getInstance();
      String jsonString = (prefs?.getString("recentSearches") ?? "[]");
      setState(() {
        recentSearches = jsonDecode(jsonString);
      });
    } catch (e) {
      print("Error loading recents: $e");
    }
  }

  Future<void> _addToRecents(Map<String, dynamic> item) async {
    if (prefs == null) return;

    bool exists = recentSearches.any((element) {
      if (item['type'] == 'stop') return element['id'] == item['id'];
      if (item['type'] == 'svc') return element['svc'] == item['svc'];
      return false;
    });

    if (!exists) {
      recentSearches.add(item);
      await prefs?.setString('recentSearches', jsonEncode(recentSearches));
    }
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Hero(
              tag: 'searchBarHero',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontVariations: [
                        FontVariation.weight(800),
                        FontVariation.width(100),
                        FontVariation("ROND", 100)
                      ],
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search for stops, roads or buses',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() {
                        query = val;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  setState(() => query = "");
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  height: query.isEmpty ? 0 : null,
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Stops'),
                      Tab(text: 'Buses'),
                    ],
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: query.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('recents'),
                        child: RecentSearchesWidget(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('results'),
                        child: searchResults(context),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TabBarView searchResults(BuildContext context) {
    return TabBarView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 3, 8.0, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28.0),
                topRight: Radius.circular(28.0)),
            child: ListView(
              children: [
                for (var stop in stops.asMap().entries)
                  if (stop.value["Name"] != null &&
                      stop.value["id"] != null &&
                      stop.value["Road"] != null &&
                      (stop.value['Name']
                              .toString()
                              .toLowerCase()
                              .contains(query.toLowerCase()) ||
                          stop.value['id']
                              .toString()
                              .toLowerCase()
                              .contains(query.toLowerCase()) ||
                          stop.value["Road"]
                              .toString()
                              .toLowerCase()
                              .contains(query.toLowerCase())))
                    Container(
                      margin: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: stop.key == 0
                              ? Radius.circular(28.0)
                              : Radius.circular(5),
                          topRight: stop.key == 0
                              ? Radius.circular(28.0)
                              : Radius.circular(5),
                        ),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                      ),
                      child: ListTile(
                        title: Text(stop.value["Name"]),
                        subtitle: Text(stop.value["id"]),
                        onTap: () async {
                          await _addToRecents(
                              {"type": "stop", "id": stop.value["id"]});
                          if (!mounted) return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      Stop(stop.value["id"])));
                        },
                      ),
                    )
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 3, 8.0, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28.0),
                topRight: Radius.circular(28.0)),
            child: ListView(
              children: [
                for (var svc in svcs.asMap().entries)
                  if (svc.value["svc"] != null &&
                      svc.value["route"] != null &&
                      svc.value["svc"]
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()))
                    Container(
                      margin: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: svc.key == 0
                              ? Radius.circular(28.0)
                              : Radius.circular(5),
                          topRight: svc.key == 0
                              ? Radius.circular(28.0)
                              : Radius.circular(5),
                        ),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                      ),
                      child: ListTile(
                        title: Text(svc.value["svc"]),
                        subtitle: Text(svc.value["route"]),
                        onTap: () async {
                          await _addToRecents(
                              {"type": "svc", "svc": svc.value["svc"]});
                          if (!mounted) return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      BusRoute(svc.value["svc"])));
                        },
                      ),
                    )
              ],
            ),
          ),
        )
      ],
    );
  }
}
