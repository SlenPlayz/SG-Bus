# SGBus

A Flutter based android app (not tested on other platforms) to get arrival timings for Singapore buses based on the material 3 design spec.

## Features
 - Material 3 design with Material You support
 - Stop Maps
 - Favourite stops
 - Nearby stops
 - Search for stops and buses
 - Map of Singapore with stops
 - MRT map
 - View bus routes
 - View bus routes on a map
 
## Running locally
 1. Rename `lib/env.example/dart` to `lib/env.dart` and fill in using instructions in the file
 2. Ensure flutter is installed and that you can develop for android by running `flutter doctor` in your terminal
 3. Connect android device to computer and enable usb debugging on the android device (if using physical device)
 4. Ensure device is connected by running `adb devices -l` in your terminal and check if your device is listed
 5. Run `flutter run` to debug
 6. Run `flutter build apk --split-per-abi` to build an apk file

## Credits
 - Data for stops, services and routes taken from [@cheeaun/sgbusdata](https://github.com/cheeaun/sgbusdata)
 - Arrival timings provided by [LTA Datamall](https://datamall.lta.gov.sg/content/datamall/en.html)
 - App built with [Flutter](https://flutter.dev)
 ### Packages used
  - [dynamic_colour](https://pub.dev/packages/dynamic_color) for Material You colours
  - [restart_app](https://pub.dev/packages/restart_app) to restart app after dataset updates
  - [shared_preferences](https://pub.dev/packages/shared_preferences) to store stops, services and route data and favourites
  - [geolocator](https://pub.dev/packages/geolocator) to get device location
  - [latlong2](https://pub.dev/packages/latlong2) additional utillities for managing positions
  - [http](https://pub.dev/packages/http) to communicate with server
  - [flutter_map](https://pub.dev/packages/flutter_map) for maps
  - [flutter_map_marker_cluster](https://pub.dev/packages/flutter_map_marker_cluster) to reduce lag when displaying lots of markers
  - [flutter_map_location_marker](https://pub.dev/packages/flutter_map_location_marker) to display a location marker on the map to indicate where you are
