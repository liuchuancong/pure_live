import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart' hide Builder; // Builder resolves to built_value's in the part file.

part 'theme_settings.g.dart';

/// Everything `DsThemeData`'s factory can express, as the app's theme
/// settings — one getter per factory parameter, [theme] feeding them all
/// back in.
///
/// Nullable getters mean "let the API decide": a null [density] takes
/// `DsDensity.forPlatform`, a null [platform] takes
/// `defaultTargetPlatform`, a null [seed] takes `DsSeed.blue` (the app
/// seeds it from the platform accent where the machine has one), unset
/// typography falls back to the platform's designed face with the bundled
/// Schibsted Grotesk, and unset adjusters leave the generated tokens
/// untouched. Every change goes through `rebuild` — the generated builder
/// assigns null directly where a viewer clears a choice.
abstract class AppThemeSettings implements Built<AppThemeSettings, AppThemeSettingsBuilder> {
  factory AppThemeSettings([void Function(AppThemeSettingsBuilder) updates]) = _$AppThemeSettings;

  AppThemeSettings._();

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AppThemeSettingsBuilder b) {
    b
      ..mode = DsThemeMode.system
      ..contrast = DsContrast.standard
      ..cornerStyle = DsCornerStyle.standard
      ..selectionStyle = DsSelectionStyle.soft
      ..autoClashRule = true
      ..motion = const DsMotion()
      ..extensions = ListBuilder<DsThemeExtension<dynamic>>();
  }

  /// The brand seed: the platform accent where the machine has one, a
  /// named tone or `DsSeed.oklch`/`DsSeed.color` expression where it does
  /// not. Null takes the API's `DsSeed.blue`.
  DsSeed? get seed;

  /// Light / dark / follow the system. Consumed by `DsApp`, which derives
  /// the dark variant from the same [seed].
  DsThemeMode get mode;

  /// Soft or standard contrast.
  DsContrast get contrast;

  /// Sharp / standard / soft / pill corners.
  DsCornerStyle get cornerStyle;

  /// Compact or touch; null follows [platform], or the device's platform
  /// when that is null too.
  DsDensity? get density;

  /// The platform the sizes and the font design assume; null takes
  /// `defaultTargetPlatform`.
  TargetPlatform? get platform;

  /// Soft or hard selection styles.
  DsSelectionStyle get selectionStyle;

  /// Whether the palette keeps selection apart from danger and success
  /// automatically. Off makes [seed] the only voice.
  bool get autoClashRule;

  /// Replaces the generated danger colour.
  Color? get dangerOverride;

  /// Replaces the generated success colour.
  Color? get successOverride;

  /// Replaces the generated warning colour.
  Color? get warningOverride;

  /// Edits the generated colours before shadows are built. Runs per
  /// brightness, so one adjuster serves the theme pair.
  DsColorsAdjuster? get adjustColors;

  /// Edits the generated shadows.
  DsShadowsAdjuster? get adjustShadows;

  /// Edits the generated radii (the corner style's output).
  DsRadiiAdjuster? get adjustRadii;

  /// Edits the generated sizes (the density's output).
  DsSizesAdjuster? get adjustSizes;

  /// The text face, used on every platform — Apple's included. Null keeps
  /// the API's design: San Francisco on iOS and macOS, the bundled
  /// Schibsted Grotesk elsewhere. Looked up in this app unless
  /// [fontPackage] says otherwise.
  String? get fontFamily;

  /// The code face; null keeps the bundled Geist Mono.
  String? get monoFontFamily;

  /// The display face for display and title roles; null keeps the text
  /// family.
  String? get displayFontFamily;

  /// The package bundling [fontFamily], or null for a font declared in
  /// this app.
  String? get fontPackage;

  /// The package bundling [monoFontFamily].
  String? get monoFontPackage;

  /// The package bundling [displayFontFamily].
  String? get displayFontPackage;

  /// Motion: springs, press scales, overlay transitions, shimmer and
  /// spinner periods.
  DsMotion get motion;

  /// Haptic feedback rules; null takes the API's default.
  DsHaptics? get haptics;

  /// Theme extensions carried through to `DsTheme` keyed by type.
  BuiltList<DsThemeExtension<dynamic>> get extensions;

  /// The theme this setting describes, every factory parameter fed from a
  /// getter of this class. `DsApp` derives the dark variant from the same
  /// expression.
  DsThemeData theme() => DsThemeData(
    seed: seed ?? DsSeed.blue,
    contrast: contrast,
    cornerStyle: cornerStyle,
    density: density,
    platform: platform,
    selectionStyle: selectionStyle,
    autoClashRule: autoClashRule,
    dangerOverride: dangerOverride,
    successOverride: successOverride,
    warningOverride: warningOverride,
    adjustColors: adjustColors,
    adjustShadows: adjustShadows,
    adjustRadii: adjustRadii,
    adjustSizes: adjustSizes,
    typography: _typography(),
    motion: motion,
    haptics: haptics,
    extensions: extensions,
  );

  /// Builds the typography override only when a font getter is set;
  /// otherwise the API's `DsTypography(density: …)` stands.
  DsTypography? _typography() {
    if (fontFamily == null &&
        monoFontFamily == null &&
        displayFontFamily == null &&
        fontPackage == null &&
        monoFontPackage == null &&
        displayFontPackage == null) {
      return null;
    }
    final density = this.density ?? DsDensity.forPlatform(platform ?? defaultTargetPlatform);
    if (monoFontFamily != null || monoFontPackage != null) {
      return DsTypography(
        family: fontFamily,
        package: fontPackage,
        monoFamily: monoFontFamily!,
        monoPackage: monoFontPackage,
        displayFamily: displayFontFamily,
        displayPackage: displayFontPackage,
        density: density,
      );
    }
    return DsTypography(
      family: fontFamily,
      package: fontPackage,
      displayFamily: displayFontFamily,
      displayPackage: displayFontPackage,
      density: density,
    );
  }

  /// The density the viewer's platform gets when none is pinned.
  static DsDensity platformDensity() => DsDensity.forPlatform(defaultTargetPlatform);
}

/// The settings and a way to change them, above the whole tree: the
/// settings surface writes through [onChanged], every page reads
/// [settings] — and because the scope is an `InheritedWidget`, a change
/// rebuilds exactly the widgets that look.
class AppThemeScope extends InheritedWidget {
  /// Exposes [settings] with [onChanged] to [child].
  const AppThemeScope({required this.settings, required this.onChanged, required super.child, super.key});

  /// The current appearance settings.
  final AppThemeSettings settings;

  /// Applies a new set; the root keeps it in state.
  final ValueChanged<AppThemeSettings> onChanged;

  /// The nearest scope.
  static AppThemeScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppThemeScope>()!;

  @override
  bool updateShouldNotify(AppThemeScope old) => old.settings != settings;
}
