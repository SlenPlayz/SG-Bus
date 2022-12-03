import 'package:flutter/material.dart';

class MRTMap extends StatelessWidget {
  const MRTMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 10,
      child: Center(
        child: Image(
          image: AssetImage('assets/mrt-map.jpg'),
        ),
      ),
    );
  }
}
