import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:sgbus/env.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:uuid/uuid.dart';

class DSearchDelegate extends SearchDelegate {
  DSearchDelegate({required this.showLoc});

  final bool showLoc;

  var sessID = Uuid().v4();

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
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
      sessID: sessID,
      showLoc: showLoc,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return searchResultsWidget(
      query: query,
      close: close,
      sessID: sessID,
      showLoc: showLoc,
    );
  }
}

class searchResultsWidget extends StatefulWidget {
  const searchResultsWidget({
    super.key,
    required this.query,
    required this.close,
    required this.sessID,
    required this.showLoc,
  });
  final String query;
  final close;
  final sessID;
  final bool showLoc;

  @override
  State<searchResultsWidget> createState() => _searchResultsWidgetState();
}

class _searchResultsWidgetState extends State<searchResultsWidget> {
  var timer;
  var oldQuery = "";
  var searchRes = [];

  bool error = false;
  String errorMsg = "";

  bool isLoading = true;

  Random random = new Random();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
        Duration(seconds: 2), (Timer t) => getUpdatedSearchResults());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> getUpdatedSearchResults() async {
    if (widget.query != oldQuery && widget.query != "") {
      setState(() {
        error = false;
        errorMsg = "";
        isLoading = true;
      });
      oldQuery = widget.query;
      try {
        final url = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/suggest?q=${widget.query}&access_token=${mapboxAccessToken}&session_token=${widget.sessID}&country=sg&types=address,block,place,street,poi');
        Response results = await get(url).timeout(Duration(seconds: 45));

        var response = results.body;

        searchRes = jsonDecode(response)["suggestions"];
        setState(() {
          searchRes = searchRes;
          isLoading = false;
        });
      } catch (err) {
        setState(() {
          isLoading = false;
          error = true;
          if (err.toString().startsWith("Failed host lookup:")) {
            errorMsg = "Check that wifi or mobile data is enabled";
          } else {
            errorMsg = err.toString();
          }
        });
      }
    }
    if (widget.query == "") {
      searchRes = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.showLoc
            ? Card(
                child: ListTile(
                  title: Text("Your Location"),
                  leading: Icon(Icons.gps_fixed),
                  onTap: () => widget.close(context, {
                    "data": {"name": "Your Location", "ul": true},
                    "sessID": widget.sessID
                  }),
                ),
              )
            : Container(),
        widget.query == ""
            ? Container()
            : error
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.warning_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "An error occured",
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              )
                            ],
                          ),
                          Text(errorMsg),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: Skeletonizer(
                      enabled: isLoading,
                      child: Card(
                        child: ListView(
                          children: [
                            if (!isLoading)
                              for (var res in searchRes)
                                ListTile(
                                  title: Text(res["name"]),
                                  subtitle: Text(res["place_formatted"]),
                                  onTap: () => widget.close(context,
                                      {"data": res, "sessID": widget.sessID}),
                                )
                            else
                              for (var i
                                  in new List<int>.generate(10, (i) => i + 1))
                                ListTile(
                                  title: Text("AAAAAA" +
                                      List.generate(random.nextInt(20),
                                          (index) => "A").join()),
                                  subtitle: Text("AAAAAAAA" +
                                      List.generate(random.nextInt(20),
                                          (index) => "A").join()),
                                )
                          ],
                        ),
                      ),
                    ),
                  ),
      ],
    );
    // return Text(temp.toString());
  }
}
