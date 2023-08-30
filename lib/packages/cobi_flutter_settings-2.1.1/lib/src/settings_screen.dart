import 'package:cobi_flutter_settings/src/settings_widget_base.dart';
import 'package:flutter/material.dart';

/// The uppermost container for settings widgets
/// 
/// This can contain multiple SettingsGroups
/// and other Widgets derived from [SettingsWidgetBase].
/// It can also contain any other widgets
class SettingsScreen extends StatelessWidget{
  
  /// All children go here
  final List<Widget> children;

  SettingsScreen({
    Key? key,
    required String title,
    required this.children,
  }) :
  super(key: key);
  
  @override
  Widget build(BuildContext context) {
    List<Widget> content = [];
    
    children.forEach((item) {
      content.add(Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: item,
        )
      );
      if (item != children.last) {
        // content.add(
        //   Divider(
        //     height: 8.0,
        //     thickness: 1.0
        //   )
        // );
      }
    });
    
    return ListView.builder(
      shrinkWrap: true,
      itemCount: content.length,
      itemBuilder: (BuildContext context, int index) => content[index],
    );
  }
}
