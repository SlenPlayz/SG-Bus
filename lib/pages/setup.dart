import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/pages/download_page.dart';
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
          body: SetupWelcomeScreen()),
    );
  }
}

class SetupWelcomeScreen extends StatelessWidget {
  const SetupWelcomeScreen({Key? key}) : super(key: key);

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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (BuildContext context) => DownloadPage())),
            child: Text(
              "Start Download",
            ),
          )
        ],
      ),
    );
  }
}
