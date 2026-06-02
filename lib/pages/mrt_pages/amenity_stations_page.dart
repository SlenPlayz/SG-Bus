import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/components/trainStationListView.dart';
import 'package:sgbus/pages/mrt_pages/station_page.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sgbus/scripts/location_helper.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AmenityStationsPage extends StatefulWidget {
  final String amenityName;
  const AmenityStationsPage({super.key, required this.amenityName});

  @override
  State<AmenityStationsPage> createState() => _AmenityStationsPageState();
}

class _AmenityStationsPageState extends State<AmenityStationsPage> {
  List<dynamic> matchingStations = [];
  MapboxMap? mapboxMap;
  CircleAnnotationManager? circleAnnotationManager;

  bool _isLocating = true;
  geo.Position? _userPosition;

  @override
  void initState() {
    super.initState();
    final data = getMRTData();
    if (data['stations'] != null) {
      for (var s in data['stations']) {
        final amenities = s['amenities'] as List? ?? [];
        if (amenities
            .any((a) => (a['name'] as String? ?? '') == widget.amenityName)) {
          matchingStations.add(Map<String, dynamic>.from(s));
        }
      }
    }

    _getLocationAndSort();
  }

  Future<void> _getLocationAndSort() async {
    try {
      final LocationResult result =
          await LocationHelper.getUserLocation(context);
      if (result.hasError || result.position == null) {
        setState(() {
          _isLocating = false;
        });
        return;
      }

      _userPosition = result.position;

      for (var s in matchingStations) {
        final lat = s['latitude'] as double?;
        final lng = s['longitude'] as double?;
        if (lat != null && lng != null) {
          final dist = geo.Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            lat,
            lng,
          );
          s['dist'] = dist.round();
        } else {
          s['dist'] = 9999999;
        }
      }

      matchingStations.sort((a, b) => (a['dist'] as int? ?? 9999999)
          .compareTo(b['dist'] as int? ?? 9999999));
    } catch (e) {
      print("Error getting location: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _onStyleLoaded(MapboxMap map) async {
    mapboxMap = map;
    try {
      circleAnnotationManager =
          await map.annotations.createCircleAnnotationManager();

      final annotations = matchingStations.map((s) {
        return CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(s['longitude'], s['latitude']),
          ),
          circleRadius: 10.0,
          circleColor: Theme.of(context).colorScheme.primary.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        );
      }).toList();

      await circleAnnotationManager?.createMulti(annotations);
    } catch (e) {
      print("Error creating circle annotations: $e");
    }

    // Fit camera to the bounds of all matching stations if possible
    if (matchingStations.isNotEmpty) {
      double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
      for (var s in matchingStations) {
        final lat = s['latitude'] as double;
        final lng = s['longitude'] as double;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      if (maxLat - minLat < 0.001) {
        minLat -= 0.001;
        maxLat += 0.001;
      }
      if (maxLng - minLng < 0.001) {
        minLng -= 0.001;
        maxLng += 0.001;
      }

      try {
        CameraOptions cameraOptions = await map.cameraForCoordinateBounds(
          CoordinateBounds(
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
            infiniteBounds: false,
          ),
          MbxEdgeInsets(top: 100.0, left: 50.0, bottom: 400.0, right: 50.0),
          null,
          null,
          null,
          null,
        );
        map.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));
      } catch (e) {
        print("Camera bounds error: $e");
      }
    }
  }

  Future<void> _onMapTap(MapContentGestureContext gestureContext) async {
    if (mapboxMap == null) return;

    // We can query the map features. We know BaseMap adds 'mrt_station_circle_layer'
    // Let's use that to capture clicks on stations, which is simple and robust.
    final conv = gestureContext.touchPosition;
    try {
      final features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(
            ScreenCoordinate(x: conv.x, y: conv.y)),
        RenderedQueryOptions(layerIds: ['mrt_station_circle_layer']),
      );

      if (features.isNotEmpty) {
        final feature = features[0]?.queriedFeature.feature;
        if (feature != null) {
          final properties = feature['properties'] as Map<String, dynamic>?;
          if (properties != null && properties['code'] != null) {
            final code = properties['code'].toString().split('/').first;
            if (code.isNotEmpty) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StationPage(stationCode: code)));
            }
          }
        }
      } else {
        // As a fallback, check if they tapped near our custom circle annotations by distance
        final point = gestureContext.point;
        final pointLng = point.coordinates.lng;
        final pointLat = point.coordinates.lat;

        dynamic closestStation;
        double minDistance = double.infinity;

        for (var s in matchingStations) {
          // Simple euclidean distance approximation for small map area selection
          final d = (s['longitude'] - pointLng) * (s['longitude'] - pointLng) +
              (s['latitude'] - pointLat) * (s['latitude'] - pointLat);
          if (d < minDistance) {
            minDistance = d;
            closestStation = s;
          }
        }

        // 0.0000005 squared degree ~ roughly small tap radius
        if (minDistance < 0.0000005 && closestStation != null) {
          final codes = closestStation['codes'] as List? ?? [];
          if (codes.isNotEmpty) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StationPage(stationCode: codes.first)));
          }
        }
      }
    } catch (e) {
      print('Error querying map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            widget.amenityName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BaseMap(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.8198, 1.3521)),
                zoom: 10.5,
              ),
              onStyleLoaded: _onStyleLoaded,
              onMapTap: _onMapTap,
              showCompass: true,
              showScaleBar: true,
              topPadding: MediaQuery.paddingOf(context).top + kToolbarHeight,
              fabBottomPadding: height * 0.4 + 10,
              showBusStopsToggle: false,
              loadDefaultBusStops: false,
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            snap: true,
            snapSizes: const [0.4, 0.8],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.storefront,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${matchingStations.length} Station${matchingStations.length == 1 ? ' has' : 's have'} ${widget.amenityName}',
                              overflow: TextOverflow.fade,
                              softWrap: true,
                              maxLines: 2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontVariations: [
                                FontVariation('ROND', 100),
                                FontVariation.width(110),
                                FontVariation.weight(900),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // const Divider(height: 24),
                    const SizedBox(
                      height: 24,
                    ),
                    Expanded(
                      child:
                          // _isLocating
                          //     ? Center(
                          //         child: Card(
                          //           margin: const EdgeInsets.all(24),
                          //           child: Padding(
                          //             padding: const EdgeInsets.all(32.0),
                          //             child: Column(
                          //               mainAxisSize: MainAxisSize.min,
                          //               children: [
                          //                 const ExpressiveLoadingIndicator(),
                          //                 const SizedBox(height: 24),
                          //                 Text(
                          //                   "Getting ${widget.amenityName}s near you...",
                          //                   style: Theme.of(context)
                          //                       .textTheme
                          //                       .titleMedium!
                          //                       .copyWith(fontVariations: [
                          //                     FontVariation('ROND', 100),
                          //                     FontVariation.width(110),
                          //                     FontVariation.weight(900),
                          //                   ]),
                          //                   textAlign: TextAlign.center,
                          //                 ),
                          //               ],
                          //             ),
                          //           ),
                          //         ),
                          //       )
                          //     :
                          matchingStations.isEmpty
                              ? const Center(child: Text('No stations found'))
                              : Skeletonizer(
                                  enabled: _isLocating,
                                  child: Container(
                                    padding: const EdgeInsets.only(
                                        top: 0, bottom: 20, left: 8, right: 8),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadiusGeometry.circular(28),
                                      child: ListView.builder(
                                        controller: scrollController,
                                        padding: const EdgeInsets.only(
                                          top: 0,
                                        ),
                                        itemCount: matchingStations.length,
                                        itemBuilder: (context, index) {
                                          final station =
                                              matchingStations[index];
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant
                                                  .withOpacity(0.3),
                                              borderRadius: BorderRadius.only(
                                                topLeft: index == 0
                                                    ? const Radius.circular(28)
                                                    : const Radius.circular(5),
                                                topRight: index == 0
                                                    ? const Radius.circular(28)
                                                    : const Radius.circular(5),
                                                bottomLeft: index ==
                                                        matchingStations
                                                                .length -
                                                            1
                                                    ? const Radius.circular(28)
                                                    : const Radius.circular(5),
                                                bottomRight: index ==
                                                        matchingStations
                                                                .length -
                                                            1
                                                    ? const Radius.circular(28)
                                                    : const Radius.circular(5),
                                              ),
                                            ),
                                            child: TrainStationListTile(
                                              station: station,
                                              showCode:
                                                  _isLocating ? false : true,
                                              trailing: station['dist'] != null
                                                  ? Text('${station['dist']}m',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall)
                                                  : null,
                                              onTap: () {
                                                final codes =
                                                    station['codes'] as List? ??
                                                        [];
                                                if (codes.isNotEmpty) {
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              StationPage(
                                                                  stationCode: codes
                                                                      .first)));
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
