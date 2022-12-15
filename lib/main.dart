import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/download_page.dart';
import 'package:sgbus/pages/mrt_map.dart';
import 'package:sgbus/pages/nearby.dart';
import 'package:sgbus/pages/favourites.dart';
import 'package:sgbus/pages/stops_map.dart';
import 'package:sgbus/pages/search.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();

  RequestConfiguration adConfig = RequestConfiguration(
      testDeviceIds:
          kReleaseMode ? ["BFE1A462271EE8B4883DB5FC72D986A0"] : null);

  MobileAds.instance.updateRequestConfiguration(adConfig);

  if (kReleaseMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://7dc195a0ea1742c89c3cf4e9f8f18f83@o4504325797445632.ingest.sentry.io/4504325798559744';
        // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
        // We recommend adjusting this value in production.
        options.tracesSampleRate = 0.5;
      },
      appRunner: () => runApp(MyApp()),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light().copyWith(
          useMaterial3: true,
          colorScheme: lightColorScheme ??
              const ColorScheme.light(
                primary: Color.fromARGB(255, 191, 205, 255),
                secondary: Color.fromARGB(255, 191, 205, 255),
              ),
          scaffoldBackgroundColor: lightColorScheme != null
              ? lightColorScheme.background
              : Colors.white,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: lightColorScheme != null
                ? lightColorScheme.background
                : Colors.white,
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
        ),
        darkTheme: ThemeData.dark().copyWith(
          useMaterial3: true,
          colorScheme: darkColorScheme ??
              const ColorScheme.dark(
                primary: Color.fromARGB(255, 216, 225, 255),
                secondary: Color.fromARGB(255, 216, 225, 255),
              ),
          scaffoldBackgroundColor: darkColorScheme != null
              ? darkColorScheme.background
              : Colors.black,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkColorScheme != null
                ? darkColorScheme.background
                : Colors.black,
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
        ),
        title: 'SG Bus',
        home: const RootPage(),
      );
    });
  }
}

class RootPage extends StatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int currPageIndex = 0;

  List<Widget> pages = [
    const Nearby(),
    const StopsMap(),
    const Search(),
    const MRTMap(),
    const Favourites()
  ];
  List pageName = const [
    'Nearby stops',
    'Map',
    'Search',
    'MRT Map',
    'Favourites'
  ];
  var searchQuery = TextEditingController();

  bool isLoaded = false;
  var prefs;

  void checkData() async {
    prefs = await SharedPreferences.getInstance();

    var stops = prefs.getString('stops');
    var svcs = prefs.getString('svcs');
    var localVersion = prefs.getString('version');

    if (stops == null || svcs == null || localVersion == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text('Seems like your first time!'),
                content: const Text(
                    'SGBus needs to download some data from the internet to function. This will take less that a minute.'),
                actions: [
                  TextButton(
                      onPressed: (() {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const DownloadPage()));
                      }),
                      child: const Text('Download now'))
                ],
              ),
            );
          });
    } else {
      saveStops(stops);
      saveSvcs(svcs);
      setState(() {
        isLoaded = true;
      });

      int daysSinceLastUpdate = DateTime.now()
          .difference(
              DateTime.fromMillisecondsSinceEpoch(int.parse(localVersion)))
          .inDays;

      if (daysSinceLastUpdate > 14 || daysSinceLastUpdate < 0) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Update dataset'),
              content: const Text(
                  "It's been a while since the last update. We recomend updating. This should take less than a minute"),
              actions: [
                TextButton(
                  onPressed: (() {
                    Navigator.of(context).pop();
                  }),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: (() {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const DownloadPage()));
                  }),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      }

      const String endpoint = serverURL;

      final versionEndpoint = Uri.parse('$endpoint/api/launch');

      get(versionEndpoint).then((data) {
        var response = jsonDecode(data.body);
        List alerts = response['alerts'];
        alerts.forEach((alert) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(alert['title']),
                content: Text(alert['message']),
                actions: [
                  TextButton(
                    onPressed: (() {
                      Navigator.of(context).pop();
                    }),
                    child: const Text('Dismiss'),
                  ),
                ],
                scrollable: true,
              );
            },
          );
        });
      }).catchError((err) {});
    }
  }

  @override
  initState() {
    checkData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;
    return isLoaded
        ? Scaffold(
            extendBodyBehindAppBar: (currPageIndex == 1),
            appBar: (currPageIndex != 1)
                ? AppBar(
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness:
                          isDarkMode ? Brightness.light : Brightness.dark,
                    ),
                    title: Text(pageName[currPageIndex]))
                : null,
            body: pages[currPageIndex],
            bottomNavigationBar: NavigationBar(
              onDestinationSelected: (int index) {
                setState(() {
                  currPageIndex = index;
                });
              },
              selectedIndex: currPageIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: 'Nearby',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_transit_filled_outlined),
                  selectedIcon: Icon(Icons.directions_transit_filled_rounded),
                  label: 'MRT map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_border_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: 'Favourites',
                ),
              ],
            ),
          )
        : const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
  }
}
