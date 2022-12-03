import 'package:flutter/material.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';

class Search extends StatefulWidget {
  const Search({Key? key}) : super(key: key);

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  var searchQuery = TextEditingController();

  List stops = getStops();
  Map svcs = getSvcs();

  List _busSearchRes = [];

  String query = '';

  void searchBuses() {
    _busSearchRes = [];
    if (searchQuery.text == null || searchQuery.text == '') {
      svcs.forEach((key, value) {
        _busSearchRes.add({"sno": key, "route": value['name']});
      });
    } else {
      svcs.forEach((k, v) {
        if (k.toLowerCase().contains((searchQuery.text).toLowerCase())) {
          _busSearchRes.add({"sno": k, "route": v['name']});
        }
      });
    }
  }

  void onTextChange(text) {
    searchBuses();
    setState(() {
      query = text;
    });
  }

  @override
  void initState() {
    searchBuses();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: TextField(
            controller: searchQuery,
            textInputAction: TextInputAction.search,
            onChanged: onTextChange,
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide()),
              hintText: 'Search for Stops or Buses',
            )),
      ),
      // body: SearchRes(query: query),
      body: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
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
          body: TabBarView(children: [
            ListView(
              children: [
                for (var stop in stops)
                  if (stop['Name']
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()) ||
                      stop['id']
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()))
                    InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Stop(stop["id"])));
                      },
                      child: ListTile(
                        title: Text(stop['Name']),
                        subtitle: Text(stop['id']),
                      ),
                    )
              ],
            ),
            ListView(
              children: [
                for (var bus in _busSearchRes)
                  InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => BusRoute(bus['sno'])));
                    },
                    child: ListTile(
                      title: Text('Bus ' + bus['sno']),
                      subtitle: Text(bus['route']),
                    ),
                  ),
              ],
            )
          ]),
        ),
      ),
    );
  }
}
