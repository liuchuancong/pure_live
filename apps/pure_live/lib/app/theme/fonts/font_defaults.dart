import 'package:chinese_font_library/chinese_font_library.dart' show SystemChineseFont;
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform;
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

/// The face every platform draws its UI in unless the viewer picks another:
/// MiSans ships with the app (`pubspec.yaml`'s `flutter: fonts:`) and is the
/// default on Windows, macOS, Linux, Android and the web alike.
const String kDefaultFontFamily = 'MiSans';

/// The preset that stands for this device's own Chinese face rather than a
/// family bundled or fetched: [systemChineseFontFamily] resolves it per
/// platform when the theme is built.
const String kSystemChineseFontId = 'SystemChinese';

/// The prefix a downloaded free-font family is stored and registered under.
/// The rest of the id is a hash of the file's path in the collection.
const String kFreeFontIdPrefix = 'freefont:';

/// The default family. A stored family always outranks it.
String defaultFontFamily() => kDefaultFontFamily;

/// The family a stored value really names — a preset id that is not a family
/// of its own ([kSystemChineseFontId]) resolves here, and a Google family
/// resolves to the name `google_fonts` registers its file under. Null means
/// the default.
String? resolvedFontFamily(String? stored) => switch (stored) {
  null => kDefaultFontFamily,
  kSystemChineseFontId => systemChineseFontFamily() ?? kDefaultFontFamily,
  _ when isFreeFontId(stored) => stored,
  _ when isGoogleFontFamily(stored) => googleFontFamily(stored),
  _ => stored,
};

/// The name the engine knows a Google family by.
///
/// `google_fonts` registers each downloaded file as `<Family>_<variant>`, so
/// a theme that asks for the catalogue name alone ("Roboto") draws in the
/// fallback face and the fetch never starts. Asking the package for the style
/// both queues the file and answers the name it will be registered under; the
/// answer is kept, so a failed fetch is retried by the manager, not by every
/// rebuild.
String googleFontFamily(String family) => _googleFamilies[family] ??= GoogleFonts.getFont(family).fontFamily ?? family;

final Map<String, String> _googleFamilies = {};

/// The device's Chinese face, from `chinese_font_library`'s platform lists:
/// PingFang on Apple, Microsoft YaHei on Windows, the platform's `sans-serif`
/// (Noto CJK on stock Android) elsewhere. Linux answers null, where the
/// default MiSans stays.
String? systemChineseFontFamily({TargetPlatform? platform}) => switch (platform ?? defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => 'PingFang SC',
  TargetPlatform.windows => SystemChineseFont.windowsFontFamily.first,
  TargetPlatform.android || TargetPlatform.fuchsia => 'sans-serif',
  TargetPlatform.linux => null,
};

/// Whether [id] is a family `google_fonts` knows — the same registry the
/// official site is published from.
bool isGoogleFontFamily(String id) => GoogleFonts.asMap().containsKey(id);

/// Whether [id] was minted for a downloaded free-font file.
bool isFreeFontId(String id) => id.startsWith(kFreeFontIdPrefix);

/// A stored id this build can still draw: the default face, the system
/// preset, a downloaded free-font family or a Google family. Anything else —
/// the reference's `Default`, an old bundled or cloud face — falls back to the
/// default instead of naming a family the app cannot draw.
String? normalizeFontFamilyId(String? value) {
  final id = value?.trim();
  if (id == null || id.isEmpty || id == 'Default') return null;
  if (id == kDefaultFontFamily || id == kSystemChineseFontId) return id;
  if (isFreeFontId(id)) return id;
  return isGoogleFontFamily(id) ? id : null;
}

/// Registers a Google-hosted family on this device: `google_fonts` fetches
/// the files the first time and caches them, so the next boot is offline.
/// The bundled MiSans, the system face and the downloaded free fonts need
/// nothing here. True when a Google file finished loading.
///
/// A failed fetch (no network, a blocked host) leaves the current face in
/// place instead of failing the theme.
Future<bool> loadGoogleFont(String? family) async {
  if (family == null || family == kDefaultFontFamily || family == kSystemChineseFontId) return false;
  if (isFreeFontId(family) || !isGoogleFontFamily(family)) return false;
  try {
    googleFontFamily(family);
    await GoogleFonts.pendingFonts();
    return true;
  } on Object catch (error) {
    debugPrint('Google font $family could not be fetched: $error');
    return false;
  }
}
