import 'package:flutter/material.dart';

import '../settings_widget_base.dart';

/// A slider setting
/// 
/// This widget only uses the data type double, not int
class SliderSetting extends SettingsWidgetBase<double> {
  final Widget? trailing;
  final double minValue;
  final double maxValue;
  final int? divisions;
  
  SliderSetting({
    Key? key,
    required settingsKey,
    required title,
    this.minValue = 0,
    this.maxValue = 1,
    this.divisions,
    double? defaultValue,
    this.trailing,
    SettingChangedCallback<double>? onChanged,
  }
  ) : super(
    key: key,
    settingsKey: settingsKey,
    title: title,
    defaultValue: defaultValue,
    onChanged: onChanged,
  );

  @override
  State<StatefulWidget> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends SettingsWidgetBaseState<double, SliderSetting> {
  
  double? sliderValue;
  
  @override
  init() {
    super.init();
    if (value != null) {
      sliderValue = value!;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    
    if (sliderValue == null) {
      sliderValue = value ?? widget.defaultValue ?? 0.0;
    }
    
    return ListTile(
      leading: widget.leading,
      trailing: widget.trailing,
      title: Text(widget.title),
      subtitle: Slider(
        value: sliderValue!,
        min: widget.minValue,
        max: widget.maxValue,
        divisions: widget.divisions,
        onChangeEnd: (v) {
          onChanged(sliderValue);
        },
        onChanged: (val) => setState(() => (sliderValue = val)),
        activeColor: Theme.of(context).colorScheme.secondary,
        inactiveColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
      )
    );
  }
  
}
