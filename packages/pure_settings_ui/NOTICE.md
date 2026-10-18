# Notices

## Vendored code

`packages/pure_settings_ui/lib/src/vendor/` is a copy of **settings_ui 4.0.2**,
published on [pub.dev](https://pub.dev/packages/settings_ui) from the repository
[github.com/yako-dev/flutter-settings-ui](https://github.com/yako-dev/flutter-settings-ui).

It is used under the **Apache License, Version 2.0**, whose full text is kept
unaltered in [`LICENSE`](LICENSE) alongside this file.

The upstream `LICENSE` carries the Apache boilerplate's unfilled copyright line
(`Copyright [yyyy] [name of copyright owner]`) and names no holder, so
attribution here is to the project the package's own `pubspec.yaml` points at:
the **flutter-settings-ui** authors, `yako-dev`.

## Modifications

Section 4(b) of the licence requires stating changes. This is that statement.
The vendored tree was copied in full and then modified as follows; everything
not listed is upstream's, token for token.

**Two things to know before diffing this against upstream.** First, the whole
tree was passed through this workspace's formatter (`dart format`, page width
120), which reflowed 48 of the 62 files — line wraps and trailing commas only.
The diff against upstream is therefore structural, same files in the same
directories with the same code, rather than byte for byte. Second, **nine**
files carry real code edits, and they are exactly the ones listed under "Style
dispatch" below; the mechanical rewrites under "Imports" and "Declarations"
touch more files but change no behaviour.

**Layout**

- The whole of upstream's `lib/` moved to `lib/src/vendor/`, keeping its internal
  directory structure (`list/`, `sections/`, `split/`, `tiles/`, `utils/`).
- The barrel `lib/settings_ui.dart` became `lib/pure_settings_ui.dart`, and
  exports the theme registry added by this fork.

**Imports (mechanical)**

- `package:material_ui/material_ui.dart` → `package:flutter/material.dart` —
  20 sites.
- `package:cupertino_ui/cupertino_ui.dart` → `package:flutter/cupertino.dart` —
  14 sites. `material_ui` and `cupertino_ui` are the extracted copies of the SDK's
  own libraries; every name this package uses from them also exists in
  `flutter/material` and `flutter/cupertino`, so the re-pointing compiles
  unchanged. It is necessary rather than cosmetic: `pure_uikit` builds on the SDK
  libraries, and a `Theme` from the fork is a *different type* from a `Theme` in
  the tree, so vendored code reading the fork would find no theme and silently
  use default colours.
- `package:settings_ui/src/...` → `package:pure_settings_ui/src/...` — 260 sites.

**Declarations**

- Five public callback fields retyped from bare `Function(...)` to
  `void Function(...)`: `SettingsTile.onPressed`, `SettingsTile.onToggle` and its
  `_effectiveOnPressed` getter, and `SettingsTileData.onPressed` / `.onToggle`.
  `analysis_options.yaml` in this workspace requires declared return types.

**Style dispatch — the reason for the fork**

The nine files carrying real code edits are:
`utils/platform_utils.dart`, `utils/settings_style.dart`, `utils/theme_provider.dart`,
`list/settings_list.dart`, `sections/settings_section.dart`, `tiles/settings_tile.dart`,
`split/split_pane_style.dart`, `split/settings_page_header.dart` and
`split/split_geometry.dart`.

- `DevicePlatform.pure` added to the enum (`utils/platform_utils.dart`).
- `SettingsStyleFamily.pure` added to the family enum, with
  `settingsStyleFamily` and `settingsUsesCupertinoRoutes` covering it
  (`utils/settings_style.dart`).
- `PlatformUtils.detectPlatform` now resolves the style from pure_uikit's
  `PureTheme.of(context).config.language` and falls back to upstream's device
  detection only when there is no `PureConfigProvider` above the list.
- `SettingsStyleConfig.resolveBrightness` prefers the resolved `PureTheme`
  brightness, because four of `pure_uikit`'s hosts are a plain `WidgetsApp` that
  installs no Material or Cupertino theme for the brightness to come from.
- `SettingsList._debugWarnIfMissingTheme` warns about a missing `PureTheme`
  instead of a missing `material_ui`/`cupertino_ui` theme.
- Eleven exhaustive switches gained a `pure` case:
  `SettingsList._fillsDetailPane`, `SettingsList.calculateDefaultPadding`,
  `SettingsSection.build` (sidebar and card), `SettingsTile.build` (sidebar row
  and card row), `SplitPaneStyle.of`, `SettingsPageHeader`/`SettingsPageBar.build`,
  `defaultShowsTwoPanes` and `defaultListPaneWidth` in `split_geometry.dart`, and
  `ThemeProvider.getTheme`.
- `import 'package:flutter/cupertino.dart';` dropped from
  `list/settings_list.dart`; the widget that needed it was the theme check above.

**Added, outside the vendored tree**

- `lib/src/pure/` — this package's own code: the theme registry
  (`settings_language.dart`), the style contract (`pure_settings_style.dart`), the
  token palette (`pure_settings_palette.dart`), the shared page metrics
  (`pure_settings_metrics.dart`), the pure rendering (`pure_settings_section.dart`,
  `pure_settings_tile.dart`, `pure_page_bar.dart`, `pure_split.dart`,
  `pure_text_slot.dart`) and **one file per design language** in
  `lib/src/pure/languages/`.
- `lib/src/vendor/analysis_options.yaml`, which relaxes formatting and
  documentation lints for the vendored tree only. Every correctness lint stays
  on.

## Not used

Upstream's `example/`, `test/`, `assets/`, `doc/`, `README.md`, `CHANGELOG.md`,
`llms.txt` and `.pubignore` were not copied — only `lib/` and `LICENSE`.
