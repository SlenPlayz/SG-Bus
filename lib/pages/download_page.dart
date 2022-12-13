import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final BannerAd Ad = BannerAd(
    adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );

  bool error = false;
  String errorMsg = '';
  bool downloaded = false;
  String downloadStatus = 'Starting download...';
  static const String endpoint = serverURL;
  bool isAdLoaded = false;
  late AdWidget adWidget;

  void download() async {
    setState(() {
      error = false;
    });
    var prefs = await SharedPreferences.getInstance();
    setState(() {
      downloadStatus = 'Downloading stops...';
    });

    final stopsEndpoint = Uri.parse('$endpoint/api/data/stops');
    get(stopsEndpoint).then((stopsData) async {
      var stops = stopsData.body;
      await prefs.setString('stops', stops);

      setState(() {
        downloadStatus = 'Downloading services...';
      });

      final svcsEndpoint = Uri.parse('$endpoint/api/data/services');
      get(svcsEndpoint).then((svcsData) async {
        var svcs = svcsData.body;
        await prefs.setString('svcs', svcs);
        // setState(() {
        //   downloadStatus = 'Downloading routes...';
        // });
        await prefs.setString(
            'version', DateTime.now().millisecondsSinceEpoch.toString());
        setState(() {
          if (kReleaseMode) {
            downloadStatus = 'Downloaded!';
          } else {
            downloadStatus = 'Please hot restart the app';
          }
        });

        if (kReleaseMode) {
          Restart.restartApp();
        }
        // final routesEndpoint = Uri.parse('$endpoint/api/data/routes');
        // get(routesEndpoint).then((data) async {
        //   var routes = data.body;
        //   await prefs.setString('routes', routes);

        // }).catchError((err) {
        //   setState(() {
        //     error = true;
        //   });
        // });
      }).catchError((err) {
        setState(() {
          error = true;
        });
      });
    }).catchError((err) {
      setState(() {
        error = true;
      });
    });
  }

  Future<void> loadAd() async {
    try {
      adWidget = AdWidget(ad: Ad);
      await Ad.load();
      isAdLoaded = true;
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    if (adsEnabled) loadAd();
    download();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
            ),
          ),
          body: error
              ? const Text(
                  "Sorry, we couldnt download the data try again later")
              : Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 20.0),
                            child: CircularProgressIndicator(),
                          ),
                          Text(downloadStatus),
                        ],
                      ),
                    ),
                    isAdLoaded
                        ? Container(
                            height: height,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              alignment: Alignment.center,
                              child: adWidget,
                              width: Ad.size.width.toDouble(),
                              height: Ad.size.height.toDouble(),
                            ),
                          )
                        : Container(),
                  ],
                )),
    );
  }
}
