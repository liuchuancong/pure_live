import 'package:flutter/widgets.dart' show LocalizationsDelegate;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';

/// Every localization delegate the app's shells can need, installed up front so
/// switching `UiConfig.language` never crashes on a missing delegate further
/// down the tree. Core delegates come first: app-level strings keep priority
/// and each design language supplies only its own internal strings.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  ...liveLocalizationsDelegates,
  ...fluentLocalizationsDelegates,
  ...cupertinoUiLocalizationsDelegates,
  ...materialUiLocalizationsDelegates,
  ...foruiLocalizationsDelegates,
];
