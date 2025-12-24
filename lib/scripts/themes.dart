import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

var corePalette = DynamicColorPlugin.getCorePalette();

ThemeData getTheme(BuildContext context, String theme, bool isCustomScheme,
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
    return dark(colorScheme, context);
  } else {
    return light(colorScheme, context);
  }
}

ThemeData light(lightColorScheme, context) {
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
    // tabBarTheme: TabBarTheme(
    //   labelColor: lightColorScheme != null
    //       ? lightColorScheme.secondary
    //       : Color.fromARGB(255, 191, 205, 255),
    // ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      foregroundColor: Colors.black,
    ),
    indicatorColor: lightColorScheme != null
        ? lightColorScheme.secondary
        : Color.fromARGB(255, 191, 205, 255),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: lightColorScheme != null
              ? lightColorScheme.onSurface
              : Colors.black),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: lightColorScheme != null
              ? lightColorScheme.onSurfaceVariant.withOpacity(0.7)
              : Colors.grey),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData dark(darkColorScheme, context) {
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
    // tabBarTheme: TabBarTheme(
    //   labelColor: darkColorScheme != null
    //       ? darkColorScheme.secondary
    //       : Color.fromARGB(255, 216, 225, 255),
    // ),
    indicatorColor: darkColorScheme != null
        ? darkColorScheme.secondary
        : Color.fromARGB(255, 216, 225, 255),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: darkColorScheme != null
                ? darkColorScheme.onSurface
                : Colors.white,
            fontWeight: FontWeight.w800,
          ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: darkColorScheme != null
              ? darkColorScheme.onSurfaceVariant.withOpacity(0.7)
              : Colors.grey),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}
