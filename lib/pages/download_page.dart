import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool error = false;
  String errorMsg = '';
  bool downloaded = false;
  String downloadStatus = 'Starting download...';
  static const String endpoint = serverURL;

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
        setState(() {
          downloadStatus = 'Downloading routes...';
        });
        final routesEndpoint = Uri.parse('$endpoint/api/data/routes');
        get(routesEndpoint).then((data) async {
          var routes = data.body;
          await prefs.setString('routes', routes);
          setState(() {
            downloadStatus = 'Getting version info...';
          });
          final versionEndpoint = Uri.parse('$endpoint/api/data/version');
          get(versionEndpoint).then((versionData) async {
            var response = jsonDecode(versionData.body);
            var version = response['version'];
            await prefs.setString('version', version.toString());

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
          }).catchError(() {
            setState(() {
              error = true;
            });
          });
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
    }).catchError((err) {
      setState(() {
        error = true;
      });
    });
  }

  @override
  void initState() {
    download();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
              : Center(
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
                )),
    );
  }
}
