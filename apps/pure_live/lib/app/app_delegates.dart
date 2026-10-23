import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Every localization delegate the app can need, installed up front so
/// switching `UiConfig.language` never crashes on a missing delegate further
/// down the tree.
///
/// The core's delegates come first — Flutter's own chrome and its material /
/// cupertino labels (`liveLocalizationsDelegates`). The retired per-language
/// libraries' delegates went with their packages: the mounted Fluent host
/// appends fluent_ui's own `FluentLocalizations` after these, and nothing
/// below the host draws a widget from a retired library, so `macos`,
/// `neumorphic`, `glass`, `wind` and `yaru` need no delegate of their own.
///
/// slang carries the app's own strings and needs no delegate here; it wants
/// [TranslationProvider] above the widget that reads them instead.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [...liveLocalizationsDelegates];

/// The locales to declare to `WidgetsApp`: slang's, which every delegate
/// above covers.
List<Locale> get appSupportedLocales => AppLocaleUtils.supportedLocales;

/// The value for `WidgetsApp.locale`, kept in sync with slang's current locale.
Locale get appFlutterLocale => LocaleSettings.currentLocale.flutterLocale;
