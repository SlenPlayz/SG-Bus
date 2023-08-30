import 'dart:convert';

var stops;
var svcs;
var routes;
bool isDark = true;

void saveStops(String data) {
  stops = jsonDecode(data);
}

void saveSvcs(String data) {
  svcs = jsonDecode(data);
}

List getStops() {
  return stops;
}

Map getSvcs() {
  return svcs;
}

void setTheme(bool data) {
  isDark = data;
}
