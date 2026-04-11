import 'package:flutter/material.dart';
import 'package:sgbus/components/directionSearchDelegate.dart';
import 'package:sgbus/pages/directionsPage.dart';
import 'package:sgbus/scripts/data.dart';

class DirectionsSearchBarWidget extends StatelessWidget {
  const DirectionsSearchBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: !isDark ? Border.all(color: Colors.grey) : null,
            color: Theme.of(context).colorScheme.surface),
        child: Ink(
          child: InkWell(
            onTap: () async {
              var res = await showSearch(
                  context: context, delegate: DSearchDelegate(showLoc: false));
              if (res != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DirectionsPage(placeData: res),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 15, right: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      "Search for places",
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
