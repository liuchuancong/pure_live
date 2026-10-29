import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/theme/fonts/font_defaults.dart'
    show kDefaultFontFamily, kFreeFontIdPrefix, kSystemChineseFontId;
import 'package:pure_live/app/theme/fonts/font_entry.dart';

/// The catalogue asset: the collection's index, pruned to the four fields the
/// manager needs.
const String _catalogAsset = 'assets/fonts/free_font.json';

/// The project keeps every face under `docs/` in its repository; the raw host
/// answers the files directly and the jsDelivr mirror is the second try.
const String _rawBase = 'https://raw.githubusercontent.com/jaywcjlove/free-font/main/docs/';
const String _mirrorBase = 'https://cdn.jsdelivr.net/gh/jaywcjlove/free-font@main/docs/';

/// The id a face is stored and registered under: the prefix plus a hash of
/// its path, so the id survives renames of the shown name and never carries
/// slashes into a font family.
String freeFontIdOf(String path) => '$kFreeFontIdPrefix${_fnv1a(path)}';

/// The primary address of [path].
String freeFontUrl(String path) => '$_rawBase${_encodePath(path)}';

/// The mirror address of [path], tried when the primary host fails.
String freeFontMirrorUrl(String path) => '$_mirrorBase${_encodePath(path)}';

String _encodePath(String path) => path.split('/').map(Uri.encodeComponent).join('/');

/// Two independent 32-bit hashes over the path's code units: deterministic
/// on every platform, and wide enough that no two entries of a thousand can
/// share an id.
String _fnv1a(String value) {
  var fnv = 0x811c9dc5;
  var djb = 0x01000193;
  for (final unit in value.codeUnits) {
    fnv ^= unit;
    fnv = (fnv * 0x01000193) & 0xFFFFFFFF;
    djb = ((djb << 5) + djb + unit) & 0xFFFFFFFF;
  }
  return '${fnv.toRadixString(16).padLeft(8, '0')}${djb.toRadixString(16).padLeft(8, '0')}';
}

/// The two faces that are not catalogue rows: the bundled MiSans stays first
/// in the domestic list and the system face follows it.
const List<FontEntry> kBundledFontEntries = [
  FontEntry(
    id: kDefaultFontFamily,
    name: 'MiSans',
    region: FontRegion.domestic,
    source: FontSource.bundled,
    category: 'other',
  ),
  FontEntry(
    id: kSystemChineseFontId,
    name: 'System Chinese',
    region: FontRegion.domestic,
    source: FontSource.system,
    category: 'other',
  ),
];

/// Reads the collection's index from the bundled asset.
Future<List<FontEntry>> loadFreeFontCatalog() async {
  final raw = await rootBundle.loadString(_catalogAsset);
  final rows = (jsonDecode(raw) as List<Object?>).cast<Map<String, Object?>>();
  return [
    for (final row in rows)
      FontEntry(
        id: freeFontIdOf(row['p']! as String),
        name: row['n']! as String,
        region: FontRegion.domestic,
        source: FontSource.freeFont,
        category: row['c'] as String?,
        bytes: (row['b'] as num?)?.toInt() ?? 0,
        url: freeFontUrl(row['p']! as String),
        fallbackUrl: freeFontMirrorUrl(row['p']! as String),
      ),
  ];
}

/// The collection, loaded once for the font manager.
final freeFontCatalogProvider = FutureProvider<List<FontEntry>>((ref) => loadFreeFontCatalog());
