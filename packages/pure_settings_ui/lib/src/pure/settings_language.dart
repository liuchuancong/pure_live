import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureDesignLanguage;

/// The settings style each pure_uikit design language resolves to.
///
/// Five of the nine languages already have a rendering upstream drew, and each
/// maps onto the device platform whose settings app that rendering follows — so
/// the tile, section, split-view and page-header switches that key on
/// [DevicePlatform] keep working untouched, and the mapping is the whole seam:
///
/// | [PureDesignLanguage] | style | look |
/// |---|---|---|
/// | `material` | [DevicePlatform.android] | Android 16 cards off the Material theme |
/// | `cupertino` | [DevicePlatform.iOS] | iOS 26 grouped cards |
/// | `fluent` | [DevicePlatform.windows] | Windows 11 Settings |
/// | `macos` | [DevicePlatform.macOS] | macOS 26 System Settings |
/// | `yaru` | [DevicePlatform.linux] | GNOME/libadwaita boxed lists |
/// | `forui`, `glass`, `neumorphic`, `wind` | [DevicePlatform.pure] | pure_uikit's own |
///
/// The last four are the reason this package exists: upstream has no rendering
/// for them, so they resolve to [DevicePlatform.pure], whose section, tile,
/// switch, sidebar and page header are built on pure_uikit's components. Those
/// components read the active language themselves and construct forui's,
/// glass_morphism_plus's, flutter_neumorphic_ui_kit's or fluttersdk_wind's real
/// widgets, so one implementation covers all four and each looks like its own
/// library — the same rule the rest of pure_uikit follows, and the reason this
/// package names no design-language library in its `pubspec.yaml`.
DevicePlatform devicePlatformOf(PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.material => DevicePlatform.android,
  PureDesignLanguage.cupertino => DevicePlatform.iOS,
  PureDesignLanguage.fluent => DevicePlatform.windows,
  PureDesignLanguage.macos => DevicePlatform.macOS,
  PureDesignLanguage.yaru => DevicePlatform.linux,
  PureDesignLanguage.forui ||
  PureDesignLanguage.glass ||
  PureDesignLanguage.neumorphic ||
  PureDesignLanguage.wind => DevicePlatform.pure,
};
