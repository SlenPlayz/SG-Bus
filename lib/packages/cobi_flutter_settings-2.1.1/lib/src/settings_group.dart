import 'package:cobi_flutter_settings/src/settings_widget_base.dart';
import 'package:flutter/material.dart';

import 'settings_screen.dart';

/// A group of settings
/// 
/// This widget groups various [SettingsWidgetBase]s together
/// 
/// It can also contain any other widgets
class SettingsGroup extends StatelessWidget {
  
  /// All children go here
  final List<Widget> children;
  final String title;
  final TextStyle? style;
  
  SettingsGroup({
    Key? key,
    required this.title,
    required this.children,
    this.style
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    
    SettingsScreen? screen = context.findAncestorWidgetOfExactType<SettingsScreen>();
    
    if (screen == null) {
      throw('SettingsGroup must be a child of SettingsScreen');
    }
    
    List<Widget> content = [];
    
    children.forEach((item) {
      content.add(Container(
        // padding: EdgeInsets.only(top: 8.0, bottom: 0.0),
        child: item,
      ) );
      if (item != children.last) {
        // content.add(Divider(
        //   height: 8.0,
        //   thickness: 1.0
        // ));
      }
    });
    
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.left,
            overflow: TextOverflow.fade,
            style: style ?? TextStyle(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          ...content,
        ],
      )
    );
  }
}
