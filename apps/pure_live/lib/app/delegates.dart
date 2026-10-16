import 'package:flutter/widgets.dart';

import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';
import 'package:live_uikit_material/live_uikit_material.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// Every localization delegate the app can need, installed up front so
/// switching `UiConfig.language` never crashes on a missing delegate further
/// down the tree.
///
/// The core's delegates come first — Flutter's own chrome and its material
/// labels — and each design language contributes only its own internal
/// strings. `macos`, `neumorphic`, `glass` and `wind` need none.
///
/// slang carries the app's own strings and needs no delegate here; it wants
/// [TranslationProvider] above the widget that reads them instead.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  ...liveLocalizationsDelegates,
  ...fluentLocalizationsDelegates,
  ...cupertinoLocalizationsDelegates,
  ...materialLocalizationsDelegates,
  ...foruiLocalizationsDelegates,
];

/// The locales to declare to `WidgetsApp`: slang's, which every delegate
/// above covers.
List<Locale> get appSupportedLocales => AppLocaleUtils.supportedLocales;

/// The value for `WidgetsApp.locale`, kept in sync with slang's current locale.
Locale get appFlutterLocale => LocaleSettings.currentLocale.flutterLocale;
