import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/scripts/downloadData.dart';

class Setup extends StatefulWidget {
  const Setup({Key? key}) : super(key: key);

  @override
  _SetupState createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  int currState = 0;
  void goto(state) {
    setState(() {
      currState = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Setup"),
          automaticallyImplyLeading: false,
        ),
        body: (currState == 0)
            ? SetupWelcomeScreen(goto: goto)
            : (currState == 1)
                ? SetupDownloadPage(goto: goto)
                : (currState == 2)
                    ? SetupCompletedPage(
                        goto: goto,
                      )
                    : (currState == 3)
                        ? SetupFailedPage(
                            goto: goto,
                          )
                        : Text("An unknown error occured"),
      ),
    );
  }
}

class SetupWelcomeScreen extends StatelessWidget {
  const SetupWelcomeScreen({Key? key, required this.goto}) : super(key: key);
  final goto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromRGBO(225, 225, 225, 1.0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image(
                  image: AssetImage("assets/icon.png"),
                  height: 85,
                ),
              ),
            ),
          ),
          Text(
            "SG Bus",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 26,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Welcome to SG Bus! The app needs to download some data to function. Click on \"Start Download\" to continue",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          TextButton(
            onPressed: () => goto(1),
            child: Text(
              "Start Download",
            ),
          )
        ],
      ),
    );
  }
}

class SetupDownloadPage extends StatefulWidget {
  const SetupDownloadPage({Key? key, required this.goto}) : super(key: key);
  final goto;

  @override
  _SetupDownloadPageState createState() => _SetupDownloadPageState();
}

class _SetupDownloadPageState extends State<SetupDownloadPage> {
  Future<void> download() async {
    try {
      bool success = await downloadData();
      if (success) {
        widget.goto(2);
      } else {
        widget.goto(3);
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

class SetupCompletedPage extends StatelessWidget {
  const SetupCompletedPage({Key? key, this.goto}) : super(key: key);
  final goto;

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
            "Setup completed!",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 24,
            ),
          ),
          TextButton(
            onPressed: () {
              if (kReleaseMode) {
                Restart.restartApp();
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

class SetupFailedPage extends StatelessWidget {
  const SetupFailedPage({Key? key, this.goto}) : super(key: key);
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
              goto(1);
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
