# SGBus

A Flutter based android app (not tested on other platforms) to get arrival timings for Singapore buses based on the material 3 design spec.

## Features
 - Material 3 design with Material You support
 - Custom Themes
 - Favourite stops
 - Nearby stops
 - Stop Maps
 - Search for stops and buses
 - MRT map
 - View bus routes + map
 
## Running locally
 1. Clone this Repo by running `git clone https://github.com/SlenPlayz/SG-Bus.git`
 1. Rename `lib/env.example/dart` to `lib/env.dart` and fill in using instructions in the file
 1. Setup Mapbox credentials using [these instructions](https://docs.mapbox.com/android/maps/guides/install/#configure-credentials)
 1. Ensure flutter is installed and that you can develop for android by running `flutter doctor` in your terminal
 1. Connect android device to computer through adb
 1. Ensure device is connected by running `adb devices -l` in your terminal and check if your device is listed
 1. Run `flutter run` to debug
 1. Run `flutter build apk --split-per-abi` to build an apk file

## Credits
 - Data for stops, services and routes taken and modified from [@cheeaun/sgbusdata](https://github.com/cheeaun/sgbusdata) into [@SlenPlayz/sgbusdata](https://github.com/SlenPlayz/sgbusdata)
 - Arrival timings provided by [LTA Datamall](https://datamall.lta.gov.sg/content/datamall/en.html)
 - App built with [Flutter](https://flutter.dev)
 - Map made with [Mapbox](https://www.mapbox.com/)