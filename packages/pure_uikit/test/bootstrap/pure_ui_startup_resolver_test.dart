import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/src/bootstrap/pure_ui_startup_config.dart';
import 'package:pure_uikit/src/bootstrap/pure_ui_startup_resolver.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// The §6.3 table, one test per row: every abnormal start-up has a stated
/// outcome, and the outcome is a language plus a reason the boot log can print.
void main() {
  const fallback = PureDesignLanguage.fluent;

  /// The decode the app's persistence layer supplies: an id is the enum's
  /// `name`, and anything else names no language.
  PureDesignLanguage? decode(String? id) => id == null || id.isEmpty
      ? null
      : PureDesignLanguage.values.where((language) => language.name == id).firstOrNull;

  group('PureUiStartupResolver', () {
    test('mounts the stored language and says it came from the store', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'macos',
        decode: decode,
      );

      expect(config.language, PureDesignLanguage.macos);
      expect(config.origin, PureUiStartupOrigin.recorded);
      expect(config.isForced, isFalse);
      expect(config.reason, contains('macos'));
    });

    test('takes the product default when nothing was ever stored', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: '',
        decode: decode,
      );

      expect(config.language, fallback);
      expect(config.origin, PureUiStartupOrigin.notRecorded);
      expect(config.isForced, isTrue);
    });

    test('takes the product default when the stored id names no language', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'aLanguageThatWasRenamed',
        decode: decode,
      );

      expect(config.language, fallback);
      expect(config.origin, PureUiStartupOrigin.unrecognised);
      // The raw id survives into the reason: an unrecognised value is a fault
      // worth naming, not a silent default.
      expect(config.storedLanguageId, 'aLanguageThatWasRenamed');
      expect(config.reason, contains('aLanguageThatWasRenamed'));
    });

    test('lets a launch pin beat the store without touching it', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'macos',
        decode: decode,
        launchPin: PureDesignLanguage.wind,
      );

      expect(config.language, PureDesignLanguage.wind);
      expect(config.origin, PureUiStartupOrigin.launchPin);
      expect(config.pin, PureDesignLanguage.wind);
      // What the user chose is still recorded, so the next unpinned launch
      // honours it rather than the run that overrode it.
      expect(config.storedLanguageId, 'macos');
    });

    test('degrades to the product default when a language cannot be mounted', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'glass',
        decode: decode,
        isAvailable: (language) => language != PureDesignLanguage.glass,
      );

      expect(config.language, fallback);
      expect(config.origin, PureUiStartupOrigin.degraded);
      expect(config.isForced, isTrue);
    });

    test('never resolves to the sentinel value', () {
      // `device`-style "detect it later" has no place here: the host is chosen
      // from this value, so every path has to land on a concrete language.
      for (final stored in <String?>[null, '', 'macos', 'nonsense']) {
        final config = PureUiStartupResolver.resolve(
          defaultLanguage: fallback,
          storedLanguageId: stored,
          decode: decode,
        );
        expect(PureDesignLanguage.values, contains(config.language));
      }
    });
  });

  group('PureUiStartupConfig', () {
    test('names both the id that failed and the default that answered', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'nope',
        decode: decode,
      );

      expect(config.language, fallback);
      expect(config.origin, PureUiStartupOrigin.unrecognised);
      expect(config.defaultLanguage, fallback);
      expect(config.reason, contains('nope'));
      expect(config.reason, contains(fallback.name));
    });

    test('keeps the pin on record while the store keeps the user choice', () {
      final config = PureUiStartupResolver.resolve(
        defaultLanguage: fallback,
        storedLanguageId: 'yaru',
        decode: decode,
        launchPin: PureDesignLanguage.forui,
      );

      expect(config.pin, PureDesignLanguage.forui);
      expect(config.storedLanguageId, 'yaru');
      expect(config.reason, contains('forui'));
    });
  });
}
