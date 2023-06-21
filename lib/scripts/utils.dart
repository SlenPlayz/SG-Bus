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
