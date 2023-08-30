import 'package:flutter/material.dart';

import '../common.dart';
import '../settings_widget_base.dart';

/// A radiobutton setting
/// 
/// This shows mutiple radio buttons of which one can be selected
class RadioSetting<T> extends SettingsWidgetBase<T> {
  final Widget? trailing;
  
  final List<ListItem<T>> items;
  
  RadioSetting({
    Key? key,
    required settingsKey,
    required title,
    required this.items,
    T? defaultValue,
    String? subtitle,
    Widget? leading,
    this.trailing,
    bool enabled = true,
    SettingChangedCallback<T>? onChanged,
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
  State<StatefulWidget> createState() => _RadioSettingState<T>();
}

class _RadioSettingState<T> extends SettingsWidgetBaseState<T, RadioSetting<T>> {
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      leading: widget.leading,
      trailing: widget.trailing,
      subtitle: Column(
        children: List.generate(widget.items.length, (index) =>
          RadioListTile<T>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: widget.items[index].value,
            groupValue: value,
            title: Text(widget.items[index].caption),
            onChanged: (val) => onChanged(val)
          )
        ),
      ),
    );
  }
}

/// Similar to [RadioSetting] but instead of showing the radio buttons directly,
/// this opens a dialog and stores the selected value only when the dialog is confirmed
class RadioModalSetting<T> extends SettingsWidgetBase<T> {
  final Widget? trailing;
  
  final List<ListItem<T>> items;
  
  RadioModalSetting({Key? key,
    required settingsKey,
    required title,
    required this.items,
    T? defaultValue,
    String? subtitle,
    Widget? leading,
    this.trailing,
    bool enabled = true,
    SettingChangedCallback<T>? onChanged,
  }) : super(
    key: key,
    settingsKey: settingsKey,
    title: title,
    defaultValue: defaultValue,
    subtitle: subtitle,
    leading: leading,
    enabled: enabled,
    onChanged: onChanged,
  );

  @override
  State<StatefulWidget> createState() => _RadioModalSettingState<T>();
}

class _RadioModalSettingState<T> extends SettingsWidgetBaseState<T, RadioModalSetting<T>> {
  
  String? usedSubtitle;
  
  void _onTap() async {
    T? tmpValue = value;
    bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setNewState) => AlertDialog(
          title: Text(widget.title),
          content: Container(
            width: double.maxFinite,
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (BuildContext context, int index) {
                  return RadioListTile<T>(
                    dense: true,
                    value: widget.items[index].value,
                    groupValue: tmpValue,
                    title: Text(widget.items[index].caption),
                    onChanged: (val) => setNewState(() {
                      tmpValue = val;
                    }),
                  );
                },
              ),
            ) 
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ]
        ),
      ),
    );
    if (ok != null && ok && tmpValue != value) {
      onChanged(tmpValue);
    }
  }
  
  void setSubtitle() {
    if (value != null && value != '') {
      usedSubtitle = value.toString();
    }
    else if (widget.subtitle != null) {
      usedSubtitle = widget.subtitle;
    }
    else {
      usedSubtitle = '';
    }
  }
  
  @override
  void onChanged(T? newValue) {
    if (newValue == value) {
      return;
    }
    setState(() {
      value = newValue;
      setSubtitle();
      persist();
    });
    return;
  }
  
  @override
  Widget build(BuildContext context) {
    setSubtitle();
    return ListTile(
      title: Text(widget.title),
      subtitle: usedSubtitle != null ? Text(usedSubtitle!) : Text(''),
      leading: widget.leading,
      onTap: _onTap,
      enabled: widget.enabled,
    );
  }
  
}
