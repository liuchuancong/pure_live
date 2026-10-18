# Changelog

All notable changes to `pure_settings_ui` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

The vendored tree's own history is upstream's; see
[`NOTICE.md`](NOTICE.md) for what this fork changed in it, and
[settings_ui's CHANGELOG](https://pub.dev/packages/settings_ui/changelog) for
upstream's.

## Unreleased

### Added

- The package, as a workspace member. It vendors `settings_ui` 4.0.2 under
  Apache-2.0 at `lib/src/vendor/`, in upstream's own files and directories. Nine of
  those files carry this fork's dispatch edits, all listed in `NOTICE.md`.
- A style dispatch keyed on `PureDesignLanguage` instead of the device platform.
  `PlatformUtils.detectPlatform` resolves from `PureTheme.of(context).config.language`
  and falls back to upstream's device detection only outside a `PureConfigProvider`,
  so a settings screen re-skins with the rest of the app.
- `DevicePlatform.pure` and `SettingsStyleFamily.pure`, and the eleven exhaustive
  switches that had to cover them — `SettingsList`'s detail-pane and padding
  choices, `SettingsSection`'s and `SettingsTile`'s sidebar and card branches,
  `SplitPaneStyle.of`, `SettingsPageBar.build`, the two `split_geometry` defaults,
  and `ThemeProvider.getTheme`.
- One theme per design language under `lib/src/pure/languages/`, mirroring
  `pure_uikit`'s `app/hosts/`. Each file holds that theme's `SettingsLanguage`
  constant and states its own palette, card padding, border and separator
  behaviour; `settings_language.dart` is a nine-entry lookup, not a switch several
  themes share a branch in.
- The pure rendering: `PureSettingsSection` over `PureCard`, `PureSettingsTile`
  over `PureListRow` and `PureSwitch`, `PurePageBar` over `PureAppBar`, and
  `PurePaneStyle` for the split view's list pane. One implementation covers forui,
  glass, neumorphic and wind because those components already construct each
  library's real widgets, which is also why this package names no design-language
  library in its `pubspec.yaml`.
- `pureSettingsPalette`, reading the resolved design token onto the settings
  vocabulary — the pure style follows the user's accent and brightness, which no
  upstream style does except Android's and Chrome's.
- `SettingsStyleConfig.resolveBrightness` prefers the resolved `PureTheme`, because
  four of `pure_uikit`'s hosts are a plain `WidgetsApp` carrying their own
  library's theme and installing no Material or Cupertino theme for a brightness to
  be read from.
- `lib/src/vendor/analysis_options.yaml`, relaxing formatting and documentation
  lints for the vendored tree so it stays reviewable against upstream instead of
  rewritten into this workspace's house style. Every correctness lint remains on,
  in both trees.
- `LICENSE` (upstream's, unaltered) and `NOTICE.md`, which states every
  modification this fork makes as section 4(b) of the licence requires.

### Changed

- Upstream's `material_ui` and `cupertino_ui` imports re-pointed at
  `package:flutter/material.dart` and `package:flutter/cupertino.dart` — 34 sites.
  Necessary rather than cosmetic: a `Theme` from the extracted fork is a different
  type from the SDK's, and the app is built on the SDK's, so the fork's lookups
  would find no theme and silently fall back to default colours.
- Five public callback fields typed as `void Function(...)` rather than bare
  `Function(...)`.

### Not yet done

- No behaviour tests. See the README's Testing section for the assertion worth
  writing first.
- The app's eleven settings pages under `apps/pure_live/lib/features/settings/`
  still use its own hand-built `SettingsSection`/`SettingsEntryTile` helpers. They
  are the migration this package exists to receive, and nothing in the app imports
  it yet.
