// Module: test/locale_test.dart
// Purpose: Verify locale parsing, the fallback order, RTL detection and plural selection.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_l10n/pure_live_l10n.dart';
import 'package:test/test.dart';

void main() {
  group('LocaleTag.parse', () {
    test('test_parse_languageOnly', () {
      final tag = LocaleTag.parse('zh');

      expect(tag.language, 'zh');
      expect(tag.script, isNull);
      expect(tag.region, isNull);
      expect(tag.primary, 'zh');
    });

    test('test_parse_underscoreRegion_isNormalised', () {
      final tag = LocaleTag.parse('zh_CN');

      expect(tag.language, 'zh');
      expect(tag.region, 'CN');
      expect(tag.primary, 'zh_CN');
    });

    test('test_parse_scriptAndRegion_areSeparated', () {
      final tag = LocaleTag.parse('zh-Hans-CN');

      expect(tag.script, 'Hans');
      expect(tag.region, 'CN');
      expect(tag.languageAndScript, 'zh_Hans');
      expect(tag.toString(), 'zh-Hans-CN');
    });

    test('test_parse_fourLetterTailWithoutRegion_isScriptNotRegion', () {
      final tag = LocaleTag.parse('sr-Latn');

      expect(tag.script, 'Latn');
      expect(tag.region, isNull);
    });

    test('test_parse_lowerCasedInput_isCanonicalised', () {
      final tag = LocaleTag.parse('ZH_cn');

      expect(tag.language, 'zh');
      expect(tag.region, 'CN');
    });

    test('test_parse_emptyTag_throwsAndTryParseReturnsNull', () {
      expect(() => LocaleTag.parse('  '), throwsA(isA<FormatException>()));
      expect(LocaleTag.tryParse(''), isNull);
      expect(LocaleTag.tryParse(null), isNull);
    });
  });

  group('resolveLocale', () {
    test('test_resolveLocale_exactMatch_wins', () {
      expect(resolveLocale(requested: 'zh_CN', available: <String>['en', 'zh_CN', 'zh_TW']), 'zh_CN');
    });

    test('test_resolveLocale_traditionalNeverFallsBackToSimplified', () {
      // The whole point of the script step: zh-Hant must not silently become zh-Hans.
      expect(resolveLocale(requested: 'zh-Hant-TW', available: <String>['en', 'zh-Hans-CN']), 'en');
      expect(resolveLocale(requested: 'zh-Hant-TW', available: <String>['en', 'zh-Hant-HK']), 'zh-Hant-HK');
    });

    test('test_resolveLocale_bareLanguageMatch_returnsTheAvailableVariant', () {
      // fr_FR is not offered, so the nearest honest answer is another French locale, not English.
      expect(resolveLocale(requested: 'fr_FR', available: <String>['en', 'fr_CA']), 'fr_CA');
    });

    test('test_resolveLocale_noLanguageAtAll_usesFallback', () {
      expect(resolveLocale(requested: 'de_DE', available: <String>['en', 'zh_CN']), 'en');
    });

    test('test_resolveLocale_unparseableRequest_usesFallback', () {
      expect(resolveLocale(requested: '??', available: <String>['en']), 'en');
    });

    test('test_resolveLocale_fallbackNotAvailable_returnsNull', () {
      expect(resolveLocale(requested: 'de', available: <String>['zh_CN'], fallback: 'en'), isNull);
    });
  });

  group('direction and plurals', () {
    test('test_isRightToLeft_knownScripts', () {
      expect(isRightToLeft('ar'), isTrue);
      expect(isRightToLeft('he_IL'), isTrue);
      expect(isRightToLeft('zh_CN'), isFalse);
      expect(isRightToLeft('nonsense'), isFalse);
    });

    test('test_pluralCategory_english', () {
      expect(pluralCategory(1), PluralCategory.one);
      expect(pluralCategory(0), PluralCategory.other);
      expect(pluralCategory(7), PluralCategory.other);
    });

    test('test_pluralCategory_chineseHasNoForms', () {
      expect(pluralCategory(1, language: 'zh'), PluralCategory.other);
      expect(pluralCategory(30, language: 'zh'), PluralCategory.other);
    });

    test('test_pluralCategory_russianRules', () {
      expect(pluralCategory(1, language: 'ru'), PluralCategory.one);
      expect(pluralCategory(21, language: 'ru'), PluralCategory.one);
      expect(pluralCategory(11, language: 'ru'), PluralCategory.many);
      expect(pluralCategory(3, language: 'ru'), PluralCategory.few);
      expect(pluralCategory(14, language: 'ru'), PluralCategory.many);
    });

    test('test_pluralCategory_unknownLanguage_isOther', () {
      expect(pluralCategory(5, language: 'sw'), PluralCategory.other);
    });

    test('test_pluralize_substitutesTheCount', () {
      const forms = <PluralCategory, String>{PluralCategory.one: '{} room', PluralCategory.other: '{} rooms'};

      expect(pluralize(1, forms: forms), '1 room');
      expect(pluralize(4, forms: forms), '4 rooms');
    });

    test('test_pluralize_missingOtherForm_returnsTheRawCount', () {
      // A translation gap must not throw inside a widget build.
      expect(pluralize(4, forms: <PluralCategory, String>{PluralCategory.one: '{} room'}), '4');
    });
  });
}
