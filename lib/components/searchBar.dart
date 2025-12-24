import 'package:flutter/material.dart';
import 'package:sgbus/components/searchPage.dart'; // Ensure this path is correct

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({Key? key, this.callback}) : super(key: key);

  final VoidCallback? callback;

  @override
  Widget build(BuildContext context) {
    // Note: We don't need 'width' here anymore since we want it to auto-size

    return Hero(
      tag: 'searchBarHero',
      child: Material(
        color: Colors.transparent,
        child: Container(
          // No explicit width; let the child Row determine the size
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(200),
            onTap: () async {
              await Navigator.of(context).push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  reverseTransitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const CustomSearchPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
              if (callback != null) callback!();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Search for stops, roads or buses",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
