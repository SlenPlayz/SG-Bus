import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/base_map.dart';
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
  bool isAdLoaded = false;
  late AdWidget adWidget;
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

  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      setState(() => isAdLoaded = true);
    } catch (err, stackTrace) {
      await Sentry.captureException(err, stackTrace: stackTrace);
      if (!kReleaseMode) print(err);
    }
  }

  @override
  void initState() {
    if (adsEnabled) loadAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Scaffold(
              appBar: AppBar(title: Text(widget.name)),
              body: BaseMap(
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(103.8198, 1.290270)),
                  zoom: 9,
                ),
                onMapCreated: (map) => mapboxMap = map,
                onStyleLoaded: _flyToStop,
                onMapTap: onTapListener,
                showCompass: true,
                showScaleBar: true,
                topPadding: 10,
                // All 4 toggles shown (default)
              ),
            ),
          ),
          isAdLoaded
              ? Container(
                  alignment: Alignment.center,
                  child: adWidget,
                  width: Ad.size.width.toDouble(),
                  height: Ad.size.height.toDouble(),
                )
              : Container()
        ],
      ),
    );
  }
}
