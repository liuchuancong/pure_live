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
  theme scope (never a second application widget inside the host).
- Build native Glass widgets for all fifteen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast**. `glass_morphism_plus` is a surface library — it publishes
  frosted sheets and the theme that describes them — so only four of those are a
  library widget (`GlassButton`, `GlassCard`, `GlassTextField`, `GlassListTile`);
  the other eleven are composed out of `GlassContainer` and the `GlassTheme`
  values it reads (blur, tint, corner radius, stroke, shadow), and each builder
  says which (§9).
- Declare the whole contract in `glassCapabilities`: a Glass page reports no
  `controlUnsupported` downgrade, and nothing inside a Glass frame is a token
  renderer (§16/§17).
- Own the app host: the library ships no application widget, so the host is
  Flutter's `WidgetsApp` with `GlassTheme` above the routed tree — which is what
  takes the page transition, the scroll physics and a dialog's modal barrier out
  of Material's hands (§ surfaces). The shell still resolves shared and is
  reported: the library's only structural widget is `GlassAppBar`, a Material
  `AppBar` under a frosted `flexibleSpace`, so nothing of this package's wraps a
  router-owned body yet.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract is built here. What the library has no widget for
is composed from its own frosted surfaces rather than falling back to the core
shared token renderer, so a Glass page contains no token-shaped control at all.

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
The host does need them installed: with no Material application widget above it,
the strings the composed controls and the library's own field ask for arrive
through `liveLocalizationsDelegates` and nothing else.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `glass_morphism_plus` ^0.1.0 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_glass
```

`test/adapter/glass_contract_test.dart` verifies the stable id/display name, that
the declared capabilities are the whole contract, and that every control resolves
native through the core resolver with no downgrade while an unregistered language
still resolves shared and says so (§16/§17).

## Known limitations

- Four controls are the library's own widgets; the other eleven are composed from
  its `GlassContainer` surface and `GlassTheme` values, because
  `glass_morphism_plus` ships no switch, box, rail, track, bar, field menu, strip,
  frame, header, destination bar or message.
- The composed controls route their tap, hover, press and focus through the core's
  `LiveBox` rather than through `GlassContainer.onTap`, because the library's ink
  host builds a Material widget with a focus node of its own that the spec's
  `focusNode` could not reach; `GlassListTile` and `GlassButton` expose no focus
  slot either (§15).
- A Glass `select` opens its option list in flow, under the field, since the
  contract wants a widget that renders where it is placed and an overlay-anchored
  popup is not one (§9).
- Glassmorphism blur/backdrop effects must degrade gracefully where the platform
  cannot afford them; they are never a required dependency (§13).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path and
  the app host pumped with no Material app above it), and
  `test/integration/` (resolution surface across the contract and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- `errorText` has no slot in `glass_morphism_plus`, so it is drawn as a caption
  under the field rather than as a border state, and `selected`/`bordered` have no
  frosted equivalent (§9).
