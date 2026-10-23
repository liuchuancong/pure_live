import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/i18n/translations.g.dart' show AppLocale;

/// The user's language choice, in memory for now; the storage phase swaps in
/// a persisted backing store without changing the interface.
///
/// Null means "follow the system locale".
final class LocalePreferencesController extends Notifier<AppLocale?> {
  @override
  AppLocale? build() => null;

  /// The language the viewer picked, or null for the system's.
  AppLocale? get locale => state;

  /// Picks the language, or clears the override with null.
  set locale(AppLocale? locale) => state = locale;
}

/// The language preference the shell reads.
final localePreferencesProvider = NotifierProvider<LocalePreferencesController, AppLocale?>(
  LocalePreferencesController.new,
);
