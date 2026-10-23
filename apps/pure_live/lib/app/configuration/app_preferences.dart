import 'package:flutter/widgets.dart' show Color;
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/app/theme/app_theme_mode.dart' show AppThemeMode;
import 'package:pure_live/i18n/translations.g.dart' show AppLocale;

/// Where the appearance document is persisted: one box, one versioned key,
/// the same discipline every preference group follows.
abstract final class AppearanceKeys {
  /// The box every preference group document shares.
  static const String box = 'settings.preferences';

  /// The appearance group's document key, versioned in its name.
  static const String document = 'preferences.appearance.v1';
}

/// What a failed appearance read or write looked like.
enum AppearanceFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A stored object did not decode.
  decode,

  /// The document could not be written.
  write,
}

/// The persisted appearance: theme mode, accent colour, language.
///
/// Plain primitives only — the mode's id and the colour's argb — so a
/// stored document survives the theme packages renaming their types.
final class AppearanceDocument {
  /// A document.
  const new({this.themeMode = AppThemeMode.system, this.accentArgb, this.locale});

  /// Decodes a stored map; unknown shapes keep the defaults.
  factory fromJson(Map<dynamic, dynamic> json) => AppearanceDocument(
    themeMode: switch (json['themeMode'] as String?) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    },
    accentArgb: json['accentArgb'] as int?,
    locale: switch (json['locale'] as String?) {
      'zh-CN' => AppLocale.zhCn,
      'zh-TW' => AppLocale.zhTw,
      'en-US' => AppLocale.enUs,
      'ja-JP' => AppLocale.jaJp,
      _ => null,
    },
  );

  /// Light/dark/system.
  final AppThemeMode themeMode;

  /// The accent override's argb, or null for the system's.
  final int? accentArgb;

  /// The language, or null to follow the system.
  final AppLocale? locale;

  /// Encodes for storage.
  Map<String, Object?> toJson() => {
    'themeMode': switch (themeMode) {
      AppThemeMode.system => 'system',
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
    },
    if (accentArgb != null) 'accentArgb': accentArgb,
    if (locale != null)
      'locale': switch (locale!) {
        AppLocale.zhCn => 'zh-CN',
        AppLocale.zhTw => 'zh-TW',
        AppLocale.enUs => 'en-US',
        AppLocale.jaJp => 'ja-JP',
      },
  };

  /// Returns a copy with the given fields replaced.
  AppearanceDocument copyWith({AppThemeMode? themeMode, int? accentArgb, AppLocale? locale}) => AppearanceDocument(
    themeMode: themeMode ?? this.themeMode,
    accentArgb: accentArgb ?? this.accentArgb,
    locale: locale ?? this.locale,
  );
}

/// The appearance document, in memory and on disk.
///
/// Reads are synchronous so the first frame renders in the viewer's own
/// theme; writes go through immediately (this document changes a handful of
/// times in the app's life, so it needs no debounce).
final class AppearanceStore {
  /// A store persisting through [repository].
  new({required this.repository, this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(AppearanceFailure failure, Object error, StackTrace stack)? onError;

  AppearanceDocument _value = const AppearanceDocument();

  /// The current document, readable before the first frame.
  AppearanceDocument get value => _value;

  /// Loads the document; a missing, stale or broken one keeps the defaults.
  Future<void> load() async {
    final Map<dynamic, dynamic>? stored;
    try {
      stored = repository.get(AppearanceKeys.document);
    } on Object catch (error, stack) {
      onError?.call(AppearanceFailure.read, error, stack);
      return;
    }
    if (stored == null) {
      return;
    }
    try {
      _value = AppearanceDocument.fromJson(Map<String, Object?>.from(stored));
    } on Object catch (error, stack) {
      onError?.call(AppearanceFailure.decode, error, stack);
    }
  }

  /// Persists [document] as the current one.
  Future<void> save(AppearanceDocument document) async {
    _value = document;
    try {
      await repository.save(AppearanceKeys.document, document.toJson());
    } on Object catch (error, stack) {
      onError?.call(AppearanceFailure.write, error, stack);
    }
  }
}

/// The document's colour as a [Color], or null.
Color? accentColorOf(AppearanceDocument document) => document.accentArgb == null ? null : Color(document.accentArgb!);
