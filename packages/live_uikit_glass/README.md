# live_uikit_glass

The Glass (glassmorphism) design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`glass_morphism_plus` widgets and maps the resolved design token into that
library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Glass**
implementation so an application can select `glass` at runtime and have its
controls drawn by `glass_morphism_plus`, without business pages importing it.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.glass` (stable id `glass`).
- Map the resolved `DesignToken` into the Glass theme and install it through a
  theme scope (never a nested application shell).
- Build native Glass widgets for: **button, card, text field**.
- Declare exactly those controls in `glassCapabilities` so the core resolver
  reports a `controlUnsupported` downgrade for the rest (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (switch, checkbox, slider, segmented, progress, select,
tab bar) fall back to the core shared token renderer — they still render
on-theme.

## Public entry point

`package:live_uikit_glass/live_uikit_glass.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.glass: glassAdapter},
  fallback: SharedLanguageAdapter(),
);
```

The library reuses the core's localization, so this package adds no delegates.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `glass_morphism_plus` ^0.1.0 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_glass
```

`test/adapter/glass_contract_test.dart` verifies the stable id/display name,
that the declared capabilities match the controls the adapter overrides, and the
core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Only button, card and text field are native; every other control uses the shared
  renderer.
- Glassmorphism blur/backdrop effects must degrade gracefully where the platform
  cannot afford them; they are never a required dependency (§13).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path), and
  `test/integration/` (resolution surface across the contract and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- `errorText` has no slot in `glass_morphism_plus`, so it is drawn as a caption
  under the field rather than as a border state, and `selected`/`bordered` have no
  frosted equivalent (§9).
