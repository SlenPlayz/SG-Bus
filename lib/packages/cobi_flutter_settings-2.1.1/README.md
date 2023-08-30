# cobi_flutter_settings
An application settings screen that persists values via the [shared_preferences](https://pub.dev/packages/shared_preferences) package.
This is a material-only version of [cobi_flutter_platform_settings](https://pub.dev/packages/cobi_flutter_platform_settings)
## Getting Started
All widgets come with a property 'settingsKey' which is used to store them in shared_preferences, so you can retrieve the value from anywhere using the same key. The only exceptions from this are SettingsScreen, SettingsGroup and CustomSetting (which is intended to launch navigation routes or to just show some information).

## Widgets
### SettingsScreen
The uppermost settings container. Use this as a starting point.
```dart
SettingsScreen (
  title: 'App Settings',
  children: [],
)
```
### SettingsGroup
A container that groups various settings together
```dart
SettingsGroup (
  title: 'First Group',
  children: [],
)
```
### CustomSetting
A settings widget that takes an onPressed action, useful e.g. to launch navigation routes.
```dart
CustomSetting (
  title: 'My Custom Setting',
  subtitle: 'My subtitle',
  onPressed: () => debugPrint('hello world!'),
)
```
### TextSetting
A widget that shows a textfield
```dart
TextSetting<int>(
  settingsKey: 'text-setting',
  title: 'A text setting for integers only',
  keyboardType: TextInputType.number,
  defaultValue: 42000,
  validator: (value) {
    if (value == null || value < 1024 || value > 65536) {
      return 'Integer number between 1024 and 65536 expected';
    }
  },
),
```
### ImageSetting
A widget with an image picker that stores the filename as a string
```dart
ImageSetting(
  settingsKey: 'image-setting',
  title: 'This is an image setting'
),
```
### SwitchSetting
A widget with a two-state switch
```dart
SwitchSetting(
  settingsKey: 'switch-setting',
  title: 'This is a switch setting',
  defaultValue: true,
)
```
### CheckboxSetting
A widget with a checkbox
```dart
CheckboxSetting(
  settingsKey: 'checkbox-setting',
  title: 'This is a checkbox setting',
  defaultValue: false,
),
```
### RadioSetting
This shows a list of radio buttons
```dart
RadioSetting<int>(
  settingsKey:  'radio-setting',
  title:  'This is a radio setting',
  items: [
    ListItem<int>(value: 1, caption: 'One'),
    ListItem<int>(value: 2, caption: 'Two'),
    ListItem<int>(value: 3, caption: 'Three'),
    ListItem<int>(value: 4, caption: 'Four'),
    ListItem<int>(value: 5, caption: 'Five'),
  ],
),
```
### RadioModalSetting
The radio buttons in this one are shown in a dialog
```dart
RadioModalSetting<int>(
  settingsKey: 'radio-modal-setting',
  title: 'This is a modal radio setting',
  defaultValue: 5,
  items: [
    ListItem<int>(value: 1, caption: 'One'),
    ListItem<int>(value: 2, caption: 'Two'),
    ListItem<int>(value: 3, caption: 'Three'),
    ListItem<int>(value: 4, caption: 'Four'),
    ListItem<int>(value: 5, caption: 'Five'),
    ListItem<int>(value: 6, caption: 'Six'),
  ],
),
```
### SliderSetting
You guessed right, a widget with a slider
```dart
SliderSetting(
  settingsKey: 'slider-setting',
  title: 'This is a slider setting',
  minValue: 0.0,
  maxValue: 100.0,
  divisions: 100,
  defaultValue: 25.0,
),
```
### MultiSelectSetting
A setting that shows a multi-selection list
```dart
MultiSelectSetting<String>(
  settingsKey: 'multi-select-setting',
  title: "A multi-select setting",
  items: [
    ListItem(value: "hello", caption: "Hello"),
    ListItem(value: "world", caption: "World"),
    ListItem(value: "foo", caption: "foo"),
    ListItem(value: "bar", caption: "bar"),
  ]
),
```
#### You can find more example use cases in the included example app.
## Extensibility
You can define your own widgets by subclassing ``SettingsWidgetBase<T>`` and ``SettingsWidgetBaseState<T, YourSettingsWidgetClass>`` with ``T`` being the type stored via shared_preferences.

If you need a data type *not* supplied by shared_preferences, you can override ``SettingsWidgetBaseState::serialize()`` and ``SettingsWidgetBaseState::deserialize()`` and do the serialization yourself.
#### Note: Serialization and deserialization behave different since version 2.0.0. See the included example
