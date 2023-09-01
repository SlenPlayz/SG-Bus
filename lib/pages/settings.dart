import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sgbus/pages/download_page.dart';

import '../packages/cobi_flutter_settings-2.1.1/lib/cobi_flutter_settings.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (kReleaseMode) {
            Restart.restartApp();
          }
        },
        label: Text("Save & Restart"),
        icon: Icon(Icons.restart_alt),
      ),
      body: SettingsScreen(
        title: 'Settings',
        children: [
          SettingsGroup(
            title: 'General',
            children: [
              RadioModalSetting<String>(
                settingsKey: 'startup-screen',
                title: 'Startup Screen',
                defaultValue: "Nearby",
                leading: Icon(Icons.first_page),
                items: [
                  ListItem<String>(value: "Nearby", caption: 'Nearby'),
                  ListItem<String>(value: "Map", caption: 'Map'),
                  ListItem<String>(value: "Search", caption: 'Search'),
                  ListItem<String>(value: "MRT Map", caption: 'MRT Map'),
                  ListItem<String>(value: "Favourites", caption: 'Favourites'),
                ],
              ),
              RadioModalSetting<String>(
                settingsKey: 'theme',
                title: 'Theme',
                defaultValue: "System",
                leading: Icon(Icons.brightness_6),
                items: [
                  ListItem<String>(value: "System", caption: 'System'),
                  ListItem<String>(value: "Light", caption: 'Light'),
                  ListItem<String>(value: "Dark", caption: 'Dark'),
                ],
              ),
              RadioModalSetting<String>(
                settingsKey: 'color-scheme',
                title: 'Colour scheme',
                defaultValue: "System",
                leading: Icon(Icons.color_lens),
                items: [
                  ListItem<String>(value: "System", caption: 'System'),
                  ListItem<String>(value: "Blue", caption: 'Blue'),
                  ListItem<String>(value: "Green", caption: 'Green'),
                  ListItem<String>(value: "Yellow", caption: 'Yellow'),
                  ListItem<String>(value: "Purple", caption: 'Purple'),
                  ListItem<String>(value: "Orange", caption: 'Orange'),
                  ListItem<String>(value: "Cyan", caption: 'Cyan'),
                  ListItem<String>(value: "Teal", caption: 'Teal'),
                  ListItem<String>(value: "Pink", caption: 'Pink'),
                ],
              ),
            ],
          ),
          SettingsGroup(
            title: 'Data',
            children: [
              CustomSetting(
                title: 'Download data',
                subtitle: 'Re-download stop & bus data from the server',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const DownloadPage())),
              )
            ],
          )
        ],
      ),
    );
  }
}
