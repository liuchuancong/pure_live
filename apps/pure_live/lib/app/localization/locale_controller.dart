import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/localization/locale_preferences.dart' show localePreferencesProvider;
import 'package:pure_live/i18n/translations.g.dart' show AppLocale;

/// The locale the UI renders in: the user's choice, else the base locale
/// while the system's answer has no matching translation.
final activeLocaleProvider = Provider<AppLocale>((ref) => ref.watch(localePreferencesProvider) ?? AppLocale.zhCn);

/// The Material locale a slang locale turns into, so the shell never builds
/// a `Locale` by hand.
Locale flutterLocaleOf(AppLocale locale) => switch (locale) {
  AppLocale.zhCn => const Locale('zh', 'CN'),
  AppLocale.zhTw => const Locale('zh', 'TW'),
  AppLocale.enUs => const Locale('en', 'US'),
  AppLocale.jaJp => const Locale('ja', 'JP'),
};
