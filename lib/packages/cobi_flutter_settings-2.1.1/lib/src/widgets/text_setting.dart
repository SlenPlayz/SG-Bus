import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings_widget_base.dart';

/// A textfield setting
/// 
/// When tapped, this widget shows a dialog with a textbox.
class TextSetting<T> extends SettingsWidgetBase<T> {
  
  /// The keyboard type to be used in the dialog
  final TextInputType? keyboardType;
  /// Whether or not to obscure the text
  final bool? obscureText;
  /// the character used to obscure the text
  final String? obscuringCharacter;
  /// The text for the 'confirm' action in the dialog
  final String okText;
  /// The text for the 'cancel' action in the dialog
  final String cancelText;
  /// A list of TextInputFormatter that can be used to restrict or allow certain characters
  final List<TextInputFormatter>? inputFormatters;
  /// This callback is triggered for validation.
  /// Useful e.g. to make sure the user only entered numbers in a certain range
  final FormFieldValidator<T>? validator;
  
  /// Inherited from TextFormField
  final bool? autocorrect;
  /// Inherited from TextFormField
  final SmartDashesType? smartDashesType;
  /// Inherited from TextFormField
  final SmartQuotesType? smartQuotesType;
  /// Inherited from TextFormField
  final bool? enableSuggestions;
  /// Inherited from TextFormField
  final int? maxLines;
  /// Inherited from TextFormField
  final int? minLines;
  /// Inherited from TextFormField
  final bool? expands;
  /// Inherited from TextFormField
  final int? maxLength;
  /// Inherited from TextFormField
  final double cursorWidth = 2.0;
  /// Inherited from TextFormField
  final double? cursorHeight;
  /// Inherited from TextFormField
  final Color? cursorColor;
  /// Inherited from TextFormField
  final Brightness? keyboardAppearance;
  /// Inherited from TextFormField
  final EdgeInsets? scrollPadding;
  /// Inherited from TextFormField
  final bool? enableInteractiveSelection;
  /// Inherited from TextFormField
  final TextSelectionControls? selectionControls;
  
  TextSetting({
    Key? key,
    required settingsKey,
    required title,
    defaultValue,
    subtitle,
    Widget? leading,
    this.keyboardType,
    bool enabled = true,
    this.obscureText,
    this.obscuringCharacter,
    this.inputFormatters,
    this.validator,
    this.okText = 'OK',
    this.cancelText = 'Cancel',
    this.autocorrect,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions,
    this.maxLines,
    this.minLines,
    this.expands,
    this.maxLength,
    this.cursorHeight,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding,
    this.enableInteractiveSelection,
    this.selectionControls,
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
  )
  {
    if (T != String && T != int && T != double) {
      throw Exception('TextSetting only supports String, int and double as generic types');
    }
    
    if (subtitle == null) {
      subtitle = defaultValue;
    }
  }

  @override
  State<StatefulWidget> createState() => _TextSettingState<T>();
}

class _TextSettingState<T> extends SettingsWidgetBaseState<T, TextSetting<T>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  doChange(String? newValue) {
    if (newValue == null) {
      onChanged(newValue as T?);
      return;
    }
    
    switch(T) {
      case String:
        onChanged(newValue as T?);
        break;
      case int:
        onChanged(int.tryParse(newValue) as T?);
        break;
      case double:
        onChanged(double.tryParse(newValue) as T?);
        break;
      default:
        break;
    }
  }
  
  String? validate(String? val) {
    if (val == null) {
      return widget.validator != null ? widget.validator!(val as T?) : null;
    }
    
    switch(T) {
      case String:
        return widget.validator != null ? widget.validator!(val as T) : null;
      case int:
        int? v = int.tryParse(val);
        if (v == null)  {
          return 'Integer value required';
        }
        if (widget.validator != null) {
          return widget.validator!(v as T);
        }
        break;
      case double:
        double? v = double.tryParse(val);
        if (v == null)  {
          return 'Floating point value required';
        }
        if (widget.validator != null) {
          return widget.validator!(v as T);
        }
        break;
      default:
        return 'General error in text field validation';
    }
    return null;
  }
  
  List<TextInputFormatter>? _buildInputFormatters() {
    List<TextInputFormatter>? result;
    switch(T) {
      case int:
        result = [FilteringTextInputFormatter.digitsOnly];
        break;
      case double:
        result = [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))];
        break;
    }
    
    if (widget.inputFormatters != null) {
      if (result == null) {
        result = [];
      }
      result.addAll(widget.inputFormatters!);
    }
    
    return result;
  }
  
  _onTap() async {
    await showDialog<String>(
      context: context,
      builder: (_) {
        var controller = TextEditingController(text: value?.toString());
        return AlertDialog(
          title: Text(
            widget.title,
          ),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              inputFormatters: _buildInputFormatters(),
              keyboardType: widget.keyboardType,
              validator: validate,
              onSaved: doChange,
              textInputAction: TextInputAction.done,
              obscureText: widget.obscureText ?? false,
              obscuringCharacter: widget.obscuringCharacter ?? '•',
              autocorrect: widget.autocorrect ?? true,
              smartDashesType: widget.smartDashesType,
              smartQuotesType: widget.smartQuotesType,
              enableSuggestions: widget.enableSuggestions ?? true,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              expands: widget.expands ?? false,
              maxLength: widget.maxLength,
              cursorHeight: widget.cursorHeight,
              cursorColor: widget.cursorColor,
              keyboardAppearance: widget.keyboardAppearance,
              scrollPadding: widget.scrollPadding ?? const EdgeInsets.all(20.0),
              enableInteractiveSelection: widget.enableInteractiveSelection ?? true,
              selectionControls: widget.selectionControls,
            ),
            autovalidateMode: AutovalidateMode.always,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.cancelText),
            ),
            TextButton(
              onPressed: ()  {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Navigator.pop(context);
                }
              },
              child: Text(widget.okText),
            )
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    String usedSubtitle = '';
    if (this.value != null && this.value != '') {
      usedSubtitle = this.value.toString();
    }
    
    if (usedSubtitle == '' && widget.subtitle != null) {
      usedSubtitle = widget.subtitle!;
    }
    
    return ListTile(
      title: Text(widget.title),
      subtitle: Text(usedSubtitle),
      leading: widget.leading,
      onTap: _onTap,
      enabled: widget.enabled,
    );
  }

}
