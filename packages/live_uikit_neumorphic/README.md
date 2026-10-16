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
  a theme scope (never a second application widget inside the host).
- Build native Neumorphic widgets for all fifteen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast**. Eight are mappings to a library widget (`progress` is
  `NeuProgressBar`, a recessed trough with a domed fill; `app bar` is `NeuAppBar`, a
  `NeuContainer` plane around a `NavigationToolbar`); seven are composed out of the
  library's own faces — `NeuContainer` in its `flat`/`pressed`/`concave`/`convex`
  shapes with `NeuTheme` colours, depth and radius — because
  `flutter_neumorphic_ui_kit` ships no segmented track, no dropdown, no tab strip, no
  transient message, no page frame, no list tile and no bottom bar that could carry
  one (§9). `NeuBottomNav` in particular is a docked floating pill that asserts two
  items, demands a non-null callback and adds its own safe-area inset, so it is
  neither the tab strip nor the nav bar here.
- Declare the whole contract in `neumorphicCapabilities`: a Neumorphic page reports no
  `controlUnsupported` downgrade, and nothing inside a Neumorphic frame is a token
  renderer (§16/§17).
- Own the app host: the library ships no application widget, so the host is
  Flutter's `WidgetsApp` with `NeuTheme` above the routed tree — which is what takes
  the page transition and the scroll physics out of Material's hands (§ surfaces).
  The shell still resolves shared and is reported.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Nothing in the control contract falls back to the core shared token renderer here:
every control a page asks for is drawn by this library, and the host the page sits
in is this package's own — a `WidgetsApp` with `NeuTheme` above the routed tree, not
Material's. The only downgrade a Neumorphic page reports is the app shell, which
this build does not own yet and resolves shared and reports (§ surfaces).

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
