// Module: lib/src/catalog.dart
// Purpose: A namespaced translation catalog: source strings owned by each package, per-language bundles with
// plural forms, load-time validation, coverage reporting, and locale-correct number and date rendering.
// Author: liuchuancong
// Created: 2026-10-11
//
// Four apps and a dozen shared packages contribute strings, so keys are namespaced by owner - one app's
// `room.title` is not another's, and a merged flat map is how two owners silently overwrite each other.
// Validation happens here rather than at display time because a missing plural form is a translation bug that
// nobody sees until a user with the wrong count opens a screen, and by then the string is already shipped.
//
// The catalog holds no strings itself: a host registers its own source language and loads the packs that
// belong to it, which is what keeps this package out of the app's asset pipeline.

import 'package:intl/intl.dart' as intl;

import 'locale.dart';
import 'message_format.dart';
import 'plural_math.dart';
import 'plural_rules.dart';

/// One translatable string, owned by the package that declared it.
final class TranslationKey {
  const TranslationKey({required this.owner, required this.path});

  /// The declaring package or app: `pure_live_live`, `pure_bili`, `settings`.
  final String owner;

  /// The key inside that owner's namespace, dotted for grouping: `room.qualityLabel`.
  final String path;

  String get full => path.isEmpty ? owner : '$owner.$path';

  @override
  bool operator ==(Object other) => other is TranslationKey && other.owner == owner && other.path == path;

  @override
  int get hashCode => Object.hash(owner, path);

  @override
  String toString() => 'TranslationKey($full)';
}

/// What is wrong with a translation, and where.
enum CatalogProblemKind {
  /// A plural form the language requires is absent, so some counts fall back to `other`.
  missingPluralForm,

  /// The message pattern could not be parsed.
  invalidMessage,

  /// The translation dropped or renamed an argument the source string uses.
  argumentMismatch,

  /// A bundle carries a key no source string declares, which is usually a key that was renamed and orphaned.
  unknownKey,

  /// The report is full; further findings only raised [LocalizationCatalog.droppedProblemCount].
  reportTruncated,
}

/// How many findings one catalog keeps.
const int kCatalogProblemLimit = 256;

/// One validation finding.
final class CatalogProblem {
  const CatalogProblem(this.kind, this.key, this.detail, {this.language});

  final CatalogProblemKind kind;
  final String key;
  final String detail;
  final String? language;

  @override
  bool operator ==(Object other) =>
      other is CatalogProblem &&
      other.kind == kind &&
      other.key == key &&
      other.language == language &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, key, language, detail);

  @override
  String toString() => '${kind.name} $key${language == null ? '' : ' [$language]'}: $detail';
}

/// How complete one language is.
final class CatalogCoverage {
  const CatalogCoverage({
    required this.language,
    required this.total,
    required this.translated,
    required this.orphaned,
  });

  final String language;

  /// How many source strings exist.
  final int total;

  /// How many of them this language actually carries.
  final int translated;

  /// How many keys this language carries that no source string declares.
  final int orphaned;

  int get missing => total - translated;

  double get ratio => total == 0 ? 1 : translated / total;

  bool get isComplete => translated >= total;

  @override
  String toString() => 'CatalogCoverage($language $translated/$total (${(ratio * 100).round()}%), $orphaned orphaned)';
}

/// A catalog of namespaced strings, validated on load.
final class LocalizationCatalog {
  LocalizationCatalog({this.sourceLanguage = 'en', this.fallbackLanguage = 'en'});

  /// The language source strings are written in.
  final String sourceLanguage;

  /// The language a missing key falls back to before the key itself is shown.
  final String fallbackLanguage;

  /// language -> key -> plural form -> pattern.
  final Map<String, Map<TranslationKey, Map<String, String>>> _bundles =
      <String, Map<TranslationKey, Map<String, String>>>{};
  final Map<TranslationKey, String> _source = <TranslationKey, String>{};
  final Map<String, LocalizedMessage> _parsed = <String, LocalizedMessage>{};
  final List<CatalogProblem> _problems = <CatalogProblem>[];
  int _droppedProblems = 0;

  /// Everything validation found, in registration order, capped at [kCatalogProblemLimit].
  ///
  /// A mistyped pack can fail every one of its keys, and a ledger that grows per reload is how a debug build
  /// runs out of memory before the developer reads the first line. [isProblemReportTruncated] says so.
  List<CatalogProblem> get problems => List<CatalogProblem>.unmodifiable(_problems);

  bool get isProblemReportTruncated => _droppedProblems > 0;

  /// How many findings were discarded after the cap.
  int get droppedProblemCount => _droppedProblems;

  bool get isClean => _problems.isEmpty && _droppedProblems == 0;

  /// Every language with at least one bundle, plus the source language.
  Set<String> get languages {
    final out = <String>{sourceLanguage, ..._bundles.keys};
    return Set<String>.unmodifiable(out);
  }

  /// Declares an owner's source strings. Registering again replaces that owner's declarations, which is what
  /// a hot reload does; other owners keep theirs.
  void registerSource(String owner, Map<String, String> entries) {
    _requireOwner(owner);
    _source.removeWhere((key, _) => key.owner == owner);
    for (final entry in entries.entries) {
      final key = TranslationKey(owner: owner, path: entry.key);
      _source[key] = entry.value;
      _validatePattern(key.full, entry.value, language: sourceLanguage);
    }
  }

  /// Loads one owner's translations in one language, replacing that owner's previous bundle for it.
  ///
  /// A value is either a plain string or, for a plural message, a map of CLDR category (or `=N`) to pattern.
  void loadBundle(String owner, String languageTag, Map<String, Object?> entries) {
    _requireOwner(owner);
    final language = _normalize(languageTag);
    final byKey = _bundles.putIfAbsent(language, () => <TranslationKey, Map<String, String>>{})
      ..removeWhere((key, _) => key.owner == owner);
    for (final entry in entries.entries) {
      final key = TranslationKey(owner: owner, path: entry.key);
      final forms = _formsOf(entry.value);
      if (forms == null) {
        _add(
          CatalogProblem(
            CatalogProblemKind.invalidMessage,
            key.full,
            'value is neither a string nor a form map',
            language: language,
          ),
        );
        continue;
      }
      if (byKey.containsKey(key)) {
        _add(
          CatalogProblem(CatalogProblemKind.unknownKey, key.full, 'already carried by this bundle', language: language),
        );
        continue;
      }
      byKey[key] = forms;
      if (!_source.containsKey(key)) {
        _add(
          CatalogProblem(
            CatalogProblemKind.unknownKey,
            key.full,
            'no source string declares this key',
            language: language,
          ),
        );
      }
      _validateForms(key.full, forms, language: language, sourceText: _source[key]);
    }
  }

  /// Resolves [key] for [language], interpolating [args].
  ///
  /// The order is exact tag, then the same language, then the fallback, then the source string, then the key:
  /// showing an English string the user can read beats showing `room.title`, and showing the key is the last
  /// resort that makes the gap visible.
  String translate(
    String language,
    TranslationKey key, {
    Map<String, Object?> args = const <String, Object?>{},
    NumberRender? number,
  }) {
    final text = translateText(language, key, args: args, number: number);
    return text ?? key.full;
  }

  /// The same, but null instead of the key when nothing resolves, so a caller can log its own gap.
  String? translateText(
    String language,
    TranslationKey key, {
    Map<String, Object?> args = const <String, Object?>{},
    NumberRender? number,
  }) {
    for (final candidate in _candidates(language)) {
      final forms = _bundles[candidate]?[key];
      if (forms == null) {
        continue;
      }
      final pattern = _selectForm(forms, args, language: candidate);
      if (pattern == null) {
        continue;
      }
      return _render(key.full, pattern, args, language: candidate, number: number);
    }
    final source = _source[key];
    if (source == null) {
      return null;
    }
    return _render(key.full, source, args, language: sourceLanguage, number: number);
  }

  /// The same, addressed by `owner.path` for callers that read a key out of a data file.
  String translateString(
    String language,
    String key, {
    Map<String, Object?> args = const <String, Object?>{},
    NumberRender? number,
  }) {
    final dot = key.indexOf('.');
    if (dot <= 0) {
      return translate(
        language,
        TranslationKey(owner: key, path: ''),
        args: args,
        number: number,
      );
    }
    return translate(
      language,
      TranslationKey(owner: key.substring(0, dot), path: key.substring(dot + 1)),
      args: args,
      number: number,
    );
  }

  /// How complete [language] is against every registered source string.
  CatalogCoverage coverageFor(String language) {
    final normalized = _normalize(language);
    final bundle = _bundles[normalized] ?? const <TranslationKey, Map<String, String>>{};
    var translated = 0;
    for (final key in _source.keys) {
      if (bundle.containsKey(key)) {
        translated++;
      }
    }
    return CatalogCoverage(
      language: normalized,
      total: _source.length,
      translated: translated,
      orphaned: orphanedKeys(normalized).length,
    );
  }

  /// Keys declared by a bundle that no source string owns, which is how a rename shows up as orphans.
  List<String> orphanedKeys(String language) {
    final bundle = _bundles[_normalize(language)] ?? const <TranslationKey, Map<String, String>>{};
    final out = <String>[
      for (final key in bundle.keys)
        if (!_source.containsKey(key)) key.full,
    ]..sort();
    return out;
  }

  /// Every key the catalog knows about, source and bundle together, for a settings screen that lists gaps.
  Set<String> get declaredKeys => Set<String>.unmodifiable(<String>{for (final key in _source.keys) key.full});

  /// Every argument name a key's source string reads, for a caller that wants to check its own call sites.
  Set<String> argumentsOf(TranslationKey key) {
    final text = _source[key];
    if (text == null) {
      return const <String>{};
    }
    return _message(text).argumentNames;
  }

  /// A number in the locale's own grouping and decimal shapes.
  ///
  /// An unregistered locale is a translation-packaging problem, not a reason to fail a screen, so this
  /// degrades to the plain decimal rendering instead of throwing.
  String formatNumber(num value, String language, {int? decimals, bool compact = false}) {
    final locale = _intlLocale(language);
    try {
      final pattern = compact ? intl.NumberFormat.compact(locale: locale) : intl.NumberFormat.decimalPattern(locale);
      if (decimals != null) {
        pattern.maximumFractionDigits = decimals;
        pattern.minimumFractionDigits = decimals;
      }
      return pattern.format(value);
    } on Object {
      return decimals == null ? _plain(value) : value.toStringAsFixed(decimals);
    }
  }

  /// A date in the locale's own month and weekday names, falling back to ISO-8601.
  String formatDate(DateTime value, String language, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    try {
      return intl.DateFormat(pattern, _intlLocale(language)).format(value);
    } on Object {
      return value.toIso8601String();
    }
  }

  List<String> _candidates(String requested) {
    final tag = LocaleTag.tryParse(requested);
    final out = <String>[];
    void add(String? value) {
      if (value == null) {
        return;
      }
      final normalized = _normalize(value);
      if (!out.contains(normalized)) {
        out.add(normalized);
      }
    }

    add(requested);
    if (tag != null) {
      add(tag.toString());
      if (tag.script != null || tag.region != null) {
        add(tag.language);
      }
    }
    add(fallbackLanguage);
    add(sourceLanguage);
    return out;
  }

  static String _normalize(String languageTag) {
    final tag = LocaleTag.tryParse(languageTag);
    return tag == null ? languageTag.trim() : tag.toString();
  }

  Map<String, String>? _formsOf(Object? value) {
    if (value is String) {
      return <String, String>{'other': value};
    }
    if (value is! Map) {
      return null;
    }
    final forms = <String, String>{};
    for (final entry in value.entries) {
      final text = entry.value;
      if (entry.key is! String || text is! String) {
        return null;
      }
      forms[entry.key! as String] = text;
    }
    return forms.isEmpty ? null : forms;
  }

  String? _selectForm(Map<String, String> forms, Map<String, Object?> args, {required String language}) {
    if (forms.length == 1 && forms.containsKey('other')) {
      return forms['other'];
    }
    final count = _countOf(args);
    if (count == null) {
      return forms['other'];
    }
    final operands = PluralOperands.of(count);
    final exact = forms['=${operands.i}'];
    if (exact != null) {
      return exact;
    }
    return forms[pluralCategoryOf(count, language: language).name] ?? forms['other'];
  }

  /// The first numeric argument, which is what a plural message counts. A message that counts something it
  /// passes as text is out of scope here; the ICU `{n, plural, ...}` form covers it instead.
  static num? _countOf(Map<String, Object?> args) {
    for (final value in args.values) {
      if (value is num) {
        return value;
      }
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String _render(String key, String text, Map<String, Object?> args, {required String language, NumberRender? number}) {
    final message = _message(text);
    if (!message.isValid) {
      return text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (Match match) => '${args[match.group(1)] ?? match.group(0)}');
    }
    return message.format(args, language: language, number: number ?? _defaultNumber(language));
  }

  /// Parsed patterns are cached by their text, not by their key: two languages hold different text under the
  /// same key, and caching by key renders a French pattern with English operands.
  LocalizedMessage _message(String text) => _parsed[text] ??= LocalizedMessage.parse(text);

  NumberRender _defaultNumber(String language) => (value, digits) {
    if (digits == 0) {
      return formatNumber(value, language);
    }
    return formatNumber(value, language, decimals: digits);
  };

  void _validatePattern(String key, String text, {required String language}) {
    for (final problem in _message(text).problems) {
      _add(CatalogProblem(CatalogProblemKind.invalidMessage, key, problem.toString(), language: language));
    }
  }

  void _validateForms(String key, Map<String, String> forms, {required String language, String? sourceText}) {
    if (!forms.containsKey('other')) {
      _add(CatalogProblem(CatalogProblemKind.missingPluralForm, key, 'no "other" form', language: language));
    }
    // A single `other` string is a message that does not count anything; asking a host for Polish's six forms
    // for it would be a false alarm.
    if (forms.length > 1) {
      for (final needed in requiredFormNames(language)) {
        if (!forms.containsKey(needed.name)) {
          _add(
            CatalogProblem(
              CatalogProblemKind.missingPluralForm,
              key,
              'the language needs a "${needed.name}" form',
              language: language,
            ),
          );
        }
      }
    }
    for (final entry in forms.entries) {
      _validatePattern('$key#${entry.key}', entry.value, language: language);
    }
    if (sourceText != null) {
      final wanted = _message(sourceText).argumentNames;
      for (final entry in forms.entries) {
        final lost = wanted.difference(_message(entry.value).argumentNames);
        if (lost.isNotEmpty) {
          _add(
            CatalogProblem(
              CatalogProblemKind.argumentMismatch,
              key,
              'form "${entry.key}" drops ${lost.join(', ')}',
              language: language,
            ),
          );
        }
      }
    }
  }

  void _add(CatalogProblem problem) {
    if (_problems.length >= kCatalogProblemLimit) {
      if (!_problems.any((held) => held.kind == CatalogProblemKind.reportTruncated)) {
        _problems.add(
          CatalogProblem(
            CatalogProblemKind.reportTruncated,
            problem.key,
            'more than $kCatalogProblemLimit findings; the rest are counted in droppedProblemCount',
            language: problem.language,
          ),
        );
      }
      _droppedProblems++;
      return;
    }
    if (!_problems.contains(problem)) {
      _problems.add(problem);
    }
  }

  static void _requireOwner(String owner) {
    if (owner.trim().isEmpty) {
      throw ArgumentError.value(owner, 'owner', 'a translation owner namespace cannot be blank');
    }
  }

  static String _plain(num value) => value is int ? '$value' : _trimZero(value.toString());

  static String _trimZero(String text) {
    if (!text.contains('.')) {
      return text;
    }
    final trimmed = text.replaceAll(RegExp(r'0+$'), '');
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  /// intl takes hyphenated tags; the rest of this package accepts both spellings.
  static String _intlLocale(String language) => language.replaceAll('_', '-');
}
