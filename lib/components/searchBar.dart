import 'package:flutter/material.dart';
import 'package:sgbus/components/searchDelegate.dart';
import 'package:sgbus/pages/settings.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({Key? key, this.callback}) : super(key: key);

  final callback;

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Container(
        width: width,
        height: 50,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: InkWell(
            onTap: () async {
              await showSearch(context: context, delegate: SBSearchDelegate());
              callback();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 15, right: 10),
              child: Row(
                children: [
                  Icon(Icons.search),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text("Search for stops, roads or buses"),
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
