import 'dart:mirrors';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  var methods = reflectClass(MapboxMap).declarations.values.where((d) => d is MethodMirror).map((d) => (d as MethodMirror).simpleName).toList();
  print(methods);
}
