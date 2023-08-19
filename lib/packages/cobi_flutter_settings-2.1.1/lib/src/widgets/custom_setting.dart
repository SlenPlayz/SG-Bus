import 'package:flutter/material.dart';

import '../settings_widget_base.dart';

/// A Custom Setting for various purposes
/// This widget can be used for various stuff,
/// like calling another navigation route or
/// showing some information
class CustomSetting<T> extends SettingsWidgetBase<T> {
  final void Function()? onPressed;
  final Widget? trailing;
  
  CustomSetting({
      Key? key,
      settingsKey,
      required title,
      T? defaultValue,
      String? subtitle,
      enabled = true,
      this.onPressed,
      Widget? leading,
      this.trailing,
      SettingChangedCallback<T>? onChanged,
    }) : super(
      key: key,
      settingsKey: settingsKey,
      title: title,
      defaultValue: defaultValue,
      subtitle: subtitle,
      enabled: enabled,
      leading: leading,
      onChanged: onChanged
  );

  @override
  State<StatefulWidget> createState() => _CustomSettingState<T>();
  
}


class _CustomSettingState<T> extends SettingsWidgetBaseState<T, CustomSetting<T>> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: widget.leading,
      trailing: widget.trailing,
      title: Text(widget.title),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      onTap: widget.onPressed,
    );
  }
  
}
