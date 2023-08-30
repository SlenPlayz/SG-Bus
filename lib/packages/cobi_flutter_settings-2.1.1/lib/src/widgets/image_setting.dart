import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../settings_widget_base.dart';

/// An image setting
///
/// When tapped, this shows the system's image chooser.
/// The filename is stored as a string.
/// [showPreview] defaults to true and shows a square into which the image is [BoxFit.scaleDown]ed
class ImageSetting extends SettingsWidgetBase<String> {
  final bool? showPreview;
  
  ImageSetting({
    Key? key,
    required settingsKey,
    required title,
    defaultValue,
    subtitle,
    this.showPreview,
    Widget? leading,
    bool enabled = true,
    SettingChangedCallback<String>? onChanged,
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
  State<StatefulWidget> createState() => _ImageSettingState();
}

class _ImageSettingState extends SettingsWidgetBaseState<String, ImageSetting> {
  final ImagePicker _picker = ImagePicker();
  
  void _onTap() async {
    String? file = (await _picker.pickImage(source: ImageSource.gallery))?.path;
    if (file == null) {
      return;
    }
    
    if (file != value) {
      onChanged(file);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    
    return ListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      leading: widget.leading,
      trailing: (widget.showPreview ?? true) && value != null ? LayoutBuilder(builder: (context, constraints) {
        double size = min(constraints.maxHeight, constraints.maxWidth);
        return Image.file(
          File(value!),
          fit: BoxFit.scaleDown,
          height: size,
          width: size
        );
      },) : null,
      onTap: _onTap,
      enabled: widget.enabled,
    );
  }
  
}
