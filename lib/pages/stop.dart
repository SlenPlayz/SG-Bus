import 'dart:async';
import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/components/bus_timing_row.dart';
import 'package:http/http.dart';
import 'package:sgbus/pages/bus_stop_pages/standard_stop.dart';
import 'package:sgbus/pages/stop_spec_map.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Stop extends StatefulWidget {
  final String stopid;
  const Stop(this.stopid);

  @override
  _StopState createState() => _StopState();
}

class _StopState extends State<Stop> {
  @override
  Widget build(BuildContext context) {
    return StandardStop(widget.stopid);
  }
}
