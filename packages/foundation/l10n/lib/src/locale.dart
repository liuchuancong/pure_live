// Module: lib/src/locale.dart
// Purpose: Locale tag parsing, fallback resolution and the plural and RTL rules the UI layer asks for.
// Author: liuchuancong
// Created: 2026-10-08
//
// Picking a translation is where a missing asset becomes visible to a user, so the order matters: an exact
// match, then the same language with a different script, then the bare language, then the fallback. Going
// straight from zh_Hant_TW to zh_CN is wrong; going to en is right.

/// A parsed BCP-47-ish language tag: `zh`, `zh_Hans_CN`, `sr-Latn-RS`.
final class LocaleTag {
  const LocaleTag({required this.language, this.script, this.region});

  /// Parses `zh`, `zh_CN`, `zh-Hans-CN` or `zh-Hans_CN`. Returns null when the language is missing.
  factory LocaleTag.parse(String tag) {
    final parts = tag.trim().split(RegExp(r'[-_]'));
    if (parts.isEmpty || parts.first.isEmpty) {
      throw FormatException('not a language tag', tag);
    }
    return LocaleTag(
      language: parts[0].toLowerCase(),
      script: parts.length > 1 && parts[1].length == 4 ? _titleCase(parts[1]) : null,
      region: _regionOf(parts),
    );
  }

  static LocaleTag? tryParse(String? tag) {
    if (tag == null || tag.trim().isEmpty) {
      return null;
    }
    try {
      return LocaleTag.parse(tag);
    } on FormatException {
      return null;
    }
  }

  static String? _regionOf(List<String> parts) {
    if (parts.length < 2) {
      return null;
    }
    final last = parts.last;
    if (last.length == 2) {
      return last.toUpperCase();
    }
    if (last.length == 4 && parts.length == 2) {
      // A four letter tail after the language is a script, not a region.
      return null;
    }
    return null;
  }

  static String _titleCase(String value) => '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';

  final String language;

  /// The writing system, for example `Hans` or `Latn`.
  final String? script;

  /// The region code, upper cased, for example `CN` or `TW`.
  final String? region;

  /// The bare language, which is the widest fallback key.
  String get languageOnly => language;

  /// Language and script, the key that must not be collapsed into a bare language.
  String get languageAndScript => script == null ? language : '${language}_$script';

  /// The canonical `language_region` form used by the translations directory.
  String get primary => region == null ? language : '${language}_$region';

  @override
  String toString() {
    final parts = <String>[language, if (script != null) script!, if (region != null) region!];
    return parts.join('-');
  }

  @override
  bool operator ==(Object other) {
    return other is LocaleTag && other.language == language && other.script == script && other.region == region;
  }

  @override
  int get hashCode => Object.hash(language, script, region);
}

/// Chooses which available translation to use for a requested tag.
///
/// [available] is tried as given; the resolution order is exact, then language plus script, then bare
/// language, then [fallback]. A Traditional Chinese request therefore never lands on Simplified.
String? resolveLocale({required String requested, required List<String> available, String fallback = 'en'}) {
  final wanted = LocaleTag.tryParse(requested);
  if (wanted == null) {
    return available.contains(fallback) ? fallback : null;
  }
  final byExact = _firstWhere(available, (item) => item == wanted.toString() || item == wanted.primary);
  if (byExact != null) {
    return byExact;
  }
  final byScript = _firstWhere(
    available,
    (item) => LocaleTag.tryParse(item)?.languageAndScript == wanted.languageAndScript,
  );
  if (byScript != null) {
    return byScript;
  }
  final byLanguage = _firstWhere(available, (item) {
    final candidate = LocaleTag.tryParse(item);
    if (candidate == null || candidate.language != wanted.language) {
      return false;
    }
    // A request that names a script must not land on the other script of the same language: zh-Hant
    // falling back to zh-Hans reads as a wrong translation rather than a missing one.
    return wanted.script == null || candidate.script == wanted.script;
  });
  if (byLanguage != null) {
    return byLanguage;
  }
  return available.contains(fallback) ? fallback : null;
}

String? _firstWhere(List<String> values, bool Function(String value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}

/// Languages written right to left, enough to lay out the app without a platform call.
const Set<String> rightToLeftLanguages = <String>{'ar', 'he', 'fa', 'ur', 'yi', 'ps', 'sd'};

/// Whether [locale] is written right to left.
bool isRightToLeft(String locale) {
  final tag = LocaleTag.tryParse(locale);
  return tag != null && rightToLeftLanguages.contains(tag.language);
}

/// Which plural form a count takes. Names follow CLDR categories.
enum PluralCategory { zero, one, two, few, many, other }

/// Picks the plural category for [count] in [language].
///
/// English and Chinese cover the two rules this application ships; anything else falls back to the
/// `other` form, which every translation is required to provide.
PluralCategory pluralCategory(int count, {String language = 'en'}) {
  if (language == 'zh' || language == 'ja' || language == 'ko') {
    return PluralCategory.other;
  }
  if (language == 'en') {
    return count == 1 ? PluralCategory.one : PluralCategory.other;
  }
  if (language == 'ru') {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return PluralCategory.one;
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return PluralCategory.few;
    }
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

/// Formats a count with the plural rule of [language], given the forms available.
///
/// A missing `other` form is a bug in the translation, so the raw count is returned rather than throwing
/// inside a widget build.
String pluralize(int count, {required Map<PluralCategory, String> forms, String language = 'en'}) {
  final category = pluralCategory(count, language: language);
  final template = forms[category] ?? forms[PluralCategory.other];
  if (template == null) {
    return '$count';
  }
  return template.replaceAll('{}', '$count');
}
