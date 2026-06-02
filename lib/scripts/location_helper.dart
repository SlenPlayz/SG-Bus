import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum LocationErrorType {
  disabled,
  denied,
  deniedForever,
  unknown,
}

class LocationResult {
  final Position? position;
  final LocationErrorType? errorType;
  final String? errorMessage;

  LocationResult.success(this.position)
      : errorType = null,
        errorMessage = null;

  LocationResult.error(this.errorType, this.errorMessage) : position = null;

  bool get hasError => errorMessage != null;
}

class LocationHelper {
  static Future<LocationResult> getUserLocation(BuildContext context) async {
    try {
      // 1. Check if location services are enabled
      final bool isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                icon: Icon(Icons.location_off,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Location Services Disabled'),
                content: const Text(
                    'GPS/Location services are disabled on your device. Please enable them to show your location on the map or find nearby bus stops.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        return LocationResult.error(
          LocationErrorType.disabled,
          'GPS is disabled',
        );
      }

      // 2. Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  icon: Icon(Icons.warning,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('Location Permission Denied'),
                  content: const Text(
                      'Location permission is required to show your location on the map or find nearby bus stops.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          }
          return LocationResult.error(
            LocationErrorType.denied,
            'GPS Permissions not given',
          );
        }
      }

      // If denied forever, prompt to open settings
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                icon: Icon(Icons.settings,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Location Permission Required'),
                content: const Text(
                    'Location permissions are permanently denied. Please enable them in settings to show your location on the map or find nearby bus stops.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
        return LocationResult.error(
          LocationErrorType.deniedForever,
          'GPS Permissions are denied',
        );
      }

      // 3. Retrieve current position
      final Position position =
          await Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 15));
      return LocationResult.success(position);
    } catch (e) {
      if (e.toString().contains("TimeoutException")) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(Icons.settings,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Failed to get GPS Signal'),
              content: const Text(
                  "We are unable to retrieve your current location. You may be in a place with weak signal such as a Lift or on the MRT. Please try again later."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
            );
          },
        );
      }
      return LocationResult.error(
        LocationErrorType.unknown,
        'An error occurred: ${e.toString()}',
      );
    }
  }
}
