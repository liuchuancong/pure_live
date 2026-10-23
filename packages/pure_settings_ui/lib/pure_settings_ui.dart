/// Settings screens that follow the app's design language rather than the
/// device's.
///
/// This is [settings_ui](https://pub.dev/packages/settings_ui) 4.0.2 — the
/// same `SettingsList` / `SettingsSection` / `SettingsTile` /
/// `SettingsDestination` / `SettingsSplitView` API, vendored under Apache-2.0
/// (see `LICENSE` and `NOTICE.md`) — with its style dispatch re-keyed from
/// `DevicePlatform` onto pure_uikit's `PureDesignLanguage`. One declarative
/// settings tree therefore re-skins with the rest of the app:
///
/// | language | style |
/// |---|---|
/// | `fluent` | Windows 11 Settings |
///
/// That one is upstream's rendering, kept as it ships. The package also
/// carries `DevicePlatform.pure`, its own addition: built on pure_uikit's
/// components, so a language that names it draws pure_uikit's real card, row
/// and switch.
///
/// ```dart
/// SettingsList(
///   sections: [
///     SettingsSection(
///       title: const Text('General'),
///       tiles: [
///         SettingsTile.switchTile(
///           leading: const Icon(Icons.refresh_outlined),
///           title: const Text('Refresh on resume'),
///           initialValue: refreshOnResume,
///           onToggle: (value) => update(value),
///         ),
///         SettingsTile.navigation(
///           leading: const Icon(Icons.palette_outlined),
///           title: const Text('Appearance'),
///           value: Text(currentThemeName),
///           destination: SettingsDestination(
///             id: 'appearance',
///             builder: (context) => const AppearanceSettings(),
///           ),
///         ),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// Leave `platform` unset: the style comes from the `PureConfigProvider` above
/// the list. Set it to force one style, which is what the tests do.
library;

export 'src/nav/settings_nav_pane.dart';
export 'src/pure/settings_language.dart' show devicePlatformOf;
export 'src/vendor/list/settings_list.dart';
export 'src/vendor/sections/abstract_settings_section.dart';
export 'src/vendor/sections/custom_settings_section.dart';
export 'src/vendor/sections/settings_section.dart';
export 'src/vendor/split/settings_destination.dart';
export 'src/vendor/split/settings_split_view.dart' show SettingsSplitController, SettingsSplitLayout, SettingsSplitView;
export 'src/vendor/tiles/abstract_settings_tile.dart';
export 'src/vendor/tiles/custom_settings_tile.dart';
export 'src/vendor/tiles/platforms/adwaita_settings_switch.dart';
export 'src/vendor/tiles/platforms/adwaita_symbolic_icons.dart' show AdwaitaPanDownIcon;
export 'src/vendor/tiles/platforms/cupertino_settings_switch.dart';
export 'src/vendor/tiles/platforms/fluent_settings_switch.dart';
export 'src/vendor/tiles/platforms/macos_settings_switch.dart';
export 'src/vendor/tiles/settings_tile.dart';
export 'src/vendor/utils/platform_utils.dart';
export 'src/vendor/utils/settings_theme.dart';
