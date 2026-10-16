# live_uikit_macos

The macOS design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `macos_ui`
widgets and maps the resolved design token into `MacosThemeData`.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **macOS**
implementation so an application can select `macos` at runtime and have its
controls drawn by `macos_ui`, without business pages importing `macos_ui`.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.macos` (stable id `macos`).
- Map the resolved `DesignToken` into a `MacosThemeData` and install it through a
  `MacosTheme` scope (never a nested `MacosApp`).
- Build native macOS widgets for all fifteen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast**. Eleven are a one-for-one mapping onto the library's own
  widget. Four are composed out of its parts rather than mapped — the card and the
  toast surface are `MacosSheet`, the library's own panel mounted inline, because
  `macos_ui` 2.2.2 has no card, no box and no toast at all; the tab bar and the nav
  bar are rows of the library's `MacosTab` cell with its `MacosIcon` in front,
  because `MacosTabView` is a whole tab *view* with one body per tab, the real
  segmented strip has a text-only cell, and the library has no bottom bar (§9).
- Own the app-host surface (`MacosApp`); the shell falls back to the shared token
  renderer, because `Sidebar` belongs to a `MacosWindow` frame whose owner the
  contract does not yet decide (§ surfaces).
- Declare the whole contract in `macosCapabilities`: a macOS page reports no
  `controlUnsupported` downgrade, and nothing inside a macOS frame is a token
  renderer (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Nothing in the contract falls back to the core shared token renderer any more. Two
spec shapes still do, because the library refuses them rather than the adapter not
trying: a slider with no callback (`MacosSlider.onChanged` is required) and a select
whose current value is not one of its items (`MacosPopupButton` asserts it).

## Public entry point

`package:live_uikit_macos/live_uikit_macos.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.macos: macosAdapter},
  fallback: SharedLanguageAdapter(),
);
```

`macos_ui` reuses the core's Material/Cupertino localization, so this package adds
no delegates of its own (§14).

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `macos_ui` ^2.2.2 (the native macOS widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_macos
```

`test/adapter/macos_contract_test.dart` verifies the stable id/display name,
that the declared capabilities are the whole contract, and the core resolver's
native dispatch for every control (§16/§17).

## Known limitations

- The card, the toast surface and the two strips are composed from `macos_ui`'s own
  parts (`MacosSheet`, `MacosTab`, `MacosIcon`) because the library carries no card,
  no box, no transient message and no bottom bar; they are macOS by its own visual
  vocabulary, but they are not one widget the library ships.
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every control driven through the real dispatch path, and no
  `Token*` renderer left inside a macOS frame), and `test/integration/` (resolution
  surface across the contract and a switch to the shared `token` base and back with
  caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- A disabled slider has no `macos_ui` form (`MacosSlider.onChanged` is required),
  and a select whose value is not among its items is refused by
  `MacosPopupButton`'s own assert, so those two spec shapes fall back to the shared
  renderer; `PushButton`, `MacosSlider`, `MacosSwitch` and `MacosSheet` accept no
  caller focus node (§9/§15).
- macOS styling can be selected on any platform, but native macOS window
  integration should not be assumed off-macOS (§13).
