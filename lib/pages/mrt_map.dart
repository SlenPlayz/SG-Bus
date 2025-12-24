import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class MRTMap extends StatelessWidget {
  const MRTMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: InteractiveViewer(
        maxScale: 10,
        child: Stack(
          children: [
            Center(
              child: ExpressiveLoadingIndicator(),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image(
                  image: AssetImage('assets/mrt-map.jpg'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
