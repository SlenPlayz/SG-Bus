import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/pages/stop.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopsMap extends StatefulWidget {
  const StopsMap({Key? key}) : super(key: key);

  @override
  _StopsMapState createState() => _StopsMapState();
}

ViewPadding getSafeAreaPadding() {
  final FlutterView view = PlatformDispatcher.instance.views.first;
  return view.viewPadding;
}

class _StopsMapState extends State<StopsMap> {
  bool isLoaded = false;
  bool isAdLoaded = false;
  gl.Position? currLocation;
  late AdWidget adWidget;
  String? _stopsGeoJson;
  bool _isSatelliteView = false;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
      enabled: true,
      marginTop: getSafeAreaPadding().top - 45,
      marginLeft: 20,
      isMetricUnits: true,
    ));
    mapboxMap.compass.updateSettings(CompassSettings(
      enabled: true,
      marginTop: getSafeAreaPadding().top - 45,
      marginRight: 10,
    ));

    initStops();
  }

  Future<void> initStops() async {
    if (_stopsGeoJson == null) return;
    await mapboxMap?.style
        .addSource(GeoJsonSource(id: "stops", data: _stopsGeoJson!));
    var stopsLayerJSON = {
      "id": "stops_layer",
      "type": "symbol",
      "source": "stops"
    };
    await mapboxMap?.style.addStyleLayer(json.encode(stopsLayerJSON), null);
    var stopsLayerProperties = {
      'text-field': ['get', 'name'],
      "icon-image": "bus",
      "text-size": 10,
      "text-offset": [0, 2],
      "text-color": isDark ? "#fff" : "#000",
    };
    await mapboxMap?.style.setStyleLayerProperties(
        "stops_layer", json.encode(stopsLayerProperties));

    await mapboxMap?.style.addLayer(CircleLayer(
      id: "stops_circle_layer",
      sourceId: "stops",
      circleRadius: 0.5,
      maxZoom: 15.0,
      circleColor: Colors.blue.value.toInt(),
    ));

    mapboxMap?.setOnMapTapListener(onTapListener);

    if (_isSatelliteView) {
      await _toggleSatelliteMode(true);
    }
  }

  Future<void> onTapListener(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) return;

    final ScreenCoordinate conv = gestureContext.touchPosition;

    try {
      final List<QueriedRenderedFeature?> features =
          await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry(
          value: jsonEncode({
            "x": conv.x,
            "y": conv.y,
          }),
          type: Type.SCREEN_COORDINATE,
        ),
        RenderedQueryOptions(
          layerIds: ["stops_layer"],
        ),
      );

      if (features.isNotEmpty &&
          features[0]?.queriedFeature.feature["id"] != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (builder) =>
                Stop(features[0]!.queriedFeature.feature["id"].toString())));
      }
    } catch (e) {
      print("Error querying map: $e");
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
      isAdLoaded = true;
    } catch (err, stackTrace) {
      await Sentry.captureException(
        err,
        stackTrace: stackTrace,
      );
      if (!kReleaseMode) print(err);
    }
  }

  Future<void> _loadAllDependencies() async {
    setState(() {
      isLoaded = false;
    });

    final List<Future<dynamic>> futures = [
      LocationHelper.getUserLocation(context).then((res) {
        if (!res.hasError) {
          currLocation = res.position;
        }
      }),
      compute(_generateStopsGeoJson, getStops()).then((geoJson) {
        _stopsGeoJson = geoJson;
      }),
      SharedPreferences.getInstance().then((prefs) {
        _isSatelliteView = prefs.getBool('isSatelliteView') ?? false;
      }),
    ];

    if (adsEnabled) {
      futures.add(loadAd());
    }

    try {
      await Future.wait(futures);
    } catch (e, stackTrace) {
      print("Error loading dependencies: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }

    setState(() {
      isLoaded = true;
    });
  }

  Future<void> _setLayerVisibility(String layerId, bool visible) async {
    try {
      final style = mapboxMap?.style;
      if (style != null && await style.styleLayerExists(layerId)) {
        await style.setStyleLayerProperties(
          layerId,
          json.encode({"visibility": visible ? "visible" : "none"}),
        );
      }
    } catch (e) {
      print("Error setting visibility for $layerId: $e");
    }
  }

  Future<void> _toggleSatelliteMode(bool enableSatellite) async {
    if (mapboxMap == null) return;
    setState(() {
      _isSatelliteView = enableSatellite;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSatelliteView', enableSatellite);
    } catch (e) {
      print("Error saving map mode preference: $e");
    }

    try {
      final style = mapboxMap!.style;
      if (enableSatellite) {
        // 1. Add Source: Check if a RasterSource with ID onemap-sat-source exists. If not, add it.
        final sourceExists = await style.styleSourceExists("onemap-sat-source");
        if (!sourceExists) {
          await style.addSource(RasterSource(
            id: "onemap-sat-source",
            tiles: [
              "https://www.onemap.gov.sg/maps/tiles/Satellite/{z}/{x}/{y}.png"
            ],
            // Retina Hack: Force higher resolution rendering
            tileSize: 128.0,
            // Bounding Box: Stop fetching tiles outside of Singapore
            bounds: [103.5, 1.1, 104.1, 1.5],
          ));
        }

        // Retrieve existing layers to determine position and to hide base layers
        final layers = await style.getStyleLayers();
        final layerIds =
            layers.where((l) => l != null).map((l) => l!.id).toList();

        // 2. Add Layer: Check if a RasterLayer with ID onemap-sat-layer exists. If not, add it.
        final layerExists = await style.styleLayerExists("onemap-sat-layer");
        if (!layerExists) {
          LayerPosition? position;
          if (layerIds.contains("background")) {
            position = LayerPosition(above: "background");
          } else if (layerIds.isNotEmpty) {
            position = LayerPosition(below: layerIds.first);
          }

          if (position != null) {
            await style.addLayerAt(
              RasterLayer(
                id: "onemap-sat-layer",
                sourceId: "onemap-sat-source",
                // Native color grading for better visual punch
                rasterContrast: 0.20,
                // rasterSaturation: 0.20,
              ),
              position,
            );
          } else {
            await style.addLayer(
              RasterLayer(
                id: "onemap-sat-layer",
                sourceId: "onemap-sat-source",
                // Native color grading for better visual punch
                // rasterContrast: 0.25,
                // rasterSaturation: 0.20,
              ),
            );
          }
        } else {
          // If the layer already exists, make sure it is visible
          await _setLayerVisibility("onemap-sat-layer", true);
        }

        // 3. Stacking Trick: Hide base layers (background, fill, fill-extrusion, hillshade)
        // so that the satellite layer shows through.
        for (var l in layers) {
          if (l != null && l.id != "onemap-sat-layer") {
            if (l.type == "background" ||
                l.type == "fill" ||
                l.type == "fill-extrusion" ||
                l.type == "hillshade") {
              await _setLayerVisibility(l.id, false);
            }
          }
        }
      } else {
        // Switch to Regular View:
        // 1. Set the visibility of onemap-sat-layer to none.
        await _setLayerVisibility("onemap-sat-layer", false);

        // 2. Restore the visibility of all hidden base layers.
        final layers = await style.getStyleLayers();
        for (var l in layers) {
          if (l != null && l.id != "onemap-sat-layer") {
            if (l.type == "background" ||
                l.type == "fill" ||
                l.type == "fill-extrusion" ||
                l.type == "hillshade") {
              await _setLayerVisibility(l.id, true);
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print("Error in _toggleSatelliteMode: $e");
      await Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  void _showMapTypeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Map View',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontVariations: [
                            FontVariation('ROND', 100),
                            FontVariation.width(120),
                            FontVariation.weight(1000)
                          ],
                        ),
                      ),
                      Opacity(
                        opacity: 0.8,
                        child: Text(
                          "Changes how the map is rendered.",
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontVariations: [
                              FontVariation('ROND', 50),
                              FontVariation.width(105),
                              FontVariation.weight(500),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                RadioListTile<bool>(
                  value: false,
                  groupValue: _isSatelliteView,
                  title: const Text('Regular View'),
                  subtitle: const Text(
                      'High contrast vector map. Quick & efficient. '),
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? value) {
                    if (value != null) {
                      Navigator.pop(context);
                      _toggleSatelliteMode(value);
                    }
                  },
                ),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _isSatelliteView,
                  title: const Text('Satellite View'),
                  subtitle: const Text(
                      'HD Satellite imagery. Uses more data.\nSatellite imagery provided by SLA OneMap.'),
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? value) {
                    if (value != null) {
                      Navigator.pop(context);
                      _toggleSatelliteMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    _loadAllDependencies();
    super.initState();
  }

  @override
  void dispose() {
    Ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: 'map_layer_toggle',
              onPressed: () {
                _showMapTypeBottomSheet(context);
              },
              child: const Icon(Icons.layers),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'my_location',
              onPressed: () async {
                final res = await LocationHelper.getUserLocation(context);
                if (!res.hasError && res.position != null) {
                  setState(() {
                    currLocation = res.position;
                  });
                  mapboxMap?.flyTo(
                      CameraOptions(
                        zoom: 17,
                        center: Point(
                          coordinates: Position(
                              res.position!.longitude, res.position!.latitude),
                        ),
                      ),
                      MapAnimationOptions(
                        duration: 2000,
                        startDelay: 0,
                      ));
                }
              },
              child: (currLocation != null)
                  ? const Icon(Icons.my_location)
                  : const Icon(Icons.location_disabled_rounded),
            ),
          ],
        ),
      ),
      body: isLoaded
          ? Column(
              children: [
                Expanded(
                  child: Scaffold(
                    body: ClipRRect(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18)),
                      child: MapWidget(
                        cameraOptions: CameraOptions(
                          center: Point(
                            coordinates: currLocation != null
                                ? Position(currLocation!.longitude,
                                    currLocation!.latitude)
                                : Position(103.8198, 1.290270),
                          ),
                          zoom: currLocation != null ? 17 : 9,
                        ),
                        onMapCreated: _onMapCreated,
                        styleUri: isDark
                            ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
                            : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m",
                      ),
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
            )
          : const Center(child: ExpressiveLoadingIndicator()),
    );
  }
}

String _generateStopsGeoJson(List data) {
  final Map stopsGeoJsonMap = {
    "type": "FeatureCollection",
    "features": [],
  };

  for (var stop in data) {
    stopsGeoJsonMap["features"].add({
      "type": "Feature",
      "id": stop["id"],
      "properties": {
        "number": stop["id"],
        "name": stop["Name"],
        "road": stop["Road"],
      },
      "geometry": {"type": "Point", "coordinates": stop["cords"]}
    });
  }
  return jsonEncode(stopsGeoJsonMap);
}
