import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

var corePalette = DynamicColorPlugin.getCorePalette();

const String _fontFamily = 'GoogleSansFlex';

const _labelVariations = [
  FontVariation('ROND', 100),
  FontVariation.width(90),
  FontVariation.weight(800),
];

TextStyle _labelStyle(TextStyle? base) {
  return (base ?? const TextStyle()).copyWith(
    fontFamily: _fontFamily,
    fontVariations: _labelVariations,
  );
}

ThemeData getTheme(BuildContext context, String theme, bool isCustomScheme,
    [Color? scheme, ColorScheme? deviceColorScheme, bool isAmoled = false]) {
  var colorScheme;
  final brightness =
      (theme == "dark" || isAmoled) ? Brightness.dark : Brightness.light;
  if (!isCustomScheme) {
    if (deviceColorScheme == null) {
      colorScheme =
          ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness);
    } else {
      colorScheme = deviceColorScheme;
    }
  }
  if (scheme != null)
    colorScheme =
        ColorScheme.fromSeed(seedColor: scheme, brightness: brightness);
  if (isAmoled) {
    return black(colorScheme, context);
  } else if (theme == "dark") {
    return dark(colorScheme, context);
  } else {
    return light(colorScheme, context);
  }
}

ThemeData light(lightColorScheme, context) {
  return ThemeData.light().copyWith(
    useMaterial3: true,
    textTheme:
        ThemeData.light().textTheme.apply(fontFamily: _fontFamily).copyWith(
              labelSmall: _labelStyle(ThemeData.light().textTheme.labelSmall),
              labelMedium: _labelStyle(ThemeData.light().textTheme.labelMedium),
              labelLarge: _labelStyle(ThemeData.light().textTheme.labelLarge),
            ),
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

    tabBarTheme: TabBarThemeData(
      labelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
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
        fontFamily: _fontFamily,
        fontSize: 26,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(1000)
        ],
        color: lightColorScheme != null
            ? lightColorScheme.onSurface
            : Colors.black,
      ),
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(600)
        ],
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(100),
            FontVariation.weight(600)
          ],
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
    textTheme:
        ThemeData.dark().textTheme.apply(fontFamily: _fontFamily).copyWith(
              labelSmall: _labelStyle(ThemeData.dark().textTheme.labelSmall),
              labelMedium: _labelStyle(ThemeData.dark().textTheme.labelMedium),
              labelLarge: _labelStyle(ThemeData.dark().textTheme.labelLarge),
            ),
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
    tabBarTheme: TabBarThemeData(
      labelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(1000)
        ],
      ),
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color:
            darkColorScheme != null ? darkColorScheme.onSurface : Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color:
            darkColorScheme != null ? darkColorScheme.onSurface : Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(600)
        ],
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color:
            darkColorScheme != null ? darkColorScheme.onSurface : Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(100),
            FontVariation.weight(600)
          ],
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

ThemeData black(darkColorScheme, context) {
  const amoledBlack = Color(0xFF000000);
  const amoledSurface = Color(0xFF0A0A0A);
  const amoledSurfaceContainer = Color(0xFF121212);

  return ThemeData.dark().copyWith(
    useMaterial3: true,
    textTheme:
        ThemeData.dark().textTheme.apply(fontFamily: _fontFamily).copyWith(
              labelSmall: _labelStyle(ThemeData.dark().textTheme.labelSmall),
              labelMedium: _labelStyle(ThemeData.dark().textTheme.labelMedium),
              labelLarge: _labelStyle(ThemeData.dark().textTheme.labelLarge),
            ),
    colorScheme: (darkColorScheme as ColorScheme?)?.copyWith(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Color(0xFFCACACA),
          onSecondary: Colors.black,
          tertiary: Color(0xFFCACACA),
          onTertiary: Colors.black,
          surface: amoledBlack,
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFFCAC4D0),
          surfaceContainerHighest: amoledSurfaceContainer,
          surfaceContainerHigh: amoledSurfaceContainer,
          surfaceContainer: amoledSurface,
          surfaceContainerLow: amoledBlack,
          surfaceContainerLowest: amoledBlack,
          primaryContainer: amoledSurfaceContainer,
          onPrimaryContainer: Colors.white,
          secondaryContainer: amoledSurfaceContainer,
          onSecondaryContainer: Colors.white,
          tertiaryContainer: amoledSurfaceContainer,
          onTertiaryContainer: Colors.white,
          inversePrimary: Colors.black,
          inverseSurface: Colors.white,
          onInverseSurface: Colors.black,
        ) ??
        const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFFCACACA),
        ),
    scaffoldBackgroundColor: amoledBlack,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: amoledSurface,
    ),
    dialogBackgroundColor: amoledSurface,
    cardColor: amoledSurface,
    canvasColor: amoledBlack,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    indicatorColor: Colors.white,
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.white,
      linearTrackColor: Colors.white24,
      circularTrackColor: Colors.white24,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.white,
      labelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(800)
        ],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: amoledBlack,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(110),
          FontVariation.weight(1000)
        ],
        color: Colors.white,
      ),
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color:
            darkColorScheme != null ? darkColorScheme.onSurface : Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color:
            darkColorScheme != null ? darkColorScheme.onSurface : Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(600)
        ],
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: amoledBlack,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.white.withOpacity(0.15),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontFamily: _fontFamily,
        fontVariations: [
          FontVariation('ROND', 100),
          FontVariation.width(100),
          FontVariation.weight(800)
        ],
      ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(100),
            FontVariation.weight(600)
          ],
          color: Colors.white70),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}
