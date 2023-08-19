import 'package:dynamic_color/samples.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

var corePalette = DynamicColorPlugin.getCorePalette();

ThemeData getTheme(String theme, bool isCustomScheme,
    [Color? scheme, ColorScheme? deviceColorScheme]) {
  var colorScheme;
  if (!isCustomScheme) {
    if (deviceColorScheme == null) {
      colorScheme = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: (theme == "dark") ? Brightness.dark : Brightness.light);
    } else {
      colorScheme = deviceColorScheme;
    }
  }
  if (scheme != null)
    colorScheme = ColorScheme.fromSeed(
        seedColor: scheme,
        brightness: (theme == "dark") ? Brightness.dark : Brightness.light);
  if (theme == "dark") {
    return dark(colorScheme);
  } else {
    return light(colorScheme);
  }
}

ThemeData light(lightColorScheme) {
  return ThemeData.light().copyWith(
    useMaterial3: true,
    colorScheme: lightColorScheme ??
        const ColorScheme.light(
          primary: Color.fromARGB(255, 191, 205, 255),
          secondary: Color.fromARGB(255, 191, 205, 255),
        ),
    scaffoldBackgroundColor:
        lightColorScheme != null ? lightColorScheme.background : Colors.white,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          lightColorScheme != null ? lightColorScheme.background : Colors.white,
    ),
    dialogBackgroundColor: lightColorScheme?.background,
    tabBarTheme: TabBarTheme(
      labelColor: lightColorScheme != null
          ? lightColorScheme.secondary
          : Color.fromARGB(255, 191, 205, 255),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      foregroundColor: Colors.black,
    ),
    indicatorColor: lightColorScheme != null
        ? lightColorScheme.secondary
        : Color.fromARGB(255, 191, 205, 255),
  );
}

ThemeData dark(darkColorScheme) {
  return ThemeData.dark().copyWith(
    useMaterial3: true,
    colorScheme: darkColorScheme ??
        const ColorScheme.dark(
          primary: Color.fromARGB(255, 216, 225, 255),
          secondary: Color.fromARGB(255, 216, 225, 255),
        ),
    scaffoldBackgroundColor:
        darkColorScheme != null ? darkColorScheme.background : Colors.black,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          darkColorScheme != null ? darkColorScheme.background : Colors.black,
    ),
    dialogBackgroundColor: darkColorScheme?.background,
    tabBarTheme: TabBarTheme(
      labelColor: darkColorScheme != null
          ? darkColorScheme.secondary
          : Color.fromARGB(255, 216, 225, 255),
    ),
    indicatorColor: darkColorScheme != null
        ? darkColorScheme.secondary
        : Color.fromARGB(255, 216, 225, 255),
  );
}
