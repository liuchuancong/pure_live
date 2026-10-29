import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import 'package:pure_live/app/theme/fonts/font_entry.dart';

/// The categories Google files its families under, in the order its site
/// lists them.
const List<String> kGoogleFontCategories = ['serif', 'sans-serif', 'display', 'handwriting', 'monospace'];

/// The category map pruned from the catalogue: family → Google's category.
const String _categoryAsset = 'assets/fonts/google_font_categories.json';

/// Every family the official Google Fonts site lists, named exactly as
/// `google_fonts` registers them, with the category Google files it under.
///
/// The registry comes from the package (generated from the site's own
/// catalogue); the categories come from the Font Picker constants built off
/// the same API, so a family newer than that snapshot falls under "other".
Future<List<FontEntry>> loadGoogleFontCatalog() async {
  final raw = await rootBundle.loadString(_categoryAsset);
  final categories = (jsonDecode(raw) as Map<String, Object?>).cast<String, String>();
  return [
    for (final family in GoogleFonts.asMap().keys)
      FontEntry(
        id: family,
        name: family,
        region: FontRegion.overseas,
        source: FontSource.google,
        category: categories[family] ?? 'other',
      ),
  ];
}

/// Google's catalogue, loaded once for the font manager.
final googleFontCatalogProvider = FutureProvider<List<FontEntry>>((ref) => loadGoogleFontCatalog());
