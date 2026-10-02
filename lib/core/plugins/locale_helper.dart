import 'package:easy_localization/easy_localization.dart';

String i18n(String key, {Map<String, String>? args}) {
  return tr(key, namedArgs: args);
}

/// Returns a stable label while EasyLocalization is still loading its first
/// asset bundle. Calling [tr] before that point logs a false missing-key
/// warning and briefly renders the raw key in desktop chrome.
String i18nOr(String key, String fallback, {Map<String, String>? args}) {
  if (!trExists(key)) return fallback;
  return i18n(key, args: args);
}

bool i18nExists(String key) => trExists(key);
