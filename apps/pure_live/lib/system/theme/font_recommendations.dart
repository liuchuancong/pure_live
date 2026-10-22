import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage;

/// The sentinel `appearance.fontFamily` carries to mean "the design language
/// picks the font": every skin gets the font its own platform's design
/// system ships with, instead of one global choice. An empty string is the
/// explicit 系统默认; any other id is a downloaded or imported family,
/// exactly as the font manager writes them.
const String kThemeFontFamily = 'theme';

/// Where the recommended family has to come from before it can draw.
enum RecommendedFontSource {
  /// The platform ships the font with its own system (Segoe UI on Windows);
  /// the engine resolves the installed family by name — nothing to download.
  installed,

  /// The font is official to the platform and shipped inside this app
  /// (`pubspec.yaml`'s `fonts:` families): always drawable, nothing to
  /// fetch, nothing to delete. The user's downloads and imports stack on
  /// top of these as replacements, never as prerequisites.
  bundled,

  /// The font is official to the platform but not present on this machine's
  /// font folder; it must live in the app's font tree (downloaded or
  /// imported under the same family id) before the recommendation applies.
  downloadable,

  /// The style has no owning platform and therefore no official font — the
  /// system default stands.
  none,
}

/// One skin's official font: the family string the engine is given, the
/// name the settings page shows, and where it comes from.
typedef RecommendedFont = ({String family, String name, RecommendedFontSource source});

/// The font each design language's own platform officially uses — not a
/// stylistic guess, the actual shipped family:
///
/// - fluent is Windows' design system: **Segoe UI**, installed on every
///   Windows machine and referenced by name (Windows 11 resolves that name
///   onto the Segoe UI Variable family its apps are meant to draw with);
/// - macos_ui and glass dress Apple's design languages: **SF Pro**, and
///   Cupertino's rounded register is **SF Pro Rounded** — Apple ships both
///   faces in its SF Fonts package;
/// - material is Google's: **Roboto**, Android's system face since 4.0;
/// - forui copies shadcn/ui, whose default template ships **Inter**;
/// - wind is the Flutter port of Tailwind (fluttersdk_wind), whose own UI
///   kit sets headings and body in **Inter**;
/// - yaru is Ubuntu's theme, carrying Canonical's **Ubuntu** font family.
///
/// Neumorphism is a technique, not a platform — no vendor ships its UI
/// text, so the skin answers [RecommendedFontSource.none] and the system
/// default stands. The downloadable faces are fetched from their vendors'
/// official distribution channels and registered under these family ids;
/// a downloadable pick counts only once its files are in the app's font
/// tree.
const Map<PureDesignLanguage, RecommendedFont> kRecommendedFonts = {
  PureDesignLanguage.fluent: (family: 'Segoe UI', name: 'Segoe UI', source: RecommendedFontSource.installed),
  PureDesignLanguage.macos: (family: 'SFPro', name: 'SF Pro', source: RecommendedFontSource.bundled),
  PureDesignLanguage.glass: (family: 'SFPro', name: 'SF Pro', source: RecommendedFontSource.bundled),
  PureDesignLanguage.cupertino: (
    family: 'SFRounded',
    name: 'SF Pro Rounded',
    source: RecommendedFontSource.downloadable,
  ),
  PureDesignLanguage.material: (family: 'Roboto', name: 'Roboto', source: RecommendedFontSource.bundled),
  PureDesignLanguage.forui: (family: 'Inter', name: 'Inter', source: RecommendedFontSource.bundled),
  PureDesignLanguage.wind: (family: 'Inter', name: 'Inter', source: RecommendedFontSource.bundled),
  PureDesignLanguage.yaru: (family: 'Ubuntu', name: 'Ubuntu', source: RecommendedFontSource.bundled),
  PureDesignLanguage.neumorphic: (family: '', name: '', source: RecommendedFontSource.none),
};

/// The bundled preset families — the official faces `pubspec.yaml` ships
/// inside the app, deduplicated and in table order. The font manager's
/// 预设字体 section lists exactly these; downloads and imports stack on top
/// of them as replacements.
const List<RecommendedFont> kBundledFonts = [
  (family: 'SFPro', name: 'SF Pro', source: RecommendedFontSource.bundled),
  (family: 'SFRounded', name: 'SF Pro Rounded', source: RecommendedFontSource.bundled),
  (family: 'Roboto', name: 'Roboto', source: RecommendedFontSource.bundled),
  (family: 'Inter', name: 'Inter', source: RecommendedFontSource.bundled),
  (family: 'Ubuntu', name: 'Ubuntu', source: RecommendedFontSource.bundled),
];

/// The official font of [language]; an unknown skin answers the none
/// source, which is the system default.
RecommendedFont recommendedFontFor(PureDesignLanguage language) =>
    kRecommendedFonts[language] ?? const (family: '', name: '', source: RecommendedFontSource.none);

/// What a stored [family] means while the app renders [language]:
///
/// - [kThemeFontFamily]: the platform's own font — installed families are
///   answered straight away, downloadable ones only once [isDownloaded]
///   says their files are in the app's font tree (an unregistered name
///   would fall through per-glyph anyway, and answering the system default
///   here keeps the settings page honest about what is drawing). A skin
///   without an official font is the system default too.
/// - empty (or null): the system default, unchanged.
/// - anything else: the choice stands verbatim — a downloaded cloud family
///   or an imported one, theme or no theme.
String? resolveThemeFont(
  String? family,
  PureDesignLanguage language, {
  required bool Function(String id) isDownloaded,
}) {
  if (family != kThemeFontFamily) {
    return (family == null || family.isEmpty) ? null : family;
  }
  final recommended = recommendedFontFor(language);
  return switch (recommended.source) {
    RecommendedFontSource.installed || RecommendedFontSource.bundled => recommended.family,
    RecommendedFontSource.downloadable when isDownloaded(recommended.family) => recommended.family,
    _ => null,
  };
}
