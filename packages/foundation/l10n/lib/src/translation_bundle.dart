// Module: lib/src/translation_bundle.dart
// Purpose: Loads flat-key JSON translations and resolves keys through a
// locale fallback chain.
// Author: liuchuancong
// Created: 2026-10-10
//
// The assets/translations/<lang>.json files are flat key maps (2652 keys in
// zh.json), one document per language tag. Resolution walks the LocaleTag
// fallback chain: exact tag, then bare language, then the fallback locale.
// Interpolation replaces {name} placeholders; missing keys return the key
// itself, which is what makes a half-finished translation usable.

import 'dart:convert';

import 'locale.dart';

/// One language's translation document.
final class TranslationBundle {
  TranslationBundle({required this.tag, required Map<String, String> entries}) : _entries = Map.of(entries);

  final LocaleTag tag;
  final Map<String, String> _entries;

  factory TranslationBundle.fromJson(String tag, String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('translation document is not a JSON object');
    }
    return TranslationBundle(
      tag: LocaleTag.parse(tag),
      entries: {
        for (final entry in decoded.entries)
          if (entry.value is String) '${entry.key}': entry.value! as String,
      },
    );
  }

  int get keyCount => _entries.length;

  /// The translation for [key], with {placeholder} interpolation, or null when
  /// this bundle does not carry the key.
  String? lookup(String key, [Map<String, Object?>? params]) {
    final template = _entries[key];
    if (template == null) {
      return null;
    }
    if (params == null || params.isEmpty) {
      return template;
    }
    var out = template;
    for (final entry in params.entries) {
      out = out.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return out;
  }
}

/// Resolves translations across bundles through the locale fallback chain.
final class TranslationResolver {
  TranslationResolver({required Map<String, TranslationBundle> byTag, this.fallbackLanguage = 'en'}) : _byTag = byTag;

  final Map<String, TranslationBundle> _byTag;
  final String fallbackLanguage;

  /// Registers or replaces one language's bundle.
  void register(TranslationBundle bundle) => _byTag[bundle.tag.toString()] = bundle;

  /// Resolves [key] for [locale]: exact tag, then same language, then the
  /// fallback language, then the key itself.
  String translate(String locale, String key, [Map<String, Object?>? params]) {
    final tag = LocaleTag.tryParse(locale) ?? LocaleTag(language: fallbackLanguage);
    for (final candidate in _candidates(tag)) {
      final value = _byTag[candidate]?.lookup(key, params);
      if (value != null) {
        return value;
      }
    }
    return key;
  }

  List<String> _candidates(LocaleTag tag) {
    final out = <String>[
      tag.toString(),
      if (tag.script != null || tag.region != null) tag.language,
      if (tag.language != fallbackLanguage) fallbackLanguage,
    ];
    return out.toSet().toList(growable: false);
  }
}
