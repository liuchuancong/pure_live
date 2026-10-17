# Changelog

All notable changes to `live_uikit_material` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Material UI `LanguageAdapter` (`MaterialLanguageAdapter`, stable id `material`)
  registered by the composition root via `createMaterialAdapter()` /
  `materialAdapter`.
- Theme mapping from the resolved `DesignToken` into a Material theme scope
  (`theme/`).
- Native builders for button, card, text field, switch, checkbox, slider,
  segmented, progress, select, tab bar, scaffold, app bar, list row, nav bar,
  toast, dialog and tab view.
- `materialCapabilities` declaring the rendered controls and `materialSurfaces`
  declaring the app host and the shell.
- `materialLocalizationsDelegates` for the fork's own Material localizations.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This
  adapter does not map it: its button is the fork's own widget and paints its own
  surface, so a caller overlay would have to be hand-painted over it; §9 records
  that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` (`docs/decisions/0004`). The glyph-only
  content — the bare icon, the tooltip as its semantic label and the empty label
  never painted — is composed by this package's own button builder, and `selected`
  stays documented as unmapped here (§9).

- The theme scope now installs the fork ink surface (`mu.Material`, transparent) under
  `mu.Theme`, so a host no longer has to nest one before the fork's controls can build.
- Button honours `expand` and `tooltip`; the slider keeps the caller `focusNode`; the card
  honours `dense`, the inline `Style` and interactive-only focus; the text field applies
  the inline `Style`; the segmented control uses the fork's `expandedInsets`.
- `LanguageProgressSpec.showLabel` has no fork equivalent and is documented at the
  builder rather than hand-drawn (§15).
- Added `test/widgets/` assertions for variant mapping, disabled-and-loading parity,
  progress indeterminate and `barColor` tint, the inert slider, RTL layout, and
  the SDK-widget-absent check; new `test/integration/` suite for the §11 resolution
  surface and a re-skin in place with caller-owned state preserved.
- The adapter now implements the full contract itself: `select` is the fork's
  `DropdownButton` (an off-list value is dropped so the field reads as nothing
  chosen, and null or repeated item values leave the menu before the fork's assert
  does), `tab bar` is its `TabBar` and `tab view` its `TabBarView`, each behind a
  `TabController` this package owns and asserts the spec's index onto, and `toast`
  and `dialog` hand back the fork's surface while the core keeps the overlay, the
  route and the timer (§9).
- The chrome pieces are this library's own: `scaffold` is `mu.Scaffold` with the
  dispatched bars in its app-bar and bottom slots, `app bar` is `mu.AppBar` returned
  as a `PreferredSizeWidget`, `list row` is `mu.ListTile` with the fork's `Divider`
  under it for `divided`, and `nav bar` is `mu.NavigationBar`.
- Both structural surfaces are owned here: `appHost` is `mu.MaterialApp.router`
  carrying the token's resolved theme in both its theme slots, and `shell` is
  `mu.NavigationRail` — the fork being the one library that models a disabled
  destination — falling to `mu.NavigationBar` for a bottom request (§ surfaces).
- A disabled slider and a destination strip the fork's assert refuses are composed
  in this package from the library's own disabled colours: the inert rail at the
  theme's `trackHeight` with the thumb dot at the value's fraction, and the elevated
  surface with one unselected cell per destination, each tagged with a key so a
  caller can tell it from the live widget and each unreachable to input (§9/§15).

### Fixed

- Checkbox and segmented: a null `onChanged` now disables the control instead of
  installing a closure that swallowed the value, which left a dead control rendering as
  live (§9/§15).

### Known limitations

- `material_ui` 1.6.0 cannot build a disabled `mu.Slider` (it dereferences a focus
  node it only creates when enabled) and its `mu.NavigationBar` asserts two
  destinations with an in-range selection, so those three spec shapes use this
  package's own inert forms (§9).
- `LanguageProgressSpec.showLabel` has no fork equivalent; `LanguageTabsSpec.spacing`
  has no Material counterpart; `LanguageButtonSpec.selected` and its inline `Style`
  are not mapped onto the fork's button (§9).
- Focus traversal, Android TV D-pad and the platform claims in §13 still need hardware;
  a cross-adapter switch is an application-level test because §3.3 forbids
  adapter-to-adapter dependencies.
