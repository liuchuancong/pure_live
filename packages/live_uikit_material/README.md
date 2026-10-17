# live_uikit_material

The Material UI design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`material_ui` widgets and maps the resolved design token into that library's
theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, the tokens, the
runtime dispatch and the neutral `Live*` widgets a page places. This package
supplies the **Material UI** implementation of that contract so an application
can select `material` at runtime and have its controls drawn by `material_ui`,
without business pages importing it.

`material_ui` is a fork of Flutter's Material widgets, so this adapter covers the
whole contract from that library: `MaterialLanguageAdapter` implements
`LanguageAdapter` and answers all seventeen controls plus both structural
surfaces, taking one of the fork's widgets where the fork has one and composing
its own parts where it does not.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.material` (stable id
  `material`).
- Map the resolved `DesignToken` into the Material theme and install it through a
  theme scope (never a nested application widget).
- Build native Material widgets for all seventeen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Sixteen of them are a single fork widget
  — a `text field` is its `TextField`, a `select` its `DropdownButton`, a `tab bar`
  its `TabBar` behind a `TabController` this package owns, and a `tab view` its
  `TabBarView` behind a second one. A `toast` is the exception with nothing to map:
  it is the fork's `Material` surface themed by its own `SnackBarThemeData`, because
  a `SnackBar` reads an animation only a `ScaffoldMessenger` supplies. Two controls
  keep a second, composed form for the one spec shape the fork refuses to build — a
  `slider` that must not move and a `nav bar` too short to satisfy its assert — drawn
  from the fork's own disabled slider theme and elevated surface role with no press
  target under either (§9).
- Own both structural surfaces: the app host (`mu.MaterialApp`) and the shell
  (`mu.NavigationRail`, or the fork's `NavigationBar` when the caller asks for a
  bottom strip) (§ surfaces).
- Declare the whole contract in `materialCapabilities` and both surfaces in
  `materialSurfaces`. The declaration is checked rather than trusted: a capability
  named without a matching method is a `LiveUiCapabilityException`, and a language
  this build did not register is a `LiveUiResolutionException` (§16/§17).
- Expose `materialLocalizationsDelegates` (the fork's own Material
  localizations) for the composition root to install.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract and both structural surfaces are answered here, from
`material_ui` — one of its widgets where it has one, its own parts where it does
not. A Material page therefore has nothing left in another library's hands: the
fields the fork cannot express (`LanguageProgressSpec.showLabel`,
`LanguageTabsSpec.spacing`, `LanguageButtonSpec.selected` and `.style`) are
documented at the builder that drops them (§9).

## Public entry point

`package:live_uikit_material/live_uikit_material.dart` — exports only the
registration API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/live_uikit_material.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.material: materialAdapter},
);

// In the app shell, append the fork's delegates to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...materialLocalizationsDelegates,
//     ],
//   )
```

## Dependencies

- `live_uikit` (the contracts, tokens and runtime dispatch)
- `material_ui` ^1.6.0 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_material
```

`test/adapter/material_contract_test.dart` verifies the stable id and display
name, that the declared capabilities and surfaces match the methods the adapter
overrides, and that the core resolver hands this language its own adapter and
raises `LiveUiResolutionException` for a language this build did not register
(§16/§17).

## Known limitations

- `LanguageProgressSpec.showLabel` has no slot in the fork's indicator, so a
  Material progress bar never paints the trailing percentage (§9).
- `material_ui` 1.6.0 cannot build a disabled `mu.Slider`, and its
  `mu.NavigationBar` asserts at least two destinations with an in-range selection.
  Those three spec shapes are drawn from the library's own disabled theme and
  elevated surface instead, value on screen and no input reaching the callback (§9).
- `LanguageButtonSpec.selected` and the inline `LanguageButtonSpec.style` are not
  mapped onto the fork's button, and `LanguageTabsSpec.spacing` has no Material
  counterpart; the tab strip uses the library's own tab padding (§9).
- Test coverage is present at four layers: `test/adapter/` (contract, capabilities,
  surfaces and resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime
  re-skin), `test/widgets/` (every control driven through the real dispatch path,
  including the inert slider, the inert destination strip, the chrome pieces, the
  fork host and the shell), and `test/integration/` (the whole contract resolving
  through the production resolver, and a changed `UiConfig` re-skinning Material UI
  in place with caller-owned state preserved). What remains untested is the part
  that needs hardware: focus traversal, Android TV D-pad, and the platform claims
  in §13.
