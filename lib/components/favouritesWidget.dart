import 'package:flutter/material.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
    return _favouriteStops.isNotEmpty
        ? Column(
            children: [
              for (var busStop in _favouriteStops.asMap().entries)
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: ((context) => Stop(busStop.value['id'])))),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.only(
                        topLeft: busStop.key == 0
                            ? Radius.circular(28.0)
                            : Radius.circular(0),
                        topRight: busStop.key == 0
                            ? Radius.circular(28.0)
                            : Radius.circular(0),
                        bottomLeft: busStop.key == _favouriteStops.length - 1
                            ? Radius.circular(28.0)
                            : Radius.circular(0),
                        bottomRight: busStop.key == _favouriteStops.length - 1
                            ? Radius.circular(28.0)
                            : Radius.circular(0),
                      ),
                    ),
                    margin: EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      title: Text(
                        busStop.value['Name'],
                        // style: TextStyle(
                        //   fontWeight: FontWeight.w900,
                        //   fontVariations: [
                        //     FontVariation('rond', 100),
                        //     FontVariation('wdth', 170),
                        //   ],
                        // ),
                      ),
                      subtitle: Text(
                            busStop.value['id'],
                          ),
                    ),
                  ),
                )
            ],
          )
        : Skeletonizer(
            enabled: !isLoaded,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(28.0),
              ),
              child: ListTile(
                title: Text(
                  "No favourites added",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    "Tap the heart icon on a bus stop to add it to favourites"),
                leading: isLoaded ? Icon(Icons.favorite) : null,
              ),
            ),
          );
  }
}
