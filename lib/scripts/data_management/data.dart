import 'dart:convert';

import 'package:flutter/foundation.dart';

var stops;
var svcs;
var routes;
var mrtData;

// List alerts = [];
final ValueNotifier<List> globalAlerts = ValueNotifier<List>([]);
final ValueNotifier<bool> hasFetchedLaunchData = ValueNotifier<bool>(false);

bool isNFCSupported = false;

bool isDark = true;

void saveStops(String data) {
  stops = jsonDecode(data);
}

void saveSvcs(String data) {
  svcs = jsonDecode(data);
}

void saveMRTData(String data) {
  mrtData = jsonDecode(data);
}

List getStops() {
  return stops;
}

Map getSvcs() {
  return svcs;
}

Map getMRTData() {
  return mrtData;
}

void setTheme(bool data) {
  isDark = data;
}
