import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sgbus/components/recentSearchesWidget.dart';
import 'package:sgbus/pages/mrt_pages/station_page.dart';
import 'package:sgbus/pages/mrt_pages/amenity_stations_page.dart';
import 'package:sgbus/components/amenity_list_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/components/trainStationListView.dart';

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

  String selectedFilter = 'All';

  List stops = [];
  List svcs = [];
  Map svcsRaw = {};
  List<dynamic> stations = [];
  List<dynamic> allAmenities = [];
  List<dynamic> recentSearches = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    if (widget.initialTabIndex == 0) selectedFilter = 'Stops';
    if (widget.initialTabIndex == 1) selectedFilter = 'Buses';
    if (widget.initialTabIndex == 2) selectedFilter = 'Stations';
    if (widget.initialTabIndex == 3) selectedFilter = 'Amenities';
    if (widget.initialTabIndex == 4) selectedFilter = 'All';

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _focusNode.requestFocus();
    });

    stops = getStops();
    svcsRaw = getSvcs();
    svcsRaw.forEach((key, value) {
      svcs.add({"svc": key, "route": value["name"]});
    });

    final mrtDataMap = getMRTData();
    final Map<String, dynamic> uniqueAmenities = {};
    if (mrtDataMap["stations"] != null) {
      stations = List<dynamic>.from(mrtDataMap["stations"]);
      for (var s in stations) {
        final stationAmenities = s['amenities'] as List? ?? [];
        for (var a in stationAmenities) {
          final name = (a['name'] as String? ?? '').toLowerCase().trim();
          if (name.isNotEmpty && !uniqueAmenities.containsKey(name)) {
            uniqueAmenities[name] = a;
          }
        }
      }
      allAmenities = uniqueAmenities.values.toList();
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

  Widget _buildFilterPills() {
    const filters = ['All', 'Stops', 'Buses', 'Stations', 'Amenities'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        children: filters.map((f) {
          final isSelected = selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
              side: BorderSide.none,
              padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    selectedFilter = f;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  Widget _searchResults(BuildContext context) {
    final q = query.toLowerCase();

    List<Widget> children = [];

    // 1. Stations (MRTs)
    if (selectedFilter == 'All' || selectedFilter == 'Stations') {
      List<Widget> stationTiles = [];
      final filteredStations =
          stations.where((s) => _stationMatches(s, q)).toList();
      for (var i = 0; i < filteredStations.length; i++) {
        stationTiles.add(Container(
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: stationTiles.isEmpty
                  ? const Radius.circular(28.0)
                  : const Radius.circular(5),
              topRight: stationTiles.isEmpty
                  ? const Radius.circular(28.0)
                  : const Radius.circular(5),
            ),
            color: Theme.of(context)
                .colorScheme
                .surfaceVariant
                .withValues(alpha: 0.3),
          ),
          child: TrainStationListTile(
            station: filteredStations[i],
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      StationPage(
                          stationCode: filteredStations[i]["codes"].first),
                ),
              );
            },
          ),
        ));
      }
      if (stationTiles.isNotEmpty) {
        children.add(_buildLabel("Stations:"));
        children.addAll(stationTiles);
      }
    }

    // 2. Buses
    if (selectedFilter == 'All' || selectedFilter == 'Buses') {
      List<Widget> busTiles = [];
      final filteredBuses = svcs
          .where((svc) =>
              svc["svc"] != null &&
              svc["route"] != null &&
              svc["svc"].toString().toLowerCase().contains(q))
          .toList();
      for (var i = 0; i < filteredBuses.length; i++) {
        final svc = filteredBuses[i];
        busTiles.add(_ResultTile(
          isFirst: busTiles.isEmpty,
          title: svc["svc"],
          subtitle: svc["route"],
          onTap: () async {
            await _addToRecents({"type": "svc", "svc": svc["svc"]});
            if (!mounted) return;
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => BusRoute(svc["svc"])));
          },
        ));
      }
      if (busTiles.isNotEmpty) {
        children.add(_buildLabel("Buses:"));
        children.addAll(busTiles);
      }
    }

    // 3 & 4. Stops
    if (selectedFilter == 'All' || selectedFilter == 'Stops') {
      final stopsByName = stops
          .where((stop) =>
              stop["Name"] != null &&
              stop["id"] != null &&
              stop["Road"] != null &&
              (stop['Name'].toString().toLowerCase().contains(q) ||
                  stop['id'].toString().toLowerCase().contains(q)))
          .toList();

      List<Widget> nameTiles = [];
      for (var i = 0; i < stopsByName.length; i++) {
        final stop = stopsByName[i];
        nameTiles.add(_ResultTile(
          isFirst: nameTiles.isEmpty,
          title: stop["Name"],
          subtitle: stop["id"],
          onTap: () async {
            await _addToRecents({"type": "stop", "id": stop["id"]});
            if (!mounted) return;
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => Stop(stop["id"])));
          },
        ));
      }
      if (nameTiles.isNotEmpty) {
        children.add(_buildLabel("Stops:"));
        children.addAll(nameTiles);
      }

      final stopsByRoad = stops
          .where((stop) =>
              stop["Name"] != null &&
              stop["id"] != null &&
              stop["Road"] != null &&
              !(stop['Name'].toString().toLowerCase().contains(q) ||
                  stop['id'].toString().toLowerCase().contains(q)) &&
              stop["Road"].toString().toLowerCase().contains(q))
          .toList();

      List<Widget> roadTiles = [];
      for (var i = 0; i < stopsByRoad.length; i++) {
        final stop = stopsByRoad[i];
        roadTiles.add(_ResultTile(
          isFirst: roadTiles.isEmpty,
          title: stop["Name"],
          subtitle: stop["id"],
          onTap: () async {
            await _addToRecents({"type": "stop", "id": stop["id"]});
            if (!mounted) return;
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => Stop(stop["id"])));
          },
        ));
      }
      if (roadTiles.isNotEmpty) {
        children.add(_buildLabel("Stops (By Road):"));
        children.addAll(roadTiles);
      }
    }

    // 5. Amenities
    if (selectedFilter == 'All' || selectedFilter == 'Amenities') {
      List<Widget> amenityTiles = [];
      final filteredAmenities = allAmenities.where((a) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        final type = (a['type'] as String? ?? '').toLowerCase();
        return name.contains(q) || type.contains(q);
      }).toList();
      for (var i = 0; i < filteredAmenities.length; i++) {
        amenityTiles.add(
          AmenityListTile(
            showSubtitle: false,
            amenity: filteredAmenities[i],
            isFirst: amenityTiles.isEmpty,
            isLast: i == filteredAmenities.length - 1,
          ),
        );
      }
      if (amenityTiles.isNotEmpty) {
        children.add(_buildLabel("Amenities:"));
        children.addAll(amenityTiles);
      }
    }

    if (children.isEmpty && query.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No results found."),
      ));
    }

    return _ResultList(children: children);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                child: query.isEmpty
                    ? const SizedBox.shrink()
                    : _buildFilterPills(),
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
    );
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
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
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
        color:
            Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
