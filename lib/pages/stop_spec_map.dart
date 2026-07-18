import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/components/floating_ad.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/stop.dart';

class StopSpecMap extends StatefulWidget {
  final coords;
  final name;
  const StopSpecMap({Key? key, this.coords, this.name}) : super(key: key);

  @override
  _StopSpecMapState createState() => _StopSpecMapState();
}

class _StopSpecMapState extends State<StopSpecMap> {
  MapboxMap? mapboxMap;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _flyToStop(MapboxMap map) async {
    await map.flyTo(
      CameraOptions(
        anchor: ScreenCoordinate(x: 0, y: 0),
        zoom: 18,
        center: Point(
          coordinates: Position(widget.coords[0], widget.coords[1]),
        ),
      ),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  Future<void> onTapListener(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) return;
    final conv = gestureContext.touchPosition;
    try {
      final features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry(
          value: jsonEncode({'x': conv.x, 'y': conv.y}),
          type: Type.SCREEN_COORDINATE,
        ),
        RenderedQueryOptions(layerIds: ['stops_layer']),
      );
      if (features.isNotEmpty &&
          features[0]?.queriedFeature.feature['id'] != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                Stop(features[0]!.queriedFeature.feature['id'].toString())));
      }
    } catch (e) {
      print('Error querying map: $e');
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.width(120),
                FontVariation.weight(1000)
              ],
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BaseMap(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.8198, 1.290270)),
                zoom: 9,
              ),
              onMapCreated: (map) => mapboxMap = map,
              onStyleLoaded: _flyToStop,
              onMapTap: onTapListener,
              showCompass: true,
              showScaleBar: true,
              topPadding: MediaQuery.paddingOf(context).top + kToolbarHeight,
              bottomPadding: MediaQuery.paddingOf(context).bottom + 65,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: FloatingAd(
                margin: const EdgeInsets.only(
                  bottom: 8,
                  // left: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
