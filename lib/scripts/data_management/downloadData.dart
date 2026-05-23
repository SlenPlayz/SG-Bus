import 'dart:convert';

import 'package:http/http.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> downloadData([List<Map<String, dynamic>>? tasks]) async {
  const String endpoint = serverURL;
  var prefs = await SharedPreferences.getInstance();

  final List<Map<String, dynamic>> defaultTasks = [
    {
      'url': '$endpoint/api/data/stops',
      'key': 'stops',
      'validate': validateStops,
      'save': saveStops,
    },
    {
      'url': '$endpoint/api/data/services',
      'key': 'svcs',
      'validate': validateServices,
      'save': saveSvcs,
    },
  ];

  final tasksToRun = tasks ?? defaultTasks;
  final List<Future<bool>> futures = [];

  for (var task in tasksToRun) {
    futures.add(() async {
      final String urlStr = task['url'] as String;
      final String key = task['key'] as String;
      final dynamic validate = task['validate'];
      final dynamic save = task['save'];

      try {
        final uri = Uri.parse(urlStr);
        final response = await get(uri);
        final data = response.body;

        if (validate != null) {
          bool isValid = validate(data);
          if (!isValid) {
            throw "Invalid data for key: $key";
          }
        }

        await prefs.setString(key, data);

        if (save != null) {
          save(data);
        }

        return true;
      } catch (err, stackTrace) {
        await Sentry.captureException(
          "An error occurred while downloading data for key: $key",
          stackTrace: stackTrace,
        );
        return false;
      }
    }());
  }

  final results = await Future.wait(futures);

  await prefs.setString(
      'version', DateTime.now().millisecondsSinceEpoch.toString());

  return results.every((element) => element == true);
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
