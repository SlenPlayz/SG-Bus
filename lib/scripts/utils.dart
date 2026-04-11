import 'package:sgbus/scripts/data.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart'
    as gpa;

List stops = getStops();

Map getStopByID(id) {
  var stopInfo;
  stops.forEach((stop) {
    if (stop["id"] == id) {
      stopInfo = stop;
    }
  });
  if (stopInfo != null) {
    return stopInfo;
  } else {
    throw "Not found";
  }
}

List<List<num>> decodePolyline(String polyline) {
  return gpa.decodePolyline(polyline);
}

bool isNumeric(String? s) {
  if (s == null) {
    return false;
  }
  return double.tryParse(s) != null;
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return "";
    var arr = this.split(" ");
    for (var i = 0; i < arr.length; i++) {
      var x = arr[i];
      if (x.isNotEmpty) {
        arr[i] = x[0].toUpperCase() + x.substring(1).toLowerCase();
      }
    }
    return arr.join(" ");
  }
}
