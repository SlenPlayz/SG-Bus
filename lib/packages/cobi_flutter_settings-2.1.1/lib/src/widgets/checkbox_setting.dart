import 'package:flutter/material.dart';

import '../settings_widget_base.dart';

/// A checkbox setting
class CheckboxSetting extends SettingsWidgetBase<bool> {
  CheckboxSetting({
    Key? key,
    required settingsKey,
    required title,
    bool? defaultValue,
    subtitle,
    bool enabled = true,
    Widget? leading,
    SettingChangedCallback<bool>? onChanged,
  }) : super(
    key: key,
    settingsKey: settingsKey,
    title: title,
    defaultValue: defaultValue,
    subtitle: subtitle,
    enabled: enabled,
    leading: leading,
    onChanged: onChanged,
  );

  @override
  State<StatefulWidget> createState() => _CheckboxSettingState();
}

class _CheckboxSettingState extends SettingsWidgetBaseState<bool, CheckboxSetting> {
  
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value != null ? value! : false,
      title: Text(widget.title),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      onChanged: onChanged,
    );
  }
  
}
