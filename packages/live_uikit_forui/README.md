# live_uikit_forui

The ForUI design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `forui` widgets
(`FButton`, `FCard`, `FTextField`, `FSwitch`, `FCheckbox`) and installs the forui
theme variant the resolved design token can decide.

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
- Build native forui widgets for: **button, card, text field, switch, checkbox**.
- Declare exactly those controls in `foruiCapabilities` so the core resolver can
  report a `controlUnsupported` downgrade for the rest (§16/§17).
- Expose `foruiLocalizationsDelegates` for the composition root to install.

## What this package must not own

- Global theme preferences or their persistence, and the style-selector UI.
- Shared design-token definitions or global configuration storage.
- Any state management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters, or on `forui` leaking into
  business packages.

Controls not built here (slider, segmented, progress, select, tab bar) fall back
to the core shared token renderer — they still render on-theme, they are simply
not forui-native. `forui` does ship widgets for most of them, so these are
promotion candidates, not library gaps (spec §18).

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
