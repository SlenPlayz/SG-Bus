import 'package:flutter/material.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Favourites extends StatefulWidget {
  const Favourites({Key? key}) : super(key: key);

  @override
  _FavouritesState createState() => _FavouritesState();
}

class _FavouritesState extends State<Favourites> {
  var prefs;
  List _favouriteStops = [];
  bool isLoaded = false;

  Future<void> loadFavs() async {
    prefs = await SharedPreferences.getInstance();
    var favouriteStopsIDs = (prefs.getStringList('favourites') ?? []);

    List data = getStops();

    if (favouriteStopsIDs.isNotEmpty) {
      for (var element in data) {
        if (favouriteStopsIDs.contains(element['id'].toString())) {
          _favouriteStops.add(element);
        }
      }
    }
    setState(() {
      isLoaded = true;
    });
  }

  @override
  initState() {
    loadFavs();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return isLoaded
        ? _favouriteStops.isNotEmpty
            ? ListView(
                children: [
                  for (var busStop in _favouriteStops)
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: ((context) => Stop(busStop['id'])))),
                      child: ListTile(
                        title: Text(busStop['Name']),
                        subtitle: Text(busStop['id']),
                      ),
                    )
                ],
              )
            : const Center(
                child: Text('No favourites yet!'),
              )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }
}
