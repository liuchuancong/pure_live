import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/settings_language.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureTheme;

/// The style of a `SettingsList`, named after the platform whose settings
/// app it follows.
///
/// [device] (auto-detect) is only valid as the `platform` of a `SettingsList`
/// or `SettingsSplitView`.
enum DevicePlatform {
  /// Android: <https://www.android.com/>
  android,

  /// Fuchsia: <https://fuchsia.dev/fuchsia-src/concepts>
  fuchsia,

  /// iOS: <https://www.apple.com/ios/>
  iOS,

  /// Linux: <https://www.linux.org>
  linux,

  /// macOS: <https://www.apple.com/macos>
  macOS,

  /// Windows: <https://www.windows.com>
  windows,

  /// Web
  web,

  /// pure_uikit's own style, and the one addition this fork makes to the enum.
  ///
  /// Not a device platform: it is what the four [PureDesignLanguage]s upstream
  /// has no rendering for (`forui`, `glass`, `neumorphic`, `wind`) resolve to,
  /// and its widgets are built on pure_uikit's components, so which library
  /// actually draws them is decided one level down by the active language. Pass
  /// it as `platform` to force that style under any language.
  pure,

  /// Use this to specify you want to use the default device platform
  device,
}

/// Detects the style of a `SettingsList` whose platform is not set.
class PlatformUtils {
  /// Returns the style the app's resolved [PureDesignLanguage] maps to, which
  /// is what makes a settings screen re-skin with the rest of the app instead
  /// of with the device it happens to run on.
  ///
  /// Outside a `PureConfigProvider` it degrades to upstream's behaviour —
  /// [DevicePlatform.web] in a browser, otherwise the style for
  /// `Theme.of(context).platform` — so the package still renders in a plain
  /// `MaterialApp`. Platforms that only exist in forks of Flutter (such as
  /// OpenHarmony) get [DevicePlatform.iOS].
  static DevicePlatform detectPlatform(BuildContext context) {
    final language = PureTheme.maybeOf(context)?.config.language;
    if (language != null) return devicePlatformOf(language);

    if (kIsWeb) return DevicePlatform.web;

    // `Theme.of` synthesizes a fallback rather than asserting when no Material
    // theme is installed, which is the case under four of pure_uikit's hosts —
    // they are a plain WidgetsApp carrying their own library's theme — so this
    // degrades to the device platform instead of throwing.
    final platform = Theme.of(context).platform;

    switch (platform) {
      case TargetPlatform.android:
        return DevicePlatform.android;
      case TargetPlatform.fuchsia:
        return DevicePlatform.fuchsia;
      case TargetPlatform.iOS:
        return DevicePlatform.iOS;
      case TargetPlatform.linux:
        return DevicePlatform.linux;
      case TargetPlatform.macOS:
        return DevicePlatform.macOS;
      case TargetPlatform.windows:
        return DevicePlatform.windows;
      // Forks of Flutter can add platforms, e.g. TargetPlatform.ohos on
      // OpenHarmony, which would not compile without a default (#205). A null
      // means there was no Material theme to ask, which is the same case.
      // ignore: unreachable_switch_default
      default:
        return DevicePlatform.iOS;
    }
  }
}
