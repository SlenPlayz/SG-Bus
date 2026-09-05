import 'package:flutter/foundation.dart';

/// Timestamped startup diagnostic logger
void logStartup(String stage) {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  final ms = now.millisecond.toString().padLeft(3, '0');
  debugPrint('[STARTUP $h:$m:$s.$ms] $stage');
}

/// Global error hooks to capture any RenderClipRect or layout exceptions during startup
void initStartupLogging() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    debugPrint('[STARTUP-ERROR $h:$m:$s.$ms] EXCEPTION CAUGHT: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[STARTUP-ERROR $h:$m:$s.$ms] STACK TRACE:\n${details.stack}');
    }
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    debugPrint('[STARTUP-UNCAUGHT $h:$m:$s.$ms] UNCAUGHT ASYNC EXCEPTION: $error');
    debugPrint('[STARTUP-UNCAUGHT $h:$m:$s.$ms] STACK TRACE:\n$stack');
    return false;
  };
}
