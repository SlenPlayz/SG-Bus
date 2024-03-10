import 'package:sgbus/scripts/data.dart';

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

extension StringExtension on String {
  String capitalize() {
    var arr = this.split(" ");
    for (var i = 0; i < arr.length; i++) {
      var x = arr[i];
      arr[i] = x[0].toUpperCase() + x.substring(1).toLowerCase();
    }
    return arr.join(" ");
    // return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
