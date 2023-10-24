import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/scripts/downloadData.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key, required this.restartOnComplete})
      : super(key: key);
  final bool restartOnComplete;

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  int currState = 0;

  void goto(int i) {
    setState(() {
      currState = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (currState == 0)
          ? DownloadDataPage(goto: goto)
          : (currState == 1)
              ? DownloadCompletePage(
                  goto: goto,
                  restartOnComplete: widget.restartOnComplete,
                )
              : DownloadFailedPage(goto: goto),
    );
  }
}

class DownloadDataPage extends StatefulWidget {
  const DownloadDataPage({Key? key, required this.goto}) : super(key: key);
  final goto;

  @override
  _DownloadDataPageState createState() => _DownloadDataPageState();
}

class _DownloadDataPageState extends State<DownloadDataPage> {
  Future<void> download() async {
    try {
      bool success = await downloadData();
      if (success) {
        widget.goto(1);
      } else {
        widget.goto(2);
      }
    } catch (e) {
      widget.goto(3);
    }
  }

  void initState() {
    download();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Spacer(),
          Icon(
            Icons.download,
            size: 75,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          Text(
            "Downloading...",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 24,
            ),
          ),
          Spacer(),
          Container(
            width: width,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
              child: Text(
                "Downloading stops and services...",
                textAlign: TextAlign.left,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: LinearProgressIndicator(
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          )
        ],
      ),
    );
  }
}

class DownloadCompletePage extends StatelessWidget {
  const DownloadCompletePage(
      {Key? key, this.goto, required this.restartOnComplete})
      : super(key: key);
  final goto;
  final bool restartOnComplete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.check_rounded,
            size: 75,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          Text(
            "Download completed!",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 24,
            ),
          ),
          TextButton(
            onPressed: () {
              if (restartOnComplete) {
                if (kReleaseMode) {
                  Restart.restartApp();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              "Enter app",
            ),
          )
        ],
      ),
    );
  }
}

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
            Icons.error,
            size: 75,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          Text(
            "Download failed",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 24,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Check that wifi or mobile data is enabled. If problem persists try again later.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              goto(0);
            },
            child: Text(
              "Retry",
            ),
          )
        ],
      ),
    );
  }
}
