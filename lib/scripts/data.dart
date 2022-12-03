import 'dart:convert';

var stops;
var svcs;
var routes;

void saveStops(String data) {
  stops = jsonDecode(data);
}

void saveSvcs(String data) {
  svcs = jsonDecode(data);
}

void saveRoutes(String data) {
  routes = jsonDecode(data)['features'];
}

List getStops() {
  return stops;
}

Map getSvcs() {
  return svcs;
}

List getRoutes() {
  return routes;
}
