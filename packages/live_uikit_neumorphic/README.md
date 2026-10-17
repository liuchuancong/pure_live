# live_uikit_neumorphic

The Neumorphic design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with the
widgets of `flutter_neumorphic_ui_kit` — or, where that library has no widget for
a control, out of its own container faces and theme values — and maps the resolved
design token into the library's `NeuThemeData`.

See `live-uikit-neumorphic.md` in this directory for the full architecture and
integration specification.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, the tokens, and the
runtime dispatch. This package supplies the **Neumorphic** implementation of that
contract so an application can select `neumorphic` at runtime and have every
control drawn by `flutter_neumorphic_ui_kit`, without any business page importing
that package.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.neumorphic` (stable id
  `neumorphic`). The contract is an `abstract interface class` with nothing behind
  it, and this adapter implements it directly: `language`, `id`, `displayName`,
  `capabilities`, `surfaces`, `wrap`, all seventeen control builders, `appHost` and
  `shell`.
- Map the resolved `DesignToken` into the Neumorphic theme and install it through
  a theme scope (never a second application widget inside the host).
- Build native Neumorphic widgets for all seventeen controls: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Eight are drawn with a widget the library
  ships — `NeuButton`, `NeuCard`, `NeuTextField`, `NeuSwitch`, `NeuCheckbox`,
  `NeuSlider`, `NeuProgressBar` (already a recessed trough with a domed fill) and
  `NeuAppBar` (a `NeuContainer` plane around a `NavigationToolbar`) — and nine are
  composed out of the library's own faces, `NeuContainer` in its
  `flat`/`pressed`/`concave`/`convex` shapes with `NeuTheme` colours, depth and
  radius, because `flutter_neumorphic_ui_kit` ships no segmented track, no
  dropdown, no tab strip, no transient message, no page frame, no list tile, no
  bottom bar that could carry one, no modal surface and no page view. Every builder
  records in its own doc comment whether it mapped a widget or composed one, and
  which spec fields it could not map. The `dialog` composes the surface only — a
  domed (`convex`) panel at twice the theme depth — because the route, the barrier
  and the scale-in are the core's (`showLiveDialog`); the `tab view` slides its
  pages with Flutter's own `PageView` inside a recessed (`concave`) well, the
  inverse of the domed tab. `NeuBottomNav` in particular is a docked floating pill
  that asserts two items, demands a non-null callback and adds its own safe-area
  inset, so it is neither the tab strip nor the nav bar here.
- Declare the whole contract in `neumorphicCapabilities`: all seventeen controls,
  each with an override behind it, so `LiveUiResolver.requireControl` never raises a
  `LiveUiCapabilityException` for this language and every widget inside a
  Neumorphic page is drawn by this library (§16/§17).
- Own both structural surfaces, declared together in `neumorphicSurfaces`: the
  library ships no application widget, so the host is Flutter's `WidgetsApp` with
  `NeuTheme` above the routed tree — which is what takes the page transition and
  the scroll physics out of Material's hands (§ surfaces) — and the shell is a
  vertical navigation column composed out of that library's own container faces,
  because it has no rail, sidebar or `NavigationView` of its own (see
  `NeumorphicShellBuilder`).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Nothing here is somebody else's rendering wearing this language's colours: every
control a page asks for is drawn by `flutter_neumorphic_ui_kit`, the host the page
sits in is this package's own `WidgetsApp` under `NeuTheme`, and the navigation
around it is the column this package composes. A language this build did not
register is a `LiveUiResolutionException` raised by the resolver, not a skin this
package can be asked to stand in for.

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
);
```

`UiConfig.language` selects the language at runtime; a `LiveButton` then draws
through this adapter with no change to the page. The library reuses the core's
localization, so this package adds no delegates.

## Dependencies

- `live_uikit` (the contracts, tokens and runtime dispatch)
- `flutter_neumorphic_ui_kit` ^1.0.1 (the widgets and the `NeuTheme` facilities)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_neumorphic
```

`test/adapter/neumorphic_contract_test.dart` verifies the stable id/display name,
that the declared capabilities match the controls the adapter overrides and the
declared surfaces match the ones it owns, that every control of the contract passes
`requireControl` with nothing raised, and that a language this build did not
register raises `LiveUiResolutionException` (§16/§17).

## Known limitations

- `NeuTextField` has no `readOnly`, the soft card surface has no `selected` or
  `bordered` form, `NeuButton` takes no `focusNode`/`autofocus`, `selected` or the
  inline `Style`, and the library's bar types `bottom` as a `PreferredSizeWidget`
  where the contract's is any dispatched widget — so the Neumorphic tab strip is
  stacked under the bar instead. Those fields are recorded as unmappable in the
  builders rather than emulated (§9/§15).
- Nine controls and the shell are composed from the library's own container faces
  instead of mapped to a widget of theirs, and the select's option list opens
  inline: the core owns the overlay, so nothing here may ask for one.
- The app shell has no navigation widget of its library to borrow: `NeuBottomNav`
  is a horizontal floating pill that asserts two items, demands a non-null callback
  and adds its own safe-area inset, so the rail is a composed column and the phone
  form goes back through `navBar`. The composed column has a slot for
  `LanguageShellSpec.trailing`; the docked slab does not, so a bottom shell drops
  the footer rather than inventing one (§ surfaces).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every control driven through the real dispatch path, including
  the composed shell, the host and the two surface-only controls), and
  `test/integration/` (the resolution surface across the whole contract, with
  caller-owned state preserved). What remains untested is the part that needs
  hardware: focus traversal, Android TV D-pad, and the platform claims in §13.
