// Module: lib/src/plural_rules.dart
// Purpose: CLDR cardinal plural selection for the languages this app's translations cover, and the operand
// maths the rules are written in.
// Author: liuchuancong
// Created: 2026-10-11
//
// The four-language version of this rule set (zh/ja/ko, en, ru, else) was enough for the first strings and
// wrong for everything else: French counts 0 and 1 as `one`, Arabic has six forms, Polish and Czech need the
// fraction digits, Slovenian has a dual. Plural rules are a closed published table, so they are transcribed
// here rather than guessed, and the languages not listed fall to `other`, which every translation must carry.

import 'locale.dart';
import 'plural_math.dart';

/// Which plural form a count takes in [language].
///
/// [number] is the value as displayed: `1.0` items is plural in English (`v = 1`), and `1` is singular, so
/// the operands - not just the integer part - decide.
PluralCategory pluralCategoryOf(num number, {required String language}) {
  final operands = PluralOperands.of(number);
  final rule = _rules[_baseLanguage(language)] ?? _otherOnly;
  return rule(operands);
}

/// The integer-only convenience over [pluralCategoryOf], for callers that count whole things rather than
/// display a measurement, where the visible fraction digits cannot change the answer.
PluralCategory pluralCategory(int count, {String language = 'en'}) => pluralCategoryOf(count, language: language);

/// Formats a count with the plural rule of [language], given the forms available.
///
/// A missing `other` form is a bug in the translation, so the raw count is returned rather than throwing
/// inside a widget build.
String pluralize(int count, {required Map<PluralCategory, String> forms, String language = 'en'}) {
  final template = forms[pluralCategory(count, language: language)] ?? forms[PluralCategory.other];
  if (template == null) {
    return '$count';
  }
  return template.replaceAll('{}', '$count');
}

/// The language subtag of a tag that may still carry a script or region.
///
/// Callers pass what the device reports - `zh_Hans_CN`, `pt-BR` - and the plural rule is chosen by the
/// language alone, so the stripping happens here rather than at every call site.
String _baseLanguage(String tag) {
  var text = tag.trim();
  final dash = text.indexOf('-');
  if (dash > 0) {
    text = text.substring(0, dash);
  }
  final underscore = text.indexOf('_');
  if (underscore > 0) {
    text = text.substring(0, underscore);
  }
  return text.toLowerCase();
}

/// Languages whose cardinal rules are identical for the counts this app shows, collapsed to one entry.
typedef PluralRule = PluralCategory Function(PluralOperands n);

PluralCategory _otherOnly(PluralOperands n) => PluralCategory.other;

/// English, German, Dutch, Italian, Spanish, Portuguese and Swahili agree on the simple form; only the
/// Romance languages add the 0/1-vanishing-fraction clause, kept separate below.
PluralCategory _germanic(PluralOperands n) => n.i == 1 && n.v == 0 && n.f == 0
    ? PluralCategory.one
    : n.v != 0
    ? PluralCategory.one
    : PluralCategory.other;

PluralCategory _plainOne(PluralOperands n) =>
    n.i == 1 && n.v == 0 && n.f == 0 ? PluralCategory.one : PluralCategory.other;

final Map<String, PluralRule> _rules = <String, PluralRule>{
  // one: n = 1; other.
  'en': (n) => n.i == 1 && n.v == 0 && n.f == 0 ? PluralCategory.one : PluralCategory.other,
  'de': _plainOne,
  'nl': _plainOne,
  'sv': _plainOne,
  'da': _plainOne,
  'fi': _plainOne,
  'el': _plainOne,
  'hu': _plainOne,
  'tr': _plainOne,
  'he': (n) => n.i == 1 && n.v == 0
      ? PluralCategory.one
      : n.i == 2 && n.v == 0
      ? PluralCategory.two
      : n.v == 0 && (n.i < 0 || n.i > 10)
      ? PluralCategory.many
      : PluralCategory.other,
  // zero/one: n = 0 | n = 1 (Norwegian uses one for 0 and 1 as `one`, so keep zero explicit).
  'no': (n) => n.i == 0 || n.i == 1 ? PluralCategory.one : PluralCategory.other,
  // Romance: one covers 0 and 1 including a single visible fraction digit.
  'fr': (n) => n.i == 0 || n.i == 1
      ? PluralCategory.one
      : n.v == 0 && n.i != 0 && n.i % 1000000 == 0 && n.e == 0
      ? PluralCategory.many
      : PluralCategory.other,
  'es': _germanic,
  'pt': _germanic,
  'it': _germanic,
  'ca': _germanic,
  // Slavic with the mod-10 / mod-100 pattern.
  'ru': _slavic,
  'uk': _slavic,
  'be': _slavic,
  'sr': _slavic,
  'hr': _slavic,
  'bs': _slavic,
  // Polish and Czech need the fraction digits and the two-digit tail.
  'pl': (n) => n.i == 1 && n.v == 0
      ? PluralCategory.one
      : n.v == 0 && n.i % 10 >= 2 && n.i % 10 <= 4 && (n.i % 100 < 12 || n.i % 100 > 14)
      ? PluralCategory.few
      : n.v == 0 &&
            (n.i != 1 && n.i % 10 >= 0 && n.i % 10 <= 1 ||
                n.i % 10 >= 5 && n.i % 10 <= 9 ||
                n.i % 100 >= 12 && n.i % 100 <= 14)
      ? PluralCategory.many
      : n.v != 0
      ? PluralCategory.one
      : PluralCategory.other,
  'cs': (n) => n.i == 1 && n.v == 0
      ? PluralCategory.one
      : n.i >= 2 && n.i <= 4 && n.v == 0
      ? PluralCategory.few
      : n.v != 0
      ? PluralCategory.many
      : PluralCategory.other,
  'sk': (n) => n.i == 1
      ? PluralCategory.one
      : n.i >= 2 && n.i <= 4
      ? PluralCategory.few
      : n.v != 0
      ? PluralCategory.many
      : PluralCategory.other,
  'lt': (n) => n.i % 10 == 1 && (n.i % 100 < 11 || n.i % 100 > 19)
      ? PluralCategory.one
      : n.i % 10 >= 2 && (n.i % 100 < 11 || n.i % 100 > 19)
      ? PluralCategory.few
      : n.f != 0
      ? PluralCategory.many
      : PluralCategory.other,
  'lv': (n) => n.i % 10 == 1 && n.i % 100 != 11
      ? PluralCategory.one
      : n.i % 10 >= 2 && n.i % 100 != 12
      ? PluralCategory.two
      : PluralCategory.other,
  // Dual.
  'sl': (n) => n.v == 0 && n.i % 100 == 1
      ? PluralCategory.one
      : n.v == 0 && n.i % 100 == 2
      ? PluralCategory.two
      : n.v == 0 && (n.i % 100 == 3 || n.i % 100 == 4) || n.v != 0
      ? PluralCategory.few
      : PluralCategory.other,
  // Arabic: zero, one, two, few (mod 100 in 3..10), many (mod 100 in 11..99), other.
  'ar': (n) => n.i == 0 && n.v == 0
      ? PluralCategory.zero
      : n.i == 1 && n.v == 0
      ? PluralCategory.one
      : n.i == 2 && n.v == 0
      ? PluralCategory.two
      : n.v == 0 && n.i % 100 >= 3 && n.i % 100 <= 10
      ? PluralCategory.few
      : n.v == 0 && n.i % 100 >= 11 && n.i % 100 <= 99
      ? PluralCategory.many
      : PluralCategory.other,
  // Bilingual few/many on the tail digits.
  'ro': (n) => n.i == 1 && n.v == 0
      ? PluralCategory.one
      : n.v != 0 || (n.i == 0 && n.v == 0) || (n.i != 1 && n.i % 1000000 == 0 && n.e == 0)
      ? PluralCategory.few
      : PluralCategory.other,
  // East Asian and Austronesian: one form for every count.
  'zh': _otherOnly,
  'ja': _otherOnly,
  'ko': _otherOnly,
  'id': _otherOnly,
  'ms': _otherOnly,
  'th': _otherOnly,
  'vi': _otherOnly,
  'km': _otherOnly,
  'lo': _otherOnly,
  'my': _otherOnly,
  'ka': _otherOnly,
  'hy': _otherOnly,
};

PluralCategory _slavic(PluralOperands n) {
  final mod10 = n.i % 10;
  final mod100 = n.i % 100;
  if (mod10 == 1 && mod100 != 11) {
    return PluralCategory.one;
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return PluralCategory.few;
  }
  if (mod10 == 0 || mod10 >= 5 || mod100 >= 11 && mod100 <= 14) {
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

/// The plural forms a [language] can require, so a translation file can be validated before it ships.
///
/// An editor told "provide one and other" for Polish gets a runtime fallback the moment somebody displays
/// 2 items, which is why the set is derived from the rule rather than listed by hand.
Set<PluralCategory> requiredCategories(String language) {
  final probe = <PluralCategory>{};
  for (final count in _probeCounts) {
    probe.add(pluralCategoryOf(count, language: language));
  }
  probe.add(PluralCategory.other);
  return probe;
}

const List<int> _probeCounts = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  44,
  45,
  46,
  47,
  48,
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66,
  67,
  68,
  69,
  70,
  71,
  72,
  73,
  74,
  75,
  76,
  77,
  78,
  79,
  80,
  81,
  82,
  83,
  84,
  85,
  86,
  87,
  88,
  89,
  90,
  91,
  92,
  93,
  94,
  95,
  96,
  97,
  98,
  99,
  100,
  101,
  102,
  103,
  104,
  105,
  106,
  107,
  108,
  109,
  110,
  111,
  112,
  113,
  114,
  115,
  116,
  117,
  118,
  119,
  120,
  121,
  1000,
  1001,
  1002,
];

/// Which forms a translation file for [language] must carry, in category order.
///
/// `other` is always required - a language with a single form still uses it - and a file missing one of these
/// is reported when it loads rather than producing a fallback the first time somebody displays a count.
List<PluralCategory> requiredFormNames(String language) {
  final needed = requiredCategories(language).toList()..sort((left, right) => left.index.compareTo(right.index));
  return List<PluralCategory>.unmodifiable(needed);
}
