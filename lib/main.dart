import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/searchDelegate.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/download_page.dart';
import 'package:sgbus/pages/mrt_map.dart';
import 'package:sgbus/pages/nearby.dart';
import 'package:sgbus/pages/favourites.dart';
import 'package:sgbus/pages/settings.dart';
import 'package:sgbus/pages/setup.dart';
import 'package:sgbus/pages/stops_map.dart';
import 'package:sgbus/pages/search.dart';
import 'package:sgbus/scripts/data.dart';
import 'package:sgbus/scripts/downloadData.dart';
import 'package:sgbus/scripts/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isCustomScheme = false;
  bool isLoaded = false;
  Color? customScheme = null;
  bool overrideSystemTheme = false;
  String theme = "";

  Future<void> loadThemeSettings() async {
    var brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    bool isSysDarkMode = brightness == Brightness.dark;
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? colorSchemeSettings = prefs.getString('color-scheme');
    final String? themeSettings = prefs.getString('theme');

    if (colorSchemeSettings != null && colorSchemeSettings != "System") {
      isCustomScheme = true;

      if (colorSchemeSettings == "Blue") {
        customScheme = Colors.blue;
      }
      if (colorSchemeSettings == "Green") {
        customScheme = Colors.green;
      }
      if (colorSchemeSettings == "Yellow") {
        customScheme = Colors.yellow;
      }
      if (colorSchemeSettings == "Purple") {
        customScheme = Colors.deepPurple;
      }
      if (colorSchemeSettings == "Orange") {
        customScheme = Colors.deepOrange;
      }
      if (colorSchemeSettings == "Cyan") {
        customScheme = Colors.cyan;
      }
      if (colorSchemeSettings == "Teal") {
        customScheme = Colors.teal;
      }
      if (colorSchemeSettings == "Pink") {
        customScheme = Colors.pink;
      }
    }

    if (themeSettings != null && themeSettings != "System") {
      overrideSystemTheme = true;
      theme = themeSettings.toLowerCase();
    }
    setTheme(overrideSystemTheme
        ? theme == "dark"
            ? true
            : false
        : isSysDarkMode);

    setState(() {
      isLoaded = true;
    });
  }

  @override
  initState() {
    loadThemeSettings();
    super.initState();
  }

  // This widget is the root of your application.
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(
            (overrideSystemTheme && theme != "") ? theme : "light",
            isCustomScheme,
            customScheme,
            (lightColorScheme?.background != null)
                ? (overrideSystemTheme && theme == "dark")
                    ? darkColorScheme
                    : lightColorScheme
                : null),
        darkTheme: getTheme(
            (overrideSystemTheme && theme != "") ? theme : "dark",
            isCustomScheme,
            customScheme,
            (lightColorScheme?.background != null)
                ? (overrideSystemTheme && theme == "light")
                    ? lightColorScheme
                    : darkColorScheme
                : null),
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
  List pageName = const ['Nearby', 'Map', 'Search', 'MRT Map', 'Favourites'];
  var searchQuery = TextEditingController();

  bool isLoaded = false;
  bool isDataUpdating = false;
  var prefs;

  void checkData() async {
    prefs = await SharedPreferences.getInstance();
    PackageInfo appInfo = await PackageInfo.fromPlatform();

    var stops = prefs.getString('stops');
    var svcs = prefs.getString('svcs');
    var localVersion = prefs.getString('version');
    var startupScreen = prefs.getString('startup-screen');

    if (startupScreen != null) {
      currPageIndex = pageName.indexOf(startupScreen);
    }

    if (stops == null || svcs == null || localVersion == null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (builder) => Setup()));
    } else {
      saveStops(stops);
      saveSvcs(svcs);
      setState(() {
        isLoaded = true;
      });

      try {
        AppUpdateInfo updateCheckRes = await InAppUpdate.checkForUpdate();
        if (updateCheckRes.flexibleUpdateAllowed &&
            updateCheckRes.updateAvailability ==
                UpdateAvailability.updateAvailable) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('App update avaliable'),
                  content: Text(
                      'A new version of the app has been released and it\'s recomended to update!! You can continue to use the app while the update is downloaded'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Dismiss'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(
                              "https://play.google.com/store/apps/details?id=com.slen.sgbus"),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: Icon(Icons.download_rounded),
                      label: Text('Update'),
                    )
                  ],
                );
              });
        }
      } catch (exception, stackTrace) {
        await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
        );
      }
      const String endpoint = serverURL;

      final versionEndpoint = Uri.parse('$endpoint/api/launch');

      get(versionEndpoint, headers: {"version": appInfo.buildNumber})
          .then((data) async {
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

        int dateDiff =
            DateTime.fromMillisecondsSinceEpoch(int.parse(localVersion))
                .compareTo(DateTime.parse(response["lastUpdated"]));

        if (dateDiff < 0) {
          updateData();
        }
      }).catchError((err, stackTrace) async {
        await Sentry.captureException(
          "An error occured when checking for or starting downloading data",
          stackTrace: stackTrace,
        );
      });
    }
  }

  Future<void> updateData() async {
    void onError() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("An error occured while trying to update data"),
            content: Text(
                "Check that wifi or mobile data is enabled. If problem persists try again later in settings."),
            actions: [
              TextButton(
                onPressed: (() {
                  Navigator.of(context).pop();
                }),
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: (() {
                  updateData();
                  Navigator.of(context).pop();
                }),
                child: const Text('Retry'),
              ),
            ],
            scrollable: true,
          );
        },
      );
    }

    setState(() {
      isDataUpdating = true;
    });
    try {
      bool success = await downloadData();
      if (!success) {
        onError();
      }
    } catch (e) {
      onError();
    }
    setState(() {
      isDataUpdating = false;
    });
  }

  @override
  initState() {
    checkData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // var brightness =
    //     SchedulerBinding.instance.platformDispatcher.platformBrightness;
    // bool isDarkMode = brightness == Brightness.dark;
    return isLoaded
        ? Scaffold(
            appBar: AppBar(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              ),
              title: isDataUpdating
                  ? Text("Updating data..")
                  : Text(pageName[currPageIndex]),
              scrolledUnderElevation: currPageIndex == 2 ? 0 : null,
              actions: [
                if (currPageIndex != 2)
                  IconButton(
                    onPressed: () => showSearch(
                        context: context, delegate: SBSearchDelegate()),
                    icon: Icon(Icons.search_rounded),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const Settings())),
                  icon: Icon(Icons.settings),
                ),
              ],
            ),
            body: Column(
              children: [
                (isDataUpdating && currPageIndex != 2)
                    ? LinearProgressIndicator()
                    : Container(),
                Expanded(child: pages[currPageIndex]),
              ],
            ),
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
