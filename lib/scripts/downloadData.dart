import 'dart:convert';

import 'package:http/http.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> downloadData() async {
  const String endpoint = serverURL;
  var prefs = await SharedPreferences.getInstance();

  final stopsEndpoint = Uri.parse('$endpoint/api/data/stops');
  final svcsEndpoint = Uri.parse('$endpoint/api/data/services');

  bool isStopsSuccess = false;
  bool isServicesSuccess = false;

  try {
    await get(stopsEndpoint).then((stopDataAPIResponse) async {
      var stops = stopDataAPIResponse.body;

      bool isStopsDataValid = validateStops(stops);
      if (!isStopsDataValid)
        throw "Invalid Stops data";
      else
        await prefs.setString("stops", stops);

      saveStops(stops);

      isStopsSuccess = true;
    });
  } catch (err, stackTrace) {
    await Sentry.captureException(
      "An error occured while downloading stop data",
      stackTrace: stackTrace,
    );
  }

  try {
    await get(svcsEndpoint).then((serviceDataAPIResponse) async {
      var services = serviceDataAPIResponse.body;

      bool isServiceDataValid = validateServices(services);
      if (!isServiceDataValid)
        throw "Invalid Service data";
      else
        await prefs.setString("svcs", services);

      saveSvcs(services);

      isServicesSuccess = true;
    });
  } catch (err, stackTrace) {
    await Sentry.captureException(
      "An error occured while downloading service data",
      stackTrace: stackTrace,
    );
  }

  await await prefs.setString(
      'version', DateTime.now().millisecondsSinceEpoch.toString());

  return (isStopsSuccess && isServicesSuccess);
}

bool validateStops(stopsRaw) {
  bool valid = true;

  var stops = jsonDecode(stopsRaw);

  for (var stop in stops) {
    if (stop["Name"] == null) {
      valid = false;
    }
    if (stop["Services"] == null) {
      valid = false;
    }
    if (stop["id"] == null) {
      valid = false;
    }
    if (stop["cords"] == null) {
      valid = false;
    }
  }

  return valid;
}

bool validateServices(servicesRaw) {
  bool valid = true;

  var services = jsonDecode(servicesRaw);

  services.forEach((k, v) {
    if (k == null) {
      valid = false;
    }
    if (v["routes"] == null) {
      valid = false;
    }
    if (v["name"] == null) {
      valid = false;
    }
  });

  return valid;
}
