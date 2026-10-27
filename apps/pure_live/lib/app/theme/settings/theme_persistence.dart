import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/theme/fonts/font_defaults.dart' show kBundledFontPresets;
import 'package:pure_live/app/theme/fonts/font_library.dart' show CloudFontIds;

/// The theme's persisted subset: the choices the settings surface writes
/// and the root reads back on boot.
///
/// Every write lands in the store the moment it happens; a closed store
/// loses the choice rather than the session.
abstract final class ThemePersistence {
  /// Whether the platform's dynamic palette seeds the theme; false keeps the
  /// viewer's own accent.
  static bool readDynamicColor() {
    try {
      return StoragePrefs.getBool('theme.dynamicColor') ?? false;
    } on Object {
      return false;
    }
  }

  /// Stores the dynamic-colour choice.
  static Future<void> storeDynamicColor({required bool value}) async {
    try {
      await StoragePrefs.setBool('theme.dynamicColor', value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// The stored mode, or null to let the settings default stand.
  static DsThemeMode? readMode() {
    try {
      return switch (StoragePrefs.getString('theme.mode')) {
        'light' => DsThemeMode.light,
        'dark' => DsThemeMode.dark,
        'system' => DsThemeMode.system,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  /// Stores the mode.
  static Future<void> storeMode(DsThemeMode mode) => _store('theme.mode', mode.name);

  /// The stored seed: a named tone (`seedBlue`), a custom colour as
  /// `#RRGGBB`/`#AARRGGBB`, or null for the platform accent (the root's
  /// own default).
  static String? readSeed() {
    try {
      return StoragePrefs.getString('theme.seed');
    } on Object {
      return null;
    }
  }

  /// Parses the reference's 6- or 8-digit hex colour forms (`#RRGGBB`,
  /// `0xAARRGGBB`); null for anything else.
  static Color? parseSeedColor(String? value) {
    if (value == null) return null;
    var hex = value.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    } else if (hex.toLowerCase().startsWith('0x')) {
      hex = hex.substring(2);
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final argb = int.tryParse(hex, radix: 16);
    return argb == null ? null : Color(argb);
  }

  /// The `#RRGGBB` form shown in the appearance rows and the picker's hex
  /// field.
  static String encodeSeedColor(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Stores a named tone or a custom hex colour; null clears it back to the
  /// platform accent.
  static Future<void> storeSeed(String? value) => value == null ? _remove('theme.seed') : _store('theme.seed', value);

  /// The stored contrast, or null to let the settings default stand.
  static DsContrast? readContrast() {
    try {
      return switch (StoragePrefs.getString('theme.contrast')) {
        'soft' => DsContrast.soft,
        'standard' => DsContrast.standard,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  /// Stores the contrast.
  static Future<void> storeContrast(DsContrast contrast) => _store('theme.contrast', contrast.name);

  /// The stored selection style, or null for the default.
  static DsSelectionStyle? readSelectionStyle() {
    try {
      return switch (StoragePrefs.getString('theme.selection')) {
        'soft' => DsSelectionStyle.soft,
        'strong' => DsSelectionStyle.strong,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  /// Stores the selection style.
  static Future<void> storeSelectionStyle(DsSelectionStyle style) => _store('theme.selection', style.name);

  /// Whether the clash rule is stored off; null keeps the default.
  static bool? readAutoClashRule() {
    try {
      return StoragePrefs.getBool('theme.autoClash');
    } on Object {
      return null;
    }
  }

  /// Stores the clash rule.
  static Future<void> storeAutoClashRule({required bool value}) async {
    try {
      await StoragePrefs.setBool('theme.autoClash', value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// The stored corner style, or null for the default.
  static DsCornerStyle? readCorners() {
    try {
      return switch (StoragePrefs.getString('theme.corners')) {
        'sharp' => DsCornerStyle.sharp,
        'standard' => DsCornerStyle.standard,
        'soft' => DsCornerStyle.soft,
        'pill' => DsCornerStyle.pill,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  /// Stores the corner style.
  static Future<void> storeCorners(DsCornerStyle style) => _store('theme.corners', style.name);

  /// The stored density, or null to follow the platform.
  static DsDensity? readDensity() {
    try {
      return switch (StoragePrefs.getString('theme.density')) {
        'compact' => DsDensity.compact,
        'touch' => DsDensity.touch,
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  /// Stores the density; null clears it back to the platform default.
  static Future<void> storeDensity(DsDensity? density) =>
      density == null ? _remove('theme.density') : _store('theme.density', density.name);

  /// The stored font family (a bundled preset id or a downloaded cloud
  /// family), or null for the platform's own face.
  static String? readFont() {
    try {
      return normalizeFontFamily(StoragePrefs.getString('theme.font'));
    } on Object {
      return null;
    }
  }

  /// The stored family when this build can draw it. Empty values, the
  /// reference's `Default` and 3.x's system aliases, ids from builds that
  /// bundled fewer faces and cloud ids whose folder is gone all fall back
  /// to the platform face instead of naming a family the app cannot load.
  static String? normalizeFontFamily(String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) return null;
    for (final (preset, _) in kBundledFontPresets) {
      if (preset == id) return id;
    }
    return CloudFontIds.contains(id) ? id : null;
  }

  /// Stores the font family; null clears it back to the platform face.
  static Future<void> storeFont(String? family) =>
      family == null ? _remove('theme.font') : _store('theme.font', family);

  /// Canonical locale codes the appearance pane offers.
  static const String localeSimplifiedChinese = 'zh-CN';
  static const String localeEnglish = 'en';

  /// Canonicalizes a persisted locale: earlier builds and the reference
  /// stored display names, while slang only resolves language tags. Empty,
  /// "system" and unknown values follow the system locale.
  static String? normalizeLocaleCode(String? value) {
    final code = value?.trim().toLowerCase();
    if (code == null || code.isEmpty || code == 'system') return null;
    if (code == 'zh' || code.startsWith('zh-') || code.startsWith('zh_')) {
      return localeSimplifiedChinese;
    }
    if (code == '简体中文' || code == '中文' || code == 'chinese' || code == 'simplified chinese') {
      return localeSimplifiedChinese;
    }
    if (code == 'en' || code.startsWith('en-') || code.startsWith('en_') || code == 'english') return localeEnglish;
    return null;
  }

  /// The stored locale's canonical code ('zh-CN', 'en'), or null to follow
  /// the system.
  static String? readLocale() {
    try {
      return normalizeLocaleCode(StoragePrefs.getString('app.locale'));
    } on Object {
      return null;
    }
  }

  /// Stores the locale's code; null clears it back to the system.
  static Future<void> storeLocale(String? code) => code == null ? _remove('app.locale') : _store('app.locale', code);

  static Future<void> _store(String key, String value) async {
    try {
      await StoragePrefs.setString(key, value);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  static Future<void> _remove(String key) async {
    try {
      await StoragePrefs.remove(key);
    } on Object {
      // Same nicety as store.
    }
  }
}

/// The named seeds the appearance pane offers, in display order.
const List<(String, DsSeed)> kNamedSeeds = [
  ('seedBlue', DsSeed.blue),
  ('seedNavy', DsSeed.navy),
  ('seedIndigo', DsSeed.indigo),
  ('seedGraphite', DsSeed.graphite),
  ('seedOxblood', DsSeed.oxblood),
  ('seedForest', DsSeed.forest),
];
