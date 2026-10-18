import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// Yaru's settings theme.
///
/// Its rendering is upstream's GNOME/libadwaita style: one card per section with
/// 12px corners and a soft shadow, 54px rows separated full-width, bold 14.67px
/// group titles, `AdwaitaSettingsSwitch`, the `go-next` arrow on a navigation
/// tile, and a 600px column that narrows like `AdwClamp`. Ubuntu's Settings is
/// a libadwaita application, so this is the rendering that fits it — not the
/// Material one, even though Yaru's *controls* are Material.
///
/// Forced to the pure rendering, Yaru draws with the Material widgets — that is
/// what Yaru is; its character comes from the host theme, `createYaruLightTheme`
/// seeded from the app's accent, not from a different row. So it separates like
/// Material and lets the row state its own selection.
const yaruSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.linux,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: true,
  ),
);
