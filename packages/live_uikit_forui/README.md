# live_uikit_forui

The ForUI design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders every control specification the core dispatches with `forui` widgets
(`FButton`, `FCard`, `FTextField`, `FSwitch`, `FCheckbox`, `FSlider`, `FProgress`,
`FSelect`, `FTabs`, `FScaffold`, `FHeader`, `FTile`, `FBottomNavigationBar`, `FToast`)
and installs the forui theme variant the resolved design token can decide.

See `live-uikit-forui.md` in this directory for the full architecture and
integration specification.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **ForUI**
implementation of that contract so an application can select `forui` at runtime
and have its controls drawn by `forui`, without any business page importing
`forui` directly.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.forui` (stable id `forui`).
- Map the resolved `DesignToken` into forui's `FThemeData` and install it through an
  `FTheme` scope (never a nested application shell). The library's private
  `FThemeData` constructor caps the mapping at the light/dark neutral variant (§8.1);
  the ceiling is pinned by test rather than faked.
- Build native ForUI widgets for all fifteen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast**. One of them is composed out of ForUI's own parts rather than
  mapped one-for-one — `segmented` is a row of ghost `FButton`s taking
  `FButton.selected`, because the library's only single-choice row is `FTabs`, which is
  a tab *view* and is spent on the tab bar — and `tab bar` is `FTabs` itself with an
  empty content panel per entry, since that widget always paints a body area while this
  contract's body belongs to the caller (§9).
- Declare the whole contract in `foruiCapabilities`: a ForUI page reports no
  `controlUnsupported` downgrade, and nothing inside a ForUI frame is a token
  renderer (§16/§17). The structural surfaces (app host, app shell) are not this
  package's yet, so those two still resolve shared and are reported.
- Expose `foruiLocalizationsDelegates` for the composition root to install.

## What this package must not own

- Global theme preferences or their persistence, and the style-selector UI.
- Shared design-token definitions or global configuration storage.
- Any state management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters, or on `forui` leaking into
  business packages.

Nothing in the fifteen-control contract falls back to the core shared token renderer
any more. What is left is narrower and documented per builder: a few spec fields the
library has no slot for (`LanguageProgressSpec.showLabel`, `LanguageSliderSpec.focusNode`,
`LanguageTabsSpec.spacing`), the two structural surfaces this package does not own, and
the theme ceiling described above (spec §18).

## Public entry point

`package:live_uikit_forui/live_uikit_forui.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

PureLive uses a single Pub workspace; this package is already a workspace member.
Business packages depend only on `live_uikit`. The **application composition root**
registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.forui: foruiAdapter},
  fallback: SharedLanguageAdapter(),
);

// In the app shell, append forui's delegate to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...foruiLocalizationsDelegates,
//     ],
//   )
```

Selecting the style at runtime is `UiConfig.language = LiveDesignLanguage.forui`;
a `LiveButton` then draws through this adapter with no change to the page.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `forui` ^0.27.5 (the native forui widgets and theme)
- Flutter SDK

## Testing

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_forui
flutter analyze packages/live_uikit_forui
flutter test packages/live_uikit_forui
```

Run from the workspace root; `tool/check_architecture.ps1` additionally asserts the
library boundary, the `as forui` import prefix, the registration-only barrel, and the
README/capability match.
