import 'dart:convert';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/components/searchDelegate.dart';
import 'package:sgbus/env.dart';
import 'package:sgbus/pages/alert_webview_page.dart';
import 'package:sgbus/pages/cepas_reader.dart';
import 'package:sgbus/pages/download_page.dart';
import 'package:sgbus/pages/home.dart';
import 'package:sgbus/pages/mrt_pages/mrt.dart';
import 'package:sgbus/pages/mrt_pages/mrt_map.dart';
import 'package:sgbus/components/nearbyWidget.dart';
import 'package:sgbus/components/favouritesWidget.dart';
import 'package:sgbus/pages/settings.dart';
import 'package:sgbus/pages/setup.dart';
import 'package:sgbus/pages/stops_map.dart';
import 'package:sgbus/pages/search.dart';
import 'package:sgbus/components/weather_pill.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/data_management/downloadData.dart';
import 'package:sgbus/scripts/data_management/weather_service.dart';
import 'package:sgbus/scripts/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MobileAds.instance.initialize();

  // mb.MapboxOptions.setAccessToken(mapboxAccessToken);

  // RequestConfiguration adConfig = RequestConfiguration(
  //     testDeviceIds:
  //         kReleaseMode ? ["BFE1A462271EE8B4883DB5FC72D986A0"] : null);

  // MobileAds.instance.updateRequestConfiguration(adConfig);

  timeDilation = 0.5;

  if (kReleaseMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://7dc195a0ea1742c89c3cf4e9f8f18f83@o4504325797445632.ingest.sentry.io/4504325798559744';
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
  bool isAmoled = false;
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

      if (colorSchemeSettings == "AMOLED") {
        isAmoled = true;
        isCustomScheme = false;
      }
      if (colorSchemeSettings == "Blue") {
        customScheme = Colors.blue;
      }
      if (colorSchemeSettings == "Green") {
        customScheme = Colors.green;
      }
      if (colorSchemeSettings == "Yellow") {
        customScheme = Colors.yellow;
      }
      if (colorSchemeSettings == "Lime") {
        customScheme = Colors.lime;
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
    setTheme(isAmoled
        ? true
        : overrideSystemTheme
            ? theme == "dark"
            : isSysDarkMode);
  }

  void initPlugins() async {
    MobileAds.instance.initialize();

    mb.MapboxOptions.setAccessToken(mapboxAccessToken);

    RequestConfiguration adConfig = RequestConfiguration(
        testDeviceIds:
            kReleaseMode ? ["BFE1A462271EE8B4883DB5FC72D986A0"] : null);

    MobileAds.instance.updateRequestConfiguration(adConfig);
  }

  Future<void> appInitialiser() async {
    initPlugins();
    await loadThemeSettings();
    setState(() {
      isLoaded = true;
    });
  }

  @override
  initState() {
    appInitialiser();
    super.initState();
  }

  Widget build(BuildContext context) {
    if (!isLoaded) {
      return MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExpressiveLoadingIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Initialising App...",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "This should not take too long. Being stuck on this page could signify a Google Play Services error.",
                      style: TextStyle(
                        // fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(
            context,
            (overrideSystemTheme && theme != "") ? theme : "light",
            isCustomScheme,
            customScheme,
            (lightColorScheme?.background != null)
                ? (overrideSystemTheme && theme == "dark")
                    ? darkColorScheme
                    : lightColorScheme
                : null,
            isAmoled),
        darkTheme: getTheme(
            context,
            (overrideSystemTheme && theme != "") ? theme : "dark",
            isCustomScheme,
            customScheme,
            (lightColorScheme?.background != null)
                ? (overrideSystemTheme && theme == "light")
                    ? lightColorScheme
                    : darkColorScheme
                : null,
            isAmoled),
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

class _RootPageState extends State<RootPage> with TickerProviderStateMixin {
  int currPageIndex = 1;

  var alerts = [];

  List<Widget> pages = [
    const StopsMap(),
    const Home(),
    const MRT(),
  ];
  List pageName = const ['Map', 'Home', 'MRT'];
  var searchQuery = TextEditingController();

  bool isLoaded = false;
  bool isDataUpdating = false;
  var prefs;

  void checkData() async {
    NFCAvailability NFCStatus = await FlutterNfcKit.nfcAvailability;

    if (NFCStatus != NFCAvailability.not_supported) {
      isNFCSupported = true;
    }

    prefs = await SharedPreferences.getInstance();
    PackageInfo appInfo = await PackageInfo.fromPlatform();

    var stops = prefs.getString('stops');
    var svcs = prefs.getString('svcs');
    var mrtData = prefs.getString('mrt-data');
    var localVersion = prefs.getString('version');
    var lastOpenedAppVersion = prefs.getString('last-opened-version');

    // var startupScreen = prefs.getString('startup-screen');

    // if (startupScreen != null) {
    //   if (startupScreen != "Map" &&
    //       startupScreen != "Home" &&
    //       startupScreen != "MRT Map") {
    //     startupScreen = "Home";
    //     prefs.setString('startup-screen', startupScreen);
    //   }
    //   currPageIndex = pageName.indexOf(startupScreen); //TODO: Fix this
    // }

    if (lastOpenedAppVersion == null) {
      prefs.setString('last-opened-version', appInfo.version.toString());
    }

    if (stops == null ||
        svcs == null ||
        mrtData == null ||
        localVersion == null ||
        lastOpenedAppVersion == null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (builder) => DownloadPage(
                restartOnComplete: true,
              )));
    } else {
      saveStops(stops);
      saveSvcs(svcs);
      saveMRTData(mrtData);
      setState(() {
        isLoaded = true;
      });

      // try {
      //   AppUpdateInfo updateCheckRes = await InAppUpdate.checkForUpdate();
      //   if (updateCheckRes.flexibleUpdateAllowed &&
      //       updateCheckRes.updateAvailability ==
      //           UpdateAvailability.updateAvailable) {
      //     showDialog(
      //         context: context,
      //         builder: (BuildContext context) {
      //           return AlertDialog(
      //             title: Text('App update avaliable'),
      //             content: Text(
      //                 'A new version of the app has been released and it\'s recomended to update!! You can continue to use the app while the update is downloaded'),
      //             actions: [
      //               TextButton(
      //                 onPressed: () => Navigator.of(context).pop(),
      //                 child: Text('Dismiss'),
      //               ),
      //               TextButton.icon(
      //                 onPressed: () {
      //                   launchUrl(
      //                     Uri.parse(
      //                         "https://play.google.com/store/apps/details?id=com.slen.sgbus"),
      //                     mode: LaunchMode.externalApplication,
      //                   );
      //                 },
      //                 icon: Icon(Icons.download_rounded),
      //                 label: Text('Update'),
      //               )
      //             ],
      //           );
      //         });
      //   }
      // } catch (exception, stackTrace) {
      //   await Sentry.captureException(
      //     exception,
      //     stackTrace: stackTrace,
      //   );
      // }
      // Fetch weather data simultaneously with launch API
      WeatherService().fetchRealtimeWeather();

      fetchLaunchData(appInfo.buildNumber, localVersion);
    }
  }

  Future<void> fetchLaunchData(
      [String? buildNumber, String? localVersion]) async {
    launchApiHasError.value = false;
    try {
      final bNumber =
          buildNumber ?? (await PackageInfo.fromPlatform()).buildNumber;
      final prefs = await SharedPreferences.getInstance();
      final lVersion = localVersion ?? prefs.getString('version') ?? '0';

      const String endpoint = serverURL;
      final versionEndpoint = Uri.parse('$endpoint/api/v2/launch');

      final data = await get(versionEndpoint, headers: {"version": bNumber})
          .timeout(const Duration(seconds: 10));

      if (data.statusCode != 200) {
        throw Exception('Launch API responded with status ${data.statusCode}');
      }

      var response = jsonDecode(data.body);
      hasFetchedLaunchData.value = true;
      launchApiHasError.value = false;

      for (var alert in response["alerts"]) {
        print(alert["startTimestamp"]);
        if (alert["startTimestamp"] != null) {
          if ((DateTime.fromMillisecondsSinceEpoch(
                      int.parse(alert["startTimestamp"])))
                  .difference(DateTime.now())
                  .inSeconds <
              0) {
            if (alert["endTimestamp"] != null) {
              print((DateTime.fromMillisecondsSinceEpoch(
                      int.parse(alert["endTimestamp"])))
                  .difference(DateTime.now())
                  .inSeconds);
              if ((DateTime.fromMillisecondsSinceEpoch(
                          int.parse(alert["endTimestamp"])))
                      .difference(DateTime.now())
                      .inSeconds >
                  0) {
                setState(() {
                  alerts.add(alert);
                });
              }
            } else {
              setState(() {
                alerts.add(alert);
              });
            }
          }
        } else {
          setState(() {
            alerts.add(alert);
          });
        }
      }
      setState(() {
        List newAlerts = [];
        print("Alerts updated");
        for (var alert in alerts) {
          var tmpAlert;
          var nAffectedLine;
          print(alert["affectedLine"]);
          if (alert["affectedLine"] == "SKL") {
            nAffectedLine = "STL";
          } else if (alert["affectedLine"] == "PTL") {
            nAffectedLine = "PTL";
          } else {
            nAffectedLine = alert["affectedLine"];
          }
          alert["affectedLine"] = nAffectedLine;
          newAlerts.add(alert);
        }
        globalAlerts.value = newAlerts;
      });

      if (response["lastUpdatedTransitData"] != null) {
        final lastUpdatedTransit =
            DateTime.parse(response["lastUpdatedTransitData"]);

        int dateDiff = DateTime.fromMillisecondsSinceEpoch(int.parse(lVersion))
            .compareTo(lastUpdatedTransit);

        print(dateDiff);
        if (dateDiff < 0) {
          updateData();
        }
      }
    } catch (err, stackTrace) {
      print('Launch API error: $err');
      launchApiHasError.value = true;
      await Sentry.captureException(
        "An error occured when checking for or starting downloading data",
        stackTrace: stackTrace,
      );
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
    double width = MediaQuery.sizeOf(context).width;

    return isLoaded
        ? Scaffold(
            extendBodyBehindAppBar: (currPageIndex == 0),
            appBar: AppBar(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              ),
              // title: isDataUpdating
              //     ? Text("Updating data..")
              //     : Text(pageName[currPageIndex]),
              title: (currPageIndex == 1)
                  ? ValueListenableBuilder<bool>(
                      valueListenable: hasFetchedLaunchData,
                      builder: (context, hasLaunch, _) {
                        return ValueListenableBuilder<dynamic>(
                          valueListenable: globalWeather,
                          builder: (context, weatherData, _) {
                            final weather = weatherData as WeatherSummary?;

                            if (isDataUpdating) {
                              return const Text("Updating data..");
                            }

                            // Show weather pill only when:
                            // 1. Launch API has finished loading (hasLaunch == true)
                            // 2. Weather service has successfully resolved weather for user's location (weather != null)
                            // 3. User is within range of a weather station in Singapore (!weather.isTooFarFromStation)
                            final bool showWeatherPill = hasLaunch &&
                                (weather != null &&
                                    !weather.isTooFarFromStation);

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: showWeatherPill
                                  ? WeatherPill(
                                      key: const ValueKey('weather_pill'),
                                      weather: weather,
                                    )
                                  : Row(
                                      key: const ValueKey('sgbus_logo'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!hasLaunch)
                                          ValueListenableBuilder<bool>(
                                            valueListenable: launchApiHasError,
                                            builder: (context, hasError, _) {
                                              if (hasError) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      onTap: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return AlertDialog(
                                                              content:
                                                                  const Text(
                                                                "Something went wrong when getting live alert data & checking for new updates. ",
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop(),
                                                                  child: const Text(
                                                                      'Dismiss'),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop();
                                                                    fetchLaunchData();
                                                                  },
                                                                  child: const Text(
                                                                      'Retry'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                      child: Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        color: Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.amber
                                                            : Colors
                                                                .amber.shade800,
                                                        size: 22,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                );
                                              }
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: FittedBox(
                                                      fit: BoxFit.contain,
                                                      child:
                                                          LoadingIndicatorM3E(),
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                ],
                                              );
                                            },
                                          ),
                                        const Text("SG Bus"),
                                      ],
                                    ),
                            );
                          },
                        );
                      },
                    )
                  : Container(
                      decoration: (currPageIndex == 0)
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(50.0),
                              color: Theme.of(context).colorScheme.surface,
                            )
                          : null,
                      padding: (currPageIndex == 0)
                          ? const EdgeInsets.fromLTRB(15, 8, 15, 8)
                          : null,
                      child: Text(
                        isDataUpdating
                            ? "Updating data.."
                            : pageName[currPageIndex],
                      ),
                    ),
              scrolledUnderElevation: 0,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: currPageIndex == 0
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.surface,
              actions: [
                Container(
                  decoration: (currPageIndex == 0)
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(50.0),
                          color: Theme.of(context).colorScheme.surface,
                        )
                      : null,
                  margin:
                      (currPageIndex == 0) ? EdgeInsets.only(right: 10) : null,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const Settings())),
                    icon: Icon(Icons.settings),
                  ),
                ),
              ],
            ),
            extendBody: true,
            body: Stack(
              children: [
                Column(
                  children: [
                    (isDataUpdating && currPageIndex != 0)
                        ? LinearProgressIndicatorM3E()
                        : Container(),
                    Expanded(child: pages[currPageIndex]),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      MediaQuery.of(context).padding.bottom + kNavBarBottomGap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubicEmphasized,
                            padding: const EdgeInsets.all(kNavBarOuterPadding),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.55),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(3, (index) {
                                final isSelected = currPageIndex == index;
                                final icons = [
                                  Icons.map_outlined,
                                  Icons.circle_outlined,
                                  Icons.directions_transit_outlined,
                                ];
                                final selectedIcons = [
                                  Icons.map_rounded,
                                  Icons.circle,
                                  Icons.directions_transit_filled_rounded,
                                ];
                                final labels = ['Map', 'Home', 'MRT'];

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      currPageIndex = index;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOutCubicEmphasized,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSelected ? 20 : 14,
                                      vertical: kNavBarInnerVerticalPadding,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          transitionBuilder:
                                              (child, animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: ScaleTransition(
                                                scale: animation,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            isSelected
                                                ? selectedIcons[index]
                                                : icons[index],
                                            key: ValueKey(isSelected),
                                            size: kNavBarIconSize,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        AnimatedSize(
                                          duration:
                                              const Duration(milliseconds: 400),
                                          curve:
                                              Curves.easeInOutCubicEmphasized,
                                          child: isSelected
                                              ? Row(
                                                  children: [
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      labels[index],
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSecondaryContainer,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : const Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExpressiveLoadingIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Checking Data...",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Fetching Material You theme & verifying transit data",
                      style: TextStyle(
                        // fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            ),
          );
  }
}
