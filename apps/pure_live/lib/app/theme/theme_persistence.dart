import 'package:desen_ui/desen_ui.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/theme/theme_settings.dart';

/// The theme's persisted subset: the choices the settings surface writes
/// and the root reads back on boot.
///
/// Every write lands in the store the moment it happens; a closed store
/// loses the choice rather than the session.
abstract final class ThemePersistence {
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

  /// The stored seed's name, or null for the platform accent (the root's
  /// own default).
  static String? readSeedName() {
    try {
      return StoragePrefs.getString('theme.seed');
    } on Object {
      return null;
    }
  }

  /// Stores the seed's name; null clears it back to the platform accent.
  static Future<void> storeSeedName(String? name) => name == null ? _remove('theme.seed') : _store('theme.seed', name);

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

  /// Whether dark surfaces collapse to true black.
  static bool readPureBlack() {
    try {
      return StoragePrefs.getBool('theme.pureBlack') ?? false;
    } on Object {
      return false;
    }
  }

  /// Stores the 纯黑 choice.
  static Future<void> storePureBlack({required bool value}) =>
      _store('theme.pureBlack', value ? 'true' : 'false');

  /// The stored font family (an app preset id), or null for the platform's
  /// own face.
  static String? readFont() {
    try {
      final stored = StoragePrefs.getString('theme.font');
      return (stored == null || stored.isEmpty) ? null : stored;
    } on Object {
      return null;
    }
  }

  /// Stores the font family; null clears it back to the platform face.
  static Future<void> storeFont(String? family) =>
      family == null ? _remove('theme.font') : _store('theme.font', family);

  /// The stored locale's code ('zh-CN', 'en'), or null to follow the system.
  static String? readLocale() {
    try {
      final stored = StoragePrefs.getString('app.locale');
      return (stored == null || stored.isEmpty) ? null : stored;
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

/// Rebuilds [settings] with [seed] applied (null = platform accent).
AppThemeSettings withSeed(AppThemeSettings settings, DsSeed? seed) => settings.rebuild((b) => b..seed = seed);
