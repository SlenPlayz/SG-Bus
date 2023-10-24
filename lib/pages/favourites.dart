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
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 75,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No favourites yet!',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Container(
                      width: 300,
                      child: Text(
                        'Add favourites by clicking the heart icon on a stop page',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }
}
