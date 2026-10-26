import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The broadcaster-language codes the Twitch directory can be filtered to
/// (the reference's `TwitchLanguagesTile.languages`).
const List<String> kTwitchLanguageCodes = [
  'zh',
  'en',
  'ko',
  'ja',
  'es',
  'pt',
  'de',
  'fr',
  'ru',
  'it',
  'th',
  'vi',
  'id',
  'tr',
  'pl',
];

/// The reference's legacy preset: Chinese and Korean only.
const List<String> kTwitchLegacyLanguages = ['zh', 'ko'];

/// The stored key.
const String kTwitchLanguagesKey = 'sites.twitch.languages';

/// Owns the Twitch directory filter; an empty list means every language.
final class TwitchLanguagesController extends Notifier<List<String>> {
  @override
  List<String> build() {
    try {
      final stored = StoragePrefs.getStringList(kTwitchLanguagesKey) ?? const [];
      return [
        for (final code in stored)
          if (kTwitchLanguageCodes.contains(code)) code,
      ];
    } on Object {
      return const [];
    }
  }

  /// Replaces the filter and writes through; unknown codes are dropped.
  Future<void> set(List<String> codes) async {
    final next = [
      for (final code in kTwitchLanguageCodes)
        if (codes.contains(code)) code,
    ];
    state = next;
    try {
      await StoragePrefs.setStringList(kTwitchLanguagesKey, next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// The legacy zh/ko preset.
  Future<void> useLegacy() => set(kTwitchLegacyLanguages);

  /// Every language.
  Future<void> clear() => set(const []);
}

/// The Twitch directory language filter.
final twitchLanguagesProvider = NotifierProvider<TwitchLanguagesController, List<String>>(
  TwitchLanguagesController.new,
);
