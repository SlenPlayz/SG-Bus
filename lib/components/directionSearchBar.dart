import 'package:flutter/material.dart';
import 'package:sgbus/components/directionSearchDelegate.dart';
import 'package:sgbus/pages/directions_page.dart';
import 'package:sgbus/pages/place_page.dart';
import 'package:sgbus/scripts/data.dart';

class DirectionsSearchBarWidget extends StatelessWidget {
  const DirectionsSearchBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Container(
        width: width,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: !isDark ? Border.all(color: Colors.grey) : null,
            color: Theme.of(context).colorScheme.surface
            // color: isDark
            //     ? Colors.black.withOpacity(0.9)
            //     : Colors.white.withOpacity(0.98),
            ),
        height: 50,
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
                    // color: Colors.grey,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      "Search for places",
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onSurface,
                        // color: Colors.grey,
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
