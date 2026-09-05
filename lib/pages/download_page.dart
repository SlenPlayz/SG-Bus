import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:sgbus/scripts/data_management/downloadData.dart';
import 'package:sgbus/scripts/data_management/startup_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key, required this.restartOnComplete})
      : super(key: key);
  final bool restartOnComplete;

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  int currState = 0;

  @override
  void initState() {
    super.initState();
    logStartup('DownloadPage constructed');
  }

  void goto(int i) {
    setState(() {
      currState = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (currState == 0)
          ? DownloadDataPage(
              goto: goto, restartOnComplete: widget.restartOnComplete)
          : (currState == 2)
              ? DownloadFailedPage(goto: goto)
              : Center(
                  child: Text("An unknown error occurred"),
                ),
    );
  }
}

class DownloadDataPage extends StatefulWidget {
  const DownloadDataPage({Key? key, this.goto, required this.restartOnComplete})
      : super(key: key);
  final goto;
  final bool restartOnComplete;

  @override
  _DownloadDataPageState createState() => _DownloadDataPageState();
}

class _DownloadDataPageState extends State<DownloadDataPage> {
  Future<void> download() async {
    try {
      logStartup('transit download started');
      bool success = await downloadData();
      logStartup('transit download completed: success=$success');
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final stopsData = prefs.getString('stops');
        final svcsData = prefs.getString('svcs');
        final mrt = prefs.getString('mrt-data');
        if (stopsData != null) saveStops(stopsData);
        if (svcsData != null) saveSvcs(svcsData);
        if (mrt != null) saveMRTData(mrt);

        if (!mounted) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else if (widget.restartOnComplete && kReleaseMode) {
          Restart.restartApp();
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        widget.goto(2);
      }
    } catch (e) {
      logStartup('transit download error: $e');
      widget.goto(3);
    }
  }

  @override
  void initState() {
    super.initState();
    logStartup('DownloadPage init completed');
    download();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExpressiveLoadingIndicator(),
          SizedBox(
            height: 15,
          ),
          Text(
            "Updating data...",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 26,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.width(110),
                FontVariation.weight(1000)
              ],
            ),
          ),
          SizedBox(height: height * 0.1),
        ],
      ),
    );
  }
}

// class DownloadCompletePage extends StatelessWidget {
//   const DownloadCompletePage(
//       {Key? key, this.goto, required this.restartOnComplete})
//       : super(key: key);
//   final goto;
//   final bool restartOnComplete;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.check_rounded,
//             size: 75,
//             color: Theme.of(context).colorScheme.onPrimaryContainer,
//           ),
//           Text(
//             "Download completed!",
//             style: TextStyle(
//               color: Theme.of(context).colorScheme.onPrimaryContainer,
//               fontSize: 24,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           SizedBox(
//             height: 6,
//           ),
//           FilledButton.icon(
//             onPressed: () {
//               if (restartOnComplete) {
//                 if (kReleaseMode) {
//                   Restart.restartApp();
//                 }
//               } else {
//                 Navigator.of(context).pop();
//               }
//             },
//             label: Text(
//               "Enter app",
//               style: TextStyle(
//                 fontWeight: FontWeight.w900,
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

class DownloadFailedPage extends StatelessWidget {
  const DownloadFailedPage({Key? key, this.goto}) : super(key: key);
  final goto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_rounded,
            size: 75,
            color: Theme.of(context).colorScheme.error,
          ),
          Text(
            "Download failed",
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 26,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.width(100),
                FontVariation.weight(800)
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Check that wifi or mobile data is enabled. If problem persists try again later.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontVariations: [
                  FontVariation('ROND', 100),
                  FontVariation.width(100),
                  FontVariation.weight(600)
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              goto(0);
            },
            icon: Icon(Icons.refresh_rounded),
            label: Text(
              "Retry",
            ),
          )
        ],
      ),
    );
  }
}
