import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart' as gpa;
import 'package:live_activities/live_activities.dart';

// ─── Top-level callback (MUST be top-level or static) ───

@pragma('vm:entry-point')
void navigationServiceCallback() {
  FlutterForegroundTask.setTaskHandler(NavigationTaskHandler());
}

// ─── Task Handler (runs in background isolate) ───

class NavigationTaskHandler extends TaskHandler {
  StreamSubscription<gl.Position>? _posStream;

  // Route data loaded from storage
  List<Map<String, dynamic>> _legs = [];
  List<List<double>> _allPoints = []; // [lat, lng] for each decoded point
  List<int> _pointToLegIndex = []; // maps each point index -> leg index
  double _destLat = 0;
  double _destLng = 0;
  String _destName = '';
  String _startName = '';
  DateTime? _tripStartTime;

  int _currentLegIndex = 0;
  bool _arrived = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Load route data saved by NavigationService
    final routeJson =
        await FlutterForegroundTask.getData<String>(key: 'nav_route');
    if (routeJson == null) return;

    final routeData = jsonDecode(routeJson) as Map<String, dynamic>;
    _destName = routeData['destName'] ?? 'Destination';
    _startName = routeData['startName'] ?? '';
    _destLat = (routeData['destLat'] as num).toDouble();
    _destLng = (routeData['destLng'] as num).toDouble();
    _tripStartTime = DateTime.tryParse(routeData['tripStartTime'] ?? '') ??
        DateTime.now();

    // Parse legs
    final legsRaw = routeData['legs'] as List<dynamic>;
    _legs = legsRaw.cast<Map<String, dynamic>>();

    // Decode all polyline points and map them to legs
    _allPoints = [];
    _pointToLegIndex = [];
    for (int i = 0; i < _legs.length; i++) {
      final encoded = _legs[i]['legGeometry']?['points'] as String? ?? '';
      if (encoded.isEmpty) continue;
      final decoded = gpa.decodePolyline(encoded);
      for (var pt in decoded) {
        _allPoints.add([pt[0].toDouble(), pt[1].toDouble()]);
        _pointToLegIndex.add(i);
      }
    }

    // Start GPS stream
    _posStream = gl.Geolocator.getPositionStream(
      locationSettings: Platform.isAndroid
          ? gl.AndroidSettings(
              intervalDuration: Duration(seconds: 3),
              accuracy: gl.LocationAccuracy.high,
            )
          : gl.AppleSettings(
              accuracy: gl.LocationAccuracy.high,
              activityType: gl.ActivityType.otherNavigation,
              allowBackgroundLocationUpdates: true,
              showBackgroundLocationIndicator: true,
            ),
    ).listen(_onLocationUpdate);
  }

  void _onLocationUpdate(gl.Position pos) {
    if (_arrived || _allPoints.isEmpty) return;

    // Find nearest point
    double minDist = double.infinity;
    int nearestIdx = 0;
    for (int i = 0; i < _allPoints.length; i++) {
      final d = gl.Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _allPoints[i][0],
        _allPoints[i][1],
      );
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    _currentLegIndex = _pointToLegIndex[nearestIdx];

    // Check arrival
    final distToDest = gl.Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _destLat,
      _destLng,
    );

    if (distToDest < 50) {
      _arrived = true;
      _updateNotification();
      _sendDataToMain();
      // Stop after a short delay
      Future.delayed(Duration(seconds: 5), () {
        FlutterForegroundTask.stopService();
      });
      return;
    }

    _updateNotification();
    _sendDataToMain();
  }

  void _updateNotification() {
    final elapsed = _tripStartTime != null
        ? DateTime.now().difference(_tripStartTime!).inMinutes
        : 0;

    if (_arrived) {
      FlutterForegroundTask.updateService(
        notificationTitle: '🎉 You\'ve arrived!',
        notificationText: 'Welcome to $_destName • Trip took ${elapsed} min',
      );
      return;
    }

    if (_currentLegIndex >= _legs.length) return;
    final leg = _legs[_currentLegIndex];
    final mode = leg['mode'] as String? ?? 'WALK';
    final route = leg['route'] as String? ?? '';
    final stopsLeft = _calculateStopsLeft(leg);
    final alightStop = _getAlightStop(leg);

    String title;
    String text;

    switch (mode) {
      case 'BUS':
        title = '🚌 Bus $route';
        text =
            '$stopsLeft stop${stopsLeft == 1 ? '' : 's'} to $alightStop • ${elapsed} min';
        break;
      case 'SUBWAY':
        title = '🚇 $route Line';
        text =
            '$stopsLeft stop${stopsLeft == 1 ? '' : 's'} to $alightStop • ${elapsed} min';
        break;
      default:
        title = '🚶 Walking';
        text = 'to ${alightStop.isNotEmpty ? alightStop : _destName} • ${elapsed} min';
        break;
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  int _calculateStopsLeft(Map<String, dynamic> leg) {
    final stops = leg['intermediateStops'] as List?;
    if (stops == null) return 0;
    // Simple estimate: total stops minus current progress through this leg
    return stops.length + 1;
  }

  String _getAlightStop(Map<String, dynamic> leg) {
    final toName = leg['to']?['name'] as String?;
    return toName ?? _destName;
  }

  void _sendDataToMain() {
    final elapsed = _tripStartTime != null
        ? DateTime.now().difference(_tripStartTime!).inMinutes
        : 0;

    final leg =
        _currentLegIndex < _legs.length ? _legs[_currentLegIndex] : null;
    final mode = leg?['mode'] as String? ?? 'WALK';
    final route = leg?['route'] as String? ?? '';
    final stopsLeft = leg != null ? _calculateStopsLeft(leg) : 0;
    final alightStop = leg != null ? _getAlightStop(leg) : '';

    FlutterForegroundTask.sendDataToMain({
      'currentLegIndex': _currentLegIndex,
      'arrived': _arrived,
      'elapsedMinutes': elapsed,
      'legMode': mode,
      'legRoute': route,
      'stopsLeft': stopsLeft,
      'alightStop': alightStop,
      'destName': _destName,
      'totalLegs': _legs.length,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We use the GPS stream instead of repeat events,
    // but we still update the notification periodically for elapsed time.
    if (!_arrived) {
      _updateNotification();
      _sendDataToMain();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _posStream?.cancel();
    _posStream = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is String && data == 'stop') {
      _posStream?.cancel();
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      _posStream?.cancel();
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {
    // Notification was dismissed - do nothing, service keeps running
  }
}

// ─── Navigation Service (called from main isolate / UI) ───

class NavigationService {
  static final LiveActivities _liveActivities = LiveActivities();
  static String? _liveActivityId;
  static bool _initialized = false;

  /// Initialize the foreground task configuration. Call once at app startup.
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sgbus_navigation',
        channelName: 'Route Navigation',
        channelDescription:
            'Shows your current route progress while navigating.',
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false, // We use Live Activity instead
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start background navigation tracking.
  static Future<void> startNavigation({
    required Map route,
    required String destName,
    required String startName,
    required double destLat,
    required double destLng,
    required DateTime tripStartTime,
  }) async {
    // Request notification permission (Android 13+)
    final notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Serialize route data for the background isolate
    final routeData = {
      'destName': destName,
      'startName': startName,
      'destLat': destLat,
      'destLng': destLng,
      'tripStartTime': tripStartTime.toIso8601String(),
      'legs': route['legs'],
    };
    await FlutterForegroundTask.saveData(
      key: 'nav_route',
      value: jsonEncode(routeData),
    );

    // Start the foreground service (Android)
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 500,
        notificationTitle: '🧭 Navigating to $destName',
        notificationText: 'Starting route...',
        notificationButtons: [
          const NotificationButton(id: 'btn_stop', text: 'End Trip'),
        ],
        callback: navigationServiceCallback,
      );
    }

    // Start iOS Live Activity
    if (Platform.isIOS) {
      await _startLiveActivity(
        destName: destName,
        startName: startName,
        totalLegs: (route['legs'] as List).length,
      );
    }
  }

  /// Stop background navigation tracking.
  static Future<void> stopNavigation() async {
    // Stop foreground service
    await FlutterForegroundTask.stopService();

    // End iOS Live Activity
    if (Platform.isIOS && _liveActivityId != null) {
      await _liveActivities.endActivity(_liveActivityId!);
      _liveActivityId = null;
    }

    // Cleanup saved data
    await FlutterForegroundTask.removeData(key: 'nav_route');
  }

  /// Update the iOS Live Activity with new navigation data.
  static Future<void> updateLiveActivity({
    required String legMode,
    required String legRoute,
    required int stopsLeft,
    required String destName,
    required int elapsedMinutes,
    required int totalLegs,
    required int currentLegIndex,
    required bool arrived,
    required String alightStop,
    String? nextBusMin,   // e.g. "5" or "Arr"
    String? nextBus2Min,  // e.g. "12"
  }) async {
    if (!Platform.isIOS || _liveActivityId == null) return;

    final data = <String, dynamic>{
      'legMode': legMode,
      'legRoute': legRoute,
      'stopsLeft': stopsLeft,
      'destName': destName,
      'elapsedMinutes': elapsedMinutes,
      'totalLegs': totalLegs,
      'currentLegIndex': currentLegIndex,
      'arrived': arrived,
      'alightStop': alightStop,
      'nextBusMin': nextBusMin ?? '',
      'nextBus2Min': nextBus2Min ?? '',
    };

    await _liveActivities.createOrUpdateActivity(_liveActivityId!, data);
  }

  /// Check if the navigation service is currently running.
  static Future<bool> get isNavigating async =>
      await FlutterForegroundTask.isRunningService;

  // ─── Private helpers ───

  static Future<void> _startLiveActivity({
    required String destName,
    required String startName,
    required int totalLegs,
  }) async {
    if (!_initialized) {
      await _liveActivities.init(appGroupId: 'group.com.slen.sgbus');
      _initialized = true;
    }

    final data = <String, dynamic>{
      'legMode': 'WALK',
      'legRoute': '',
      'stopsLeft': 0,
      'destName': destName,
      'elapsedMinutes': 0,
      'totalLegs': totalLegs,
      'currentLegIndex': 0,
      'arrived': false,
      'alightStop': '',
    };

    _liveActivityId = await _liveActivities.createOrUpdateActivity('sgbus_navigation', data);
  }
}
