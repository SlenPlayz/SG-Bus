import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class MRTMap extends StatelessWidget {
  const MRTMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton.filled(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded),
          color: Theme.of(context).colorScheme.onSurface,
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(
                Theme.of(context).colorScheme.surfaceVariant),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: ClipRRect(
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
      ),
    );
  }
}
