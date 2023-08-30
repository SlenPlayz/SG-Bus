import 'package:flutter/material.dart';

import '../settings_widget_base.dart';

/// A switch setting
/// 
/// This widget shows a switch that the user can toggle on and off
class SwitchSetting extends SettingsWidgetBase<bool> {
  SwitchSetting({
    Key? key,
    required settingsKey,
    required title,
    bool? defaultValue,
    String? subtitle,
    SettingChangedCallback<bool>? onChanged,
  }) : super(
    key: key,
    settingsKey: settingsKey,
    title: title,
    defaultValue: defaultValue,
    subtitle: subtitle,
    onChanged: onChanged,
  );

  @override
  State<StatefulWidget> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends SettingsWidgetBaseState<bool, SwitchSetting> {
  
  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value != null ? value! : false,
      title: Text(widget.title),
      // prevent an empty subtitle causing a slight vertical offset
      subtitle: widget.subtitle != null && widget.subtitle!.trim() != '' ? Text(widget.subtitle!) : null,
      onChanged: onChanged,
    );
  }
  
}
