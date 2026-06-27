import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

var stops;
var svcs;
var routes;
var mrtData;

// List alerts = [];
final ValueNotifier<List> globalAlerts = ValueNotifier<List>([]);
final ValueNotifier<bool> hasFetchedLaunchData = ValueNotifier<bool>(false);

bool isNFCSupported = false;

bool isDark = true;

// Floating nav bar dimensions (must match main.dart nav bar layout)
const double kNavBarOuterPadding = 6.0;
const double kNavBarInnerVerticalPadding = 12.0;
const double kNavBarIconSize = 22.0;
const double kNavBarBottomGap = 12.0;
const double kNavBarPillHeight =
    (kNavBarOuterPadding * 2) + (kNavBarInnerVerticalPadding * 2) + kNavBarIconSize;

/// Returns the total bottom clearance needed to keep content above the floating nav bar.
/// Accounts for device safe area insets dynamically.
double getNavBarClearance(BuildContext context, {double extraSpacing = 8.0}) {
  return MediaQuery.of(context).padding.bottom +
      kNavBarBottomGap +
      kNavBarPillHeight +
      extraSpacing;
}

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
