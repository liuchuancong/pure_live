import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart' show appearanceStoreProvider;
import 'package:pure_live/app/configuration/app_preferences.dart' show AppearanceDocument;
import 'package:pure_live/app/theme/theme_preferences.dart' show themePreferencesProvider;
import 'package:pure_live/i18n/translations.g.dart' show AppLocale;

/// The user's language choice, persisted in the appearance document.
///
/// Null means "follow the system locale".
final class LocalePreferencesController extends Notifier<AppLocale?> {
  @override
  AppLocale? build() => ref.watch(appearanceStoreProvider).value.locale;

  /// The language the viewer picked, or null for the system's.
  AppLocale? get locale => state;

  /// Picks the language, or clears the override with null.
  set locale(AppLocale? locale) {
    state = locale;
    final theme = ref.read(themePreferencesProvider);
    final document = AppearanceDocument(
      themeMode: theme.mode,
      accentArgb: theme.accentOverride?.toARGB32(),
      locale: locale,
    );
    unawaited(ref.read(appearanceStoreProvider).save(document));
  }
}

/// The language preference the shell reads.
final localePreferencesProvider = NotifierProvider<LocalePreferencesController, AppLocale?>(
  LocalePreferencesController.new,
);
