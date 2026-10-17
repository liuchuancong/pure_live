import 'package:fluent_2/fluent_2.dart' show FluentLocalizations;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' show FLocalizations;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Every localization delegate the app can need, installed up front so
/// switching `UiConfig.language` never crashes on a missing delegate further
/// down the tree.
///
/// The core's delegates come first — Flutter's own chrome and its material /
/// cupertino labels — then the two hosted libraries that ship their own
/// strings: fluent_2's `FluentLocalizations` and forui's `FLocalizations`.
/// `macos`, `neumorphic`, `glass`, `wind` and `yaru` need none beyond those.
///
/// slang carries the app's own strings and needs no delegate here; it wants
/// [TranslationProvider] above the widget that reads them instead.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  ...liveLocalizationsDelegates,
  FluentLocalizations.delegate,
  FLocalizations.delegate,
];

/// The locales to declare to `WidgetsApp`: slang's, which every delegate
/// above covers.
List<Locale> get appSupportedLocales => AppLocaleUtils.supportedLocales;

/// The value for `WidgetsApp.locale`, kept in sync with slang's current locale.
Locale get appFlutterLocale => LocaleSettings.currentLocale.flutterLocale;
