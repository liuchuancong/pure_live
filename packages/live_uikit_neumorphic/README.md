# live_uikit_neumorphic

The Neumorphic design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`flutter_neumorphic_ui_kit` widgets and maps the resolved design token into that
library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Neumorphic**
implementation so an application can select `neumorphic` at runtime and have its
controls drawn by `flutter_neumorphic_ui_kit`, without business pages importing
that package.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.neumorphic`
  (stable id `neumorphic`).
- Map the resolved `DesignToken` into the Neumorphic theme and install it through
  a theme scope (never a nested application shell).
- Build native Neumorphic widgets for: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, toast**. Seven of them
  are mappings to a library widget (`progress` is `NeuProgressBar`, a recessed
  trough with a domed fill); four are composed out of the library's own faces —
  `NeuContainer` in `pressed`/`concave`/`convex` shapes with `NeuTheme` colours,
  depth and radius — because `flutter_neumorphic_ui_kit` ships no segmented
  track, no dropdown, no tab strip and no transient message (§9).
- Declare exactly those controls in `neumorphicCapabilities` so the core
  resolver reports a `controlUnsupported` downgrade for the rest (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (the page trio `scaffold`, `app bar`, `list row` and
`nav bar`) fall back to the core shared token renderer — they still render
on-theme.

## Public entry point

`package:live_uikit_neumorphic/live_uikit_neumorphic.dart` — exports only the
registration API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter},
  fallback: SharedLanguageAdapter(),
);
```

The library reuses the core's localization, so this package adds no delegates.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `flutter_neumorphic_ui_kit` ^1.0.1 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_neumorphic
```

`test/adapter/neumorphic_contract_test.dart` verifies the stable id/display
name, that the declared capabilities match the controls the adapter overrides, and
the core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Scaffold, app bar, list row and nav bar use the shared renderer, not native
  Neumorphic surfaces; that is the next pass for this package.
- `segmented`, `select`, `tab bar` and `toast` are composed from the library's
  own container faces rather than mapped to a widget of theirs, and the select's
  option list opens inline (the core owns the overlay, so nothing here may ask
  for one).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path), and
  `test/integration/` (resolution surface across the contract and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- `NeuTextField` has no `readOnly`, and the soft surface has no `selected` or
  `bordered` form, so those spec fields are recorded as unmappable rather than
  emulated (§9).
