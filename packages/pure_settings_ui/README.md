# pure_settings_ui

PureLive's settings screens: the `settings_ui` API, vendored and re-keyed so one
declarative settings tree renders in every design language the app can switch to.

## Purpose

The app has nine switchable design languages and had eleven hand-built settings
pages, each laying out its own group titles and rows. `settings_ui` already solves
that layout — sections, tiles, switches, sub-pages, a split view for tablets and
desktop — but it picks its rendering from the **device platform**, and this app's
look is chosen by the **user's `UiConfig.language`**, independently of what it runs
on. A settings screen keyed to the OS would not re-skin with the rest of the app.

So the package is `settings_ui` 4.0.2 with that one decision reversed. Leave
`platform` unset and the style comes from the `PureConfigProvider` above the list:

| language | rendering | source |
|---|---|---|
| `material` | Android 16 cards | upstream |
| `cupertino` | iOS 26 grouped cards | upstream |
| `fluent` | Windows 11 Settings | upstream |
| `macos` | macOS 26 System Settings | upstream |
| `yaru` | GNOME/libadwaita boxed lists | upstream |
| `forui` | forui's `FCard` + `FTile` | this package |
| `glass` | `GlassCard` + `GlassListTile` | this package |
| `neumorphic` | embossed `NeuCard` rows | this package |
| `wind` | token-stroked `WCard` rows | this package |

The five upstream renderings are kept as they ship: they are pixel studies of real
Settings apps, and this package has no better version of them. The last four have
no upstream rendering at all, which is why this package exists.

## Responsibilities

- **The vendored grammar.** `SettingsList`, `SettingsSection`, `SettingsTile`
  (`.navigation`, `.switchTile`), `CustomSettingsTile`, `CustomSettingsSection`,
  `SettingsDestination` and `SettingsSplitView`, under `lib/src/vendor/` at
  upstream's own directory layout. `NOTICE.md` states every change.
- **The theme registry.** `lib/src/pure/settings_language.dart` maps each
  `PureDesignLanguage` onto a `DevicePlatform` style key and a
  `PureSettingsStyle`. It is a lookup of nine entries, one per theme — never a
  `switch` that several themes share a branch in.
- **One file per theme.** `lib/src/pure/languages/<language>_settings_language.dart`
  holds that theme's constant: which style key it draws and which palette, card
  padding, border and separator behaviour it states for itself. Mirrors
  `pure_uikit`'s `app/hosts/`, one host per language.
- **The pure rendering.** `PureSettingsSection`, `PureSettingsTile`, `PurePageBar`
  and `PurePaneStyle` — shared code built on `pure_uikit`'s `PureCard`,
  `PureListRow`, `PureSwitch` and `PureAppBar`, which already construct the active
  library's real widgets. `lib/src/pure/README` note: the parts that genuinely
  differ per theme are in the theme files; duplicating the row nine times would be
  nine files re-deciding what the library already decided.

## What this package must not own

- Any design-language library. Its `pubspec.yaml` names `flutter` and `pure_uikit`
  and nothing else; the per-language widget construction is `pure_uikit`'s job.
- Preferences, persistence, and which settings exist — the app owns those. This
  package draws a tree it is handed.
- Routing. `SettingsDestination` pushes inside the settings screen; anything
  beyond it belongs to the app's router.

## Public entry points

`package:pure_settings_ui/pure_settings_ui.dart` is the only public barrel.
Nothing under `src/` is meant for outside import; `lib/src/pure/` is reached by
`lib/src/vendor/`'s dispatch switches, which is the seam this fork adds and the
list in `NOTICE.md` tracks.

## Installation and usage

A Pub-workspace member (`resolution: workspace`).

```yaml
dependencies:
  pure_settings_ui:
```

```dart
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';

SettingsList(
  sections: [
    SettingsSection(
      title: const Text('General'),
      tiles: [
        SettingsTile.switchTile(
          leading: const Icon(Icons.refresh_outlined),
          title: const Text('Refresh on resume'),
          initialValue: preferences.refreshOnResume,
          onToggle: (value) => update((p) => p.copyWith(refreshOnResume: value)),
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Appearance'),
          value: Text(currentThemeName),
          destination: SettingsDestination(
            id: 'appearance',
            builder: (context) => const AppearanceSettingsBody(),
          ),
        ),
      ],
    ),
  ],
)
```

It must sit below a `PureConfigProvider` (`PureApp` provides one). Without it the
package still renders, but falls back to detecting the device platform and prints
one debug warning naming the missing theme.

For the full API — `SettingsThemeData` overrides, `SettingsSplitController`,
`applicationType`, padding and per-tile paddings — upstream's
[`llms.txt`](https://raw.githubusercontent.com/yako-dev/flutter-settings-ui/master/llms.txt)
and [README](https://pub.dev/packages/settings_ui) apply unchanged, with
`DevicePlatform.pure` and the language mapping as the only differences.

## Dependencies

Flutter SDK (`widgets`, `material` and `cupertino` — the SDK libraries, not the
extracted `material_ui`/`cupertino_ui` forks) and `pure_uikit`. Nothing else;
notably no design-language library, which is what makes it safe to depend on
`pure_uikit` under this repository's style-library boundary.

## Testing

None yet. The package is analysed clean under the workspace's rule set; a
behaviour test still has to be written, and the interesting case is that
`flutter test` reports an Android platform, so a test must assert that a
`forui` app on an Android test platform draws forui's switch and not Windows' or
Android's — which is the whole claim this package makes.

## Known limitations

- `SettingsTile`'s slots are widgets and `PureListRow`'s title is a string, so the
  pure rendering reads a `Text` slot's data and falls back to a `PureBox`-composed
  row for anything richer. The fallback is plainer than the library's real row: no
  `FTile` hover fill, no frosted sheet. Prefer `Text`.
- `forui` exposes no way for a host to recolour its theme (`FThemeData` has a
  private constructor), so under `forui` the card and rows keep forui's greys while
  the page background follows the app's accent. `pure_uikit` documents the same
  asymmetry for its own components.
- The `web` style is reachable only by forcing `platform: DevicePlatform.web`;
  `PureDesignLanguage` has no web member. The app ships no web target today.
- The five upstream renderings are verified under a Material host, as upstream's
  own testing prescribes — not under `pure_uikit`'s real `FluentApp` / `MacosApp` /
  `CupertinoApp` hosts. A missing-ancestor crash in those combinations would not
  be caught until the app runs.
