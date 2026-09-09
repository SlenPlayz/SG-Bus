import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sgbus/components/base_map.dart';
import 'package:sgbus/components/floating_ad.dart';
import 'package:sgbus/scripts/data_management/weather_service.dart';

class WeatherRadarMap extends StatefulWidget {
  const WeatherRadarMap({Key? key}) : super(key: key);

  @override
  State<WeatherRadarMap> createState() => _WeatherRadarMapState();
}

class _WeatherRadarMapState extends State<WeatherRadarMap> {
  final WeatherService _weatherService = WeatherService();

  MapboxMap? _mapboxMap;
  RadarData? _radarData;
  bool _isLoading = true;
  int _currentFrameIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  static const double _opacity = 0.70;
  int _activeLayerIndex = 0;
  bool _adFailedToLoad = false;

  @override
  void initState() {
    super.initState();
    _loadRadarData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRadarData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    _playbackTimer?.cancel();
    _isPlaying = false;

    try {
      final data = await _weatherService.fetchWeatherRadar(
        range: '70km',
        fetchHistory: true,
      );

      if (mounted && data != null && data.frames.isNotEmpty) {
        setState(() {
          _radarData = data;
          _currentFrameIndex = data.frames.length - 1; // Start at latest
          _isLoading = false;
        });

        if (_mapboxMap != null) {
          await _applyCurrentFrame();
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading radar data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyCurrentFrame() async {
    final map = _mapboxMap;
    final data = _radarData;
    if (map == null || data == null || data.frames.isEmpty) return;

    final frame = data.frames[_currentFrameIndex];
    final nextIndex = 1 - _activeLayerIndex;
    final nextSourceId = 'nea-radar-source-$nextIndex';
    final nextLayerId = 'nea-radar-layer-$nextIndex';
    final prevSourceId = 'nea-radar-source-$_activeLayerIndex';
    final prevLayerId = 'nea-radar-layer-$_activeLayerIndex';

    try {
      final style = map.style;

      // Clean up previous next layer if existing
      if (await style.styleLayerExists(nextLayerId)) {
        await style.removeStyleLayer(nextLayerId);
      }
      if (await style.styleSourceExists(nextSourceId)) {
        await style.removeStyleSource(nextSourceId);
      }

      // Add new source and layer
      final coords = data.boundaryBox.toMapboxCoordinates();
      await style.addSource(ImageSource(
        id: nextSourceId,
        url: frame.url,
        coordinates: coords,
      ));

      await style.addLayer(RasterLayer(
        id: nextLayerId,
        sourceId: nextSourceId,
        slot: LayerSlot.TOP,
        rasterOpacity: _opacity,
        rasterFadeDuration: 0.0,
      ));

      // Remove previous layer after new one is placed to prevent flicker
      if (await style.styleLayerExists(prevLayerId)) {
        await style.removeStyleLayer(prevLayerId);
      }
      if (await style.styleSourceExists(prevSourceId)) {
        await style.removeStyleSource(prevSourceId);
      }

      _activeLayerIndex = nextIndex;
    } catch (e) {
      print('Error applying radar frame: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoaded(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    if (_radarData != null && _radarData!.frames.isNotEmpty) {
      _applyCurrentFrame();
    }
  }

  void _togglePlayback() {
    if (_radarData == null || _radarData!.frames.isEmpty) return;

    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      _playbackTimer?.cancel();
      _playbackTimer =
          Timer.periodic(const Duration(milliseconds: 750), (timer) {
        if (!mounted || _radarData == null || _radarData!.frames.isEmpty) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentFrameIndex =
              (_currentFrameIndex + 1) % _radarData!.frames.length;
        });
        _applyCurrentFrame();
      });
    }
  }

  void _goToFrame(int index) {
    if (_radarData == null || index < 0 || index >= _radarData!.frames.length) {
      return;
    }
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _isPlaying = false;
    }
    setState(() {
      _currentFrameIndex = index;
    });
    _applyCurrentFrame();
  }

  void _stepFrame(int delta) {
    if (_radarData == null || _radarData!.frames.isEmpty) return;
    int next = _currentFrameIndex + delta;
    if (next < 0) next = 0;
    if (next >= _radarData!.frames.length) next = _radarData!.frames.length - 1;
    _goToFrame(next);
  }

  void _recenterMap() {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(103.8198, 1.345000)),
        zoom: 9.2,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 800, startDelay: 0),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute $period';
  }

  TextStyle _roundedStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    final weight = fontWeight ?? FontWeight.normal;
    return TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: [
        const FontVariation('ROND', 100),
        FontVariation.weight(weight.index * 100 + 100),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final frames = _radarData?.frames ?? [];
    final currentFrame =
        frames.isNotEmpty && _currentFrameIndex < frames.length
            ? frames[_currentFrameIndex]
            : null;
    final isLatest =
        frames.isNotEmpty && _currentFrameIndex == frames.length - 1;

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
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: theme.colorScheme.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "Rain Radar",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontVariations: const [
                    FontVariation('ROND', 100),
                    FontVariation.width(120),
                    FontVariation.weight(1000),
                  ],
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Refresh button
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                color: theme.colorScheme.onSurface,
                onPressed: _isLoading ? null : () => _loadRadarData(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Base Map with clean layer toggles & radar overlay
          Positioned.fill(
            child: BaseMap(
              initialGpsState: GpsState.uncentered,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.8198, 1.345000)),
                zoom: 9.2,
                pitch: 0,
              ),
              loadDefaultBusStops: false,
              showBusStopsToggle: true,
              showTrainLinesToggle: true,
              showStationExitsToggle: true,
              showStationBoundariesToggle: true,
              onMapCreated: _onMapCreated,
              onStyleLoaded: _onStyleLoaded,
              showCompass: true,
              showScaleBar: true,
              topPadding: MediaQuery.paddingOf(context).top + kToolbarHeight,
              bottomPadding: MediaQuery.paddingOf(context).bottom +
                  (_adFailedToLoad ? 154 : 208),
            ),
          ),

          // Loading state overlay if initial load
          if (_isLoading && _radarData == null)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: ExpressiveLoadingIndicator()),
              ),
            ),

          // Floating Radar Controls & Legend Card (Bottom)
          if (_radarData != null && frames.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: (_adFailedToLoad ? 16 : 70) +
                  MediaQuery.paddingOf(context).bottom,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface.withValues(alpha: 0.85)
                          : theme.colorScheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header row: Frame time and live badge
                        Row(
                          children: [
                            // Live indicator / Time
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLatest
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isLatest
                                          ? Colors.green
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isLatest ? "LIVE" : "PAST",
                                    style: _roundedStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLatest
                                          ? Colors.green
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (currentFrame != null)
                              Text(
                                _formatTime(currentFrame.timestamp),
                                style: _roundedStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const Spacer(),

                            // Recenter icon button
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _recenterMap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.center_focus_strong_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Recenter",
                                      style: _roundedStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Playback & Scrubber Row
                        Row(
                          children: [
                            // Prev frame button
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded),
                              iconSize: 22,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: _currentFrameIndex > 0
                                  ? () => _stepFrame(-1)
                                  : null,
                            ),
                            const SizedBox(width: 6),

                            // Play / Pause toggle
                            IconButton.filledTonal(
                              icon: Icon(_isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                              iconSize: 22,
                              onPressed: _togglePlayback,
                            ),
                            const SizedBox(width: 6),

                            // Next frame button
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: 22,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  _currentFrameIndex < frames.length - 1
                                      ? () => _stepFrame(1)
                                      : null,
                            ),

                            // Scrubber Slider
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12),
                                ),
                                child: Slider(
                                  value: _currentFrameIndex.toDouble(),
                                  min: 0,
                                  max: (frames.length - 1).toDouble().clamp(0, 50),
                                  divisions: frames.length > 1
                                      ? frames.length - 1
                                      : 1,
                                  onChanged: (val) {
                                    _goToFrame(val.round());
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Rain Intensity Legend
                        Row(
                          children: [
                            Text(
                              "Light",
                              style: _roundedStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF42A5F5), // Light Blue (Light)
                                      Color(0xFF26A69A), // Cyan / Teal
                                      Color(0xFF66BB6A), // Green (Moderate)
                                      Color(0xFFFFEE58), // Yellow
                                      Color(0xFFFFA726), // Orange (Heavy)
                                      Color(0xFFEF5350), // Red (Very Heavy)
                                      Color(0xFFAB47BC), // Violet/Purple (Intense)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Heavy",
                              style: _roundedStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Floating Ad (identical to StopSpecMap pattern)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: FloatingAd(
                margin: const EdgeInsets.only(bottom: 8),
                onAdFailedToLoad: () {
                  if (mounted) {
                    setState(() {
                      _adFailedToLoad = true;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
