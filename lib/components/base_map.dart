import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaseMap extends StatefulWidget {
  final CameraOptions? cameraOptions;
  final void Function(MapboxMap mapboxMap)? onMapCreated;
  final void Function(MapboxMap mapboxMap)? onStyleLoaded;
  final void Function(MapContentGestureContext gestureContext)? onMapTap;
  final double fabBottomPadding;
  final Widget? overlay;
  final bool showScaleBar;
  final bool showCompass;
  final double? topPadding;

  const BaseMap({
    Key? key,
    this.cameraOptions,
    this.onMapCreated,
    this.onStyleLoaded,
    this.onMapTap,
    this.fabBottomPadding = 16.0,
    this.overlay,
    required this.showScaleBar,
    required this.showCompass,
    this.topPadding,
  }) : super(key: key);

  @override
  _BaseMapState createState() => _BaseMapState();
}

ViewPadding getSafeAreaPadding() {
  final FlutterView view = PlatformDispatcher.instance.views.first;
  return view.viewPadding;
}

class _BaseMapState extends State<BaseMap> {
  MapboxMap? mapboxMap;
  gl.Position? currLocation;
  bool _isSatelliteView = false;
  bool _isPreferencesLoaded = false;
  String? _currentStyleUri;
  bool locationError = false;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isSatelliteView = prefs.getBool('isSatelliteView') ?? false;
        _isPreferencesLoaded = true;
      });
    }
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
    ));
    if (widget.showCompass) {
      mapboxMap.compass.updateSettings(CompassSettings(
        enabled: true,
        marginTop: widget.topPadding ?? 0,
        marginRight: 10,
      ));
    } else {
      mapboxMap.compass.updateSettings(CompassSettings(
        enabled: false,
      ));
    }
    if (widget.showScaleBar) {
      mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
        enabled: widget.showScaleBar,
        marginTop: widget.topPadding ?? 0,
        marginLeft: 20,
        isMetricUnits: true,
      ));
    } else {
      mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
        enabled: false,
      ));
    }

    _currentStyleUri = (_isSatelliteView || isDark)
        ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
        : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m";

    if (widget.onMapCreated != null) {
      widget.onMapCreated!(mapboxMap);
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (mapboxMap == null) return;

    if (widget.onStyleLoaded != null) {
      widget.onStyleLoaded!(mapboxMap!);
    }

    if (_isSatelliteView) {
      await _toggleSatelliteMode(true);
    }

    if (widget.onMapTap != null) {
      mapboxMap!.setOnMapTapListener(widget.onMapTap!);
    }
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

    final targetStyleUri = (enableSatellite || isDark)
        ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
        : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m";

    if (_currentStyleUri != targetStyleUri) {
      _currentStyleUri = targetStyleUri;
      await mapboxMap!.loadStyleURI(targetStyleUri);
      return;
    }

    try {
      final style = mapboxMap!.style;
      if (enableSatellite) {
        final sourceExists = await style.styleSourceExists("onemap-sat-source");
        if (!sourceExists) {
          await style.addSource(RasterSource(
            id: "onemap-sat-source",
            tiles: [
              "https://www.onemap.gov.sg/maps/tiles/Satellite/{z}/{x}/{y}.png"
            ],
            tileSize: 128.0,
            bounds: [103.5, 1.1, 104.1, 1.5],
          ));
        }

        final layers = await style.getStyleLayers();
        final layerIds =
            layers.where((l) => l != null).map((l) => l!.id).toList();

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
                rasterContrast: 0.20,
              ),
              position,
            );
          } else {
            await style.addLayer(
              RasterLayer(
                id: "onemap-sat-layer",
                sourceId: "onemap-sat-source",
              ),
            );
          }
        } else {
          await _setLayerVisibility("onemap-sat-layer", true);
        }

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
        await _setLayerVisibility("onemap-sat-layer", false);

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
  Widget build(BuildContext context) {
    if (!_isPreferencesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MapWidget(
          cameraOptions: widget.cameraOptions ??
              CameraOptions(
                center: Point(
                  coordinates: currLocation != null
                      ? Position(
                          currLocation!.longitude, currLocation!.latitude)
                      : Position(103.8198, 1.290270),
                ),
                zoom: currLocation != null ? 17 : 9,
              ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          styleUri: (_isSatelliteView || isDark)
              ? "mapbox://styles/slen/cl4p0y50c000a15qhcozehloa"
              : "mapbox://styles/slen/clb64djkx000014pcw46b1h9m",
        ),
        Positioned(
          bottom: widget.fabBottomPadding,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'map_layer_toggle_${widget.hashCode}',
                onPressed: () {
                  _showMapTypeBottomSheet(context);
                },
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'my_location_${widget.hashCode}',
                onPressed: () async {
                  final res = await LocationHelper.getUserLocation(context);
                  if (!res.hasError && res.position != null) {
                    setState(() {
                      locationError = false;
                      currLocation = res.position;
                    });
                    mapboxMap?.flyTo(
                        CameraOptions(
                          zoom: 17,
                          center: Point(
                            coordinates: Position(res.position!.longitude,
                                res.position!.latitude),
                          ),
                        ),
                        MapAnimationOptions(
                          duration: 2000,
                          startDelay: 0,
                        ));
                  } else {
                    setState(() {
                      locationError = true;
                    });
                  }
                },
                child: (!locationError)
                    ? const Icon(Icons.my_location)
                    : const Icon(Icons.location_disabled_rounded),
              ),
            ],
          ),
        ),
        if (widget.overlay != null) widget.overlay!,
      ],
    );
  }
}
