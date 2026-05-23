import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sgbus/components/recentSearchesWidget.dart';
import 'package:sgbus/pages/mrt_pages/station_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data_management/data.dart';

class CustomSearchPage extends StatefulWidget {
  /// 0 = Stops (default), 1 = Buses, 2 = MRT Stations
  const CustomSearchPage({Key? key, this.initialTabIndex = 0})
      : super(key: key);

  final int initialTabIndex;

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
  List<dynamic> stations = [];
  List<dynamic> recentSearches = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _focusNode.requestFocus();
    });

    stops = getStops();
    svcsRaw = getSvcs();
    svcsRaw.forEach((key, value) {
      svcs.add({"svc": key, "route": value["name"]});
    });

    final mrtDataMap = getMRTData();
    if (mrtDataMap != null && mrtDataMap["stations"] != null) {
      stations = List<dynamic>.from(mrtDataMap["stations"]);
    }

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

  String get _hintText {
    switch (widget.initialTabIndex) {
      case 2:
        return 'Search MRT stations';
      default:
        return 'Search for stops, roads or buses';
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
      length: 3,
      initialIndex: widget.initialTabIndex,
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
                    decoration: InputDecoration(
                      hintText: _hintText,
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                      Tab(text: 'Stations'),
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
                        child: _searchResults(context),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TabBarView _searchResults(BuildContext context) {
    final q = query.toLowerCase();

    return TabBarView(
      children: [
        // ── Stops tab ──────────────────────────────────────────────────────
        _ResultList(
          children: [
            for (var stop in stops.asMap().entries)
              if (stop.value["Name"] != null &&
                  stop.value["id"] != null &&
                  stop.value["Road"] != null &&
                  (stop.value['Name'].toString().toLowerCase().contains(q) ||
                      stop.value['id'].toString().toLowerCase().contains(q) ||
                      stop.value["Road"].toString().toLowerCase().contains(q)))
                _ResultTile(
                  isFirst: stop.key == 0,
                  title: stop.value["Name"],
                  subtitle: stop.value["id"],
                  onTap: () async {
                    await _addToRecents(
                        {"type": "stop", "id": stop.value["id"]});
                    if (!mounted) return;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Stop(stop.value["id"])));
                  },
                ),
          ],
        ),

        // ── Buses tab ──────────────────────────────────────────────────────
        _ResultList(
          children: [
            for (var svc in svcs.asMap().entries)
              if (svc.value["svc"] != null &&
                  svc.value["route"] != null &&
                  svc.value["svc"].toString().toLowerCase().contains(q))
                _ResultTile(
                  isFirst: svc.key == 0,
                  title: svc.value["svc"],
                  subtitle: svc.value["route"],
                  onTap: () async {
                    await _addToRecents(
                        {"type": "svc", "svc": svc.value["svc"]});
                    if (!mounted) return;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BusRoute(svc.value["svc"])));
                  },
                ),
          ],
        ),

        // ── MRT Stations tab ───────────────────────────────────────────────
        _ResultList(
          children: [
            for (var station in stations.asMap().entries)
              if (_stationMatches(station.value, q))
                _ResultTile(
                  isFirst: station.key == 0,
                  title: station.value["name"] ?? '',
                  subtitle:
                      (station.value["codes"] as List? ?? []).join('  ·  '),
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            StationPage(
                          stationCode: station.value["codes"].first,
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ],
    );
  }

  bool _stationMatches(dynamic station, String q) {
    if (q.isEmpty) return false;
    final name = (station["name"] ?? '').toString().toLowerCase();
    final nameCn = (station["name-chinese"] ?? '').toString().toLowerCase();
    final nameTa = (station["name-tamil"] ?? '').toString().toLowerCase();
    final codes = ((station["codes"] as List?) ?? [])
        .map((c) => c.toString().toLowerCase())
        .toList();
    return name.contains(q) ||
        nameCn.contains(q) ||
        nameTa.contains(q) ||
        codes.any((c) => c.contains(q));
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────

class _ResultList extends StatelessWidget {
  const _ResultList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 3, 8.0, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28.0),
          topRight: Radius.circular(28.0),
        ),
        child: ListView(children: children),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.isFirst,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isFirst;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft:
              isFirst ? const Radius.circular(28.0) : const Radius.circular(5),
          topRight:
              isFirst ? const Radius.circular(28.0) : const Radius.circular(5),
        ),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
