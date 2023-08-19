import 'dart:convert';

import 'package:cobi_flutter_settings/cobi_flutter_settings.dart';
import 'package:flutter/material.dart';

/// A Setting for a multi-selection list
///
/// When tapped, this setting opens a list of selectable items.
class MultiSelectSetting<T> extends SettingsWidgetBase<List<T>> {
  final Widget? trailing;
  
  final List<ListItem<T>> items;
  
  MultiSelectSetting({
    Key? key,
    required settingsKey,
    required title,
    required this.items,
    List<T>? defaultValue,
    String? subtitle,
    Widget? leading,
    this.trailing,
    bool enabled = true,
    SettingChangedCallback<List<T>>? onChanged,
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
  State<StatefulWidget> createState() => _MultiSelectSettingState<T>();
}

class _MultiSelectSettingState<T> extends SettingsWidgetBaseState<List<T>, MultiSelectSetting<T>> {
  
  void _onTap() async {
    List<T> tmpValue = value ?? widget.defaultValue ?? [];
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
                  return CheckboxListTile(
                    dense: true,
                    value: tmpValue.contains(widget.items[index].value),
                    title: Text(widget.items[index].caption),
                    onChanged: (val) => setNewState(() {
                      if ((val != null || val!) && !tmpValue.contains(widget.items[index].value)) {
                        tmpValue.add(widget.items[index].value);
                      }
                      else {
                        tmpValue.remove(widget.items[index].value);
                      }
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
    if (ok != null && ok) {
      onChanged(tmpValue);
    }
  }
  
  @override
  String? serialize() {
    return json.encode(value);
  }
  
  @override
  List<T>? deserialize(String? data) {
    if (data == null) {
      return null;
    }
    return List<T>.from(json.decode(data));
  }
  
  @override
  void onChanged(List<T>? newValue) {
    setState(() {
      value = newValue;
      persist();
    });
    return;
  }
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : Text(''),
      leading: widget.leading,
      onTap: _onTap,
      enabled: widget.enabled,
    );
  }
}
