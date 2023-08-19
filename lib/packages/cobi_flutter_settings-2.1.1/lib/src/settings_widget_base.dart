import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SettingChangedCallback<T> = void Function(T? from, T? to);

/// The base class for all settings widgets
/// [T] is the type of value stored via shared_preferences
abstract class SettingsWidgetBase<T> extends StatefulWidget {
  
  /// The default value that is used if no value is stored
  final T? defaultValue;
  
  /// The key used to store via shared_preferences
  final String? settingsKey;
  
  /// The settings tile's title
  final String title;
  /// The settings tile's subtitle
  final String? subtitle;
  
  /// Whether this setting is enabled or not
  final bool enabled;
  
  /// The leading widget for the settings tile
  final Widget? leading;
  
  /// A callback that is triggered when the value changes
  final SettingChangedCallback<T>? onChanged;
  
  SettingsWidgetBase({
    Key? key,
    this.settingsKey,
    required this.title,
    this.defaultValue,
    this.subtitle,
    this.enabled = true,
    this.onChanged,
    this.leading
  }) : super(key: key);
}

/// The base state class for [SettingsWidgetBase]
/// 
/// This takes care of persisting the value via shared_preferences
/// You can subclass this to support more complex data types than supported by shared_preferences.
/// When subclassing for complex types, implement [serialize] and [deserialize]. Please see the included example.
abstract class SettingsWidgetBaseState<T, W extends SettingsWidgetBase<T>> extends State<W> {
  
  @protected
  T? value;
  
  @protected
  late SharedPreferences prefs;
  
  SettingsWidgetBaseState() {
    
    SharedPreferences.getInstance()
    .then((value) {
      this.prefs = value;
      init();
    });
  }
  
  @protected
  void init() {
    if (widget.settingsKey == null) {
      return;
    }
    
    this.prefs = prefs;
    Object? currentValue = prefs.get(widget.settingsKey!);
    
    if (!(T == String) && (currentValue is String)) {
      currentValue = deserialize(currentValue);
    }
    
    setState(() {
      if (currentValue != null && !(currentValue is T?)) {
        value = widget.defaultValue;
      }
      if (currentValue == null) {
        currentValue = widget.defaultValue;
      }
      value = currentValue as T?;
    });
  }
  
  /// override this for more complex data types
  /// than the ones supported by shared_preferences.
  @protected
  T? deserialize(String? data) {
    return null;
  }
  
  /// override this for more complex data types
  /// than the ones supported by shared_preferences.
  @protected
  String? serialize() {
    return null;
  }
  
  /// Here the actual storing takes place
  void persist() {
    if (widget.settingsKey == null) {
      return;
    }
    
    String settingsKey = widget.settingsKey!;
    
    if (value == null) {
      prefs.remove(widget.settingsKey!);
      return;
    }
    
    switch (T) {
      case String:
        prefs.setString(settingsKey, value as String);
        break;
      case bool:
        prefs.setBool(settingsKey, value as bool);
        break;
      case int:
        prefs.setInt(settingsKey, value as int);
        break;
      case double:
        prefs.setDouble(settingsKey, value as double);
        break;
      case List:
        if (T is List<String>) {
          List<String> val = value as List<String>;
          prefs.setStringList(settingsKey, val);
        }
        break;
      default:
        String? data = serialize();
        if (data != null) {
          prefs.setString(settingsKey, data);
        }
        break;
    }
  }
  
  /// This method is called by subclasses when the value changes.
  /// Here, the new value is only set and [SettingsWidgetBase.onChanged] is only called
  /// when the value actually changes
  @protected
  void onChanged(T? newValue) {
    setState(() {
      T? oldValue = value;
      this.value = newValue;
      if (widget.onChanged != null) {
        widget.onChanged!(oldValue, newValue);
      }
      persist();
    });
  }
  
}
