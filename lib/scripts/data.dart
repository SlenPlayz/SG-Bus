import 'dart:convert';

import 'package:flutter/foundation.dart';

var stops;
var svcs;
var routes;

// List alerts = [];
final ValueNotifier<List> globalAlerts = ValueNotifier<List>([]);

bool isNFCSupported = false;

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
