import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/list/settings_list.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/theme_provider.dart';
import 'package:pure_settings_ui/src/vendor/utils/unresolved_platform.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureTheme;

/// The style inputs of a [SettingsList] or `SettingsSplitView`: platform,
/// brightness override, themes and application type. Internal.
@immutable
class SettingsStyleConfig {
  const SettingsStyleConfig({
    this.platform,
    this.brightness,
    this.lightTheme,
    this.darkTheme,
    this.applicationType = ApplicationType.material,
  });

  /// Null or [DevicePlatform.device] means "detect".
  final DevicePlatform? platform;
  final Brightness? brightness;
  final SettingsThemeData? lightTheme;
  final SettingsThemeData? darkTheme;
  final ApplicationType applicationType;

  bool get _detectsPlatform =>
      platform == null || platform == DevicePlatform.device;

  /// Fills what this config leaves unset from [parent]: a list in a page
  /// opened from another list looks like the list that opened it.
  ///
  /// [ApplicationType.material] is the default, so it counts as unset.
  SettingsStyleConfig inheritFrom(SettingsStyleConfig? parent) {
    if (parent == null) return this;
    return SettingsStyleConfig(
      platform: _detectsPlatform ? parent.platform : platform,
      brightness: brightness ?? parent.brightness,
      lightTheme: lightTheme ?? parent.lightTheme,
      darkTheme: darkTheme ?? parent.darkTheme,
      applicationType: applicationType == ApplicationType.material
          ? parent.applicationType
          : applicationType,
    );
  }

  DevicePlatform resolvePlatform(BuildContext context) =>
      _detectsPlatform ? PlatformUtils.detectPlatform(context) : platform!;

  Brightness resolveBrightness(BuildContext context) {
    final brightness = this.brightness;
    if (brightness != null) return brightness;

    // The resolved design token is the authority: it has already folded the
    // user's brightness preference and the platform's into one answer, and it
    // exists under all nine of pure_uikit's hosts — four of which are a plain
    // WidgetsApp with no Material or Cupertino theme above them at all.
    final pureBrightness = PureTheme.maybeOf(context)?.isDark;
    if (pureBrightness != null) {
      return pureBrightness ? Brightness.dark : Brightness.light;
    }

    final materialBrightness = Theme.of(context).brightness;
    final cupertinoBrightness =
        CupertinoTheme.maybeBrightnessOf(context) ??
        MediaQuery.platformBrightnessOf(context);

    switch (applicationType) {
      case ApplicationType.material:
        return materialBrightness;
      case ApplicationType.cupertino:
        return cupertinoBrightness;
      case ApplicationType.both:
        // Decide by the platform the app runs on, which picks the app widget,
        // not by the tile style set in [platform]. Inside a MaterialApp the
        // CupertinoTheme follows the Material theme, so the Cupertino
        // brightness is also right for a MaterialApp on iOS or macOS.
        final hostPlatform = PlatformUtils.detectPlatform(context);
        return hostPlatform == DevicePlatform.iOS ||
                hostPlatform == DevicePlatform.macOS
            ? cupertinoBrightness
            : materialBrightness;
    }
  }

  ResolvedSettingsStyle resolve(BuildContext context) {
    final platform = resolvePlatform(context);
    final brightness = resolveBrightness(context);
    final themeData = ThemeProvider.getTheme(
      context: context,
      platform: platform,
      brightness: brightness,
    ).merge(theme: brightness == Brightness.dark ? darkTheme : lightTheme);
    return ResolvedSettingsStyle(
      config: this,
      platform: platform,
      brightness: brightness,
      themeData: themeData,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsStyleConfig &&
      other.platform == platform &&
      other.brightness == brightness &&
      other.lightTheme == lightTheme &&
      other.darkTheme == darkTheme &&
      other.applicationType == applicationType;

  @override
  int get hashCode =>
      Object.hash(platform, brightness, lightTheme, darkTheme, applicationType);
}

/// A [SettingsStyleConfig] resolved against a [BuildContext].
@immutable
class ResolvedSettingsStyle {
  const ResolvedSettingsStyle({
    required this.config,
    required this.platform,
    required this.brightness,
    required this.themeData,
  });

  final SettingsStyleConfig config;

  /// Never [DevicePlatform.device].
  final DevicePlatform platform;
  final Brightness brightness;
  final SettingsThemeData themeData;

  /// [config] with the detected platform filled in, for pages that this
  /// screen opens.
  SettingsStyleConfig get resolvedConfig => SettingsStyleConfig(
    platform: platform,
    brightness: config.brightness,
    lightTheme: config.lightTheme,
    darkTheme: config.darkTheme,
    applicationType: config.applicationType,
  );
}

/// Which split view and page header look a [DevicePlatform] uses: iPad
/// Settings (iOS), Android Settings (Android, Fuchsia), Chrome's settings
/// page (web), macOS System Settings, Windows 11 Settings, GNOME Settings, or
/// pure_uikit's own. Tiles and sections dispatch on the [DevicePlatform]
/// itself.
enum SettingsStyleFamily {
  cupertino,
  material,
  web,
  macos,
  fluent,
  adwaita,
  pure,
}

SettingsStyleFamily settingsStyleFamily(DevicePlatform platform) {
  switch (platform) {
    case DevicePlatform.iOS:
      return SettingsStyleFamily.cupertino;
    case DevicePlatform.macOS:
      return SettingsStyleFamily.macos;
    case DevicePlatform.windows:
      return SettingsStyleFamily.fluent;
    case DevicePlatform.android:
    case DevicePlatform.fuchsia:
      return SettingsStyleFamily.material;
    case DevicePlatform.linux:
      return SettingsStyleFamily.adwaita;
    case DevicePlatform.web:
      return SettingsStyleFamily.web;
    case DevicePlatform.pure:
      return SettingsStyleFamily.pure;
    case DevicePlatform.device:
      throwUnresolvedPlatform('settingsStyleFamily');
  }
}

/// Whether pages of a style slide in over the page below, like iOS pages
/// (iOS, macOS, and GNOME's `AdwNavigationView`, which pushes pages the
/// same way). The other styles use the app's Material page transitions.
bool settingsUsesCupertinoRoutes(SettingsStyleFamily family) {
  switch (family) {
    case SettingsStyleFamily.cupertino:
    case SettingsStyleFamily.macos:
    case SettingsStyleFamily.adwaita:
      return true;
    case SettingsStyleFamily.material:
    case SettingsStyleFamily.web:
    case SettingsStyleFamily.fluent:
    // pure_uikit's four languages are hosted by a plain WidgetsApp, so there
    // is no library transition to borrow; Material's is the neutral one, and
    // the localization delegates pure_uikit ships make it safe to build.
    case SettingsStyleFamily.pure:
      return false;
  }
}

/// Puts a [SettingsStyleConfig] in the tree. Internal.
///
/// Every [SettingsList] puts its own config here (with [inherit] false) so
/// its tiles can hand it to the pages they open. Those pages put it back
/// with [inherit] true, and a [SettingsList] in the page fills its unset
/// style inputs from it.
class SettingsStyleScope extends InheritedWidget {
  const SettingsStyleScope({
    super.key,
    required this.config,
    this.inherit = false,
    required super.child,
  });

  final SettingsStyleConfig config;

  /// Whether a [SettingsList] below takes its unset style inputs from
  /// [config]. False for a list's own scope, so nested lists keep
  /// detecting their style as before.
  final bool inherit;

  static SettingsStyleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsStyleScope>();

  /// The brightness of the [SettingsList] (or split view) around [context]:
  /// its forced `brightness`, or the app theme's as its `applicationType`
  /// picks. Null outside of one.
  static Brightness? brightnessOf(BuildContext context) =>
      maybeOf(context)?.config.resolveBrightness(context);

  /// The config a [SettingsList] at [context] should inherit, if any.
  static SettingsStyleConfig? inheritedConfigOf(BuildContext context) {
    final scope = maybeOf(context);
    return scope != null && scope.inherit ? scope.config : null;
  }

  @override
  bool updateShouldNotify(SettingsStyleScope oldWidget) =>
      config != oldWidget.config || inherit != oldWidget.inherit;
}
