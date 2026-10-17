# Changelog

All notable changes to `live_uikit_wind` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Wind `LanguageAdapter` (`WindLanguageAdapter`, stable id `wind`) registered by
  the composition root via `createWindUiAdapter()` / `windUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Wind theme scope (`theme/`).
- Builders for all seventeen contract controls, each of them this library's own
  widget or a composition of its parts, plus the two structural surfaces.
- `windUiCapabilities` declaring the whole contract, since every control of it is
  built here.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- §16 and §19 describe what this package actually delivers: the controls it builds, with the
  capability/override drift gate holding them together, the theme scope mapping
  brightness, the accent swatch and a configured global font, and the button's focus
  fields recorded as unexpressible on `WAnchor`. The acceptance boxes verified against
  the code are ticked; the hardware half is left open and named.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This adapter does not
  map it: its button is the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted as a generic box; the builder
  composes its own label, so a textless button arrives already correct, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- `card` and `text field` went native: `WindCardBuilder` (fork structure with the token
  surface) and `WindTextFieldBuilder` (`wind.WInput`, with the fork `InputType` collapse
  and the error caption), both declared in `windUiCapabilities` and flipped in the contract
  test in the same change.
- Button: `disabled` now follows the seam verdict, `expand` uses the fork's `w-full`
  class, and `tooltip`/`semanticLabel` are carried; the interactive card stretches its body
  so the hit area matches the painted surface.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and a live theme switch.
- The contract is seventeen controls and two structural surfaces, and this adapter now
  builds every one of them. `slider`, `segmented` and `progress` are drawn from
  `fluttersdk_wind`'s own pieces — `WDiv` and `WCard` panels, the `WAnchor` its own
  controls are built on, `WText`/`WIcon` leaves, `WButton` for a segment — coloured from
  its Tailwind maps and driven through its state prefixes, because the library ships no
  slider, segmented track or progress bar; the bare tab strip is the same story.
  `windUiCapabilities` declares all seventeen and the adapter implements all of them, so
  a Wind page has no unimplemented control and no frame, bar, row,
  navigation bar, toast, dialog or page switcher of another language's shape in it; the
  dialog is its `WCard` surface over a barrier owned by core's `showLiveDialog`, and the
  tab view is Flutter's `PageView` under the strip. A composed control cannot always
  carry every spec field a mapping does: the switch's thumb transform has no parser here,
  so an indeterminate progress run breathes instead of travelling. `LiveUiDiagnosticCode`
  now has one member, `unsupportedEffect`, and an unregistered language fails resolution
  with `LiveUiResolutionException` rather than rendering in a default look.

### Fixed

- Switch and checkbox: a null callback now drives the fork `disabled` flag as well as the
  callback, so the painted state never disagrees with the callback it has (§9/§15).

### Known limitations

- Slider, segmented, progress and the bare tab strip are composed from `fluttersdk_wind`'s own
  parts: the library ships no widget for those jobs (§9).
- `WButton` owns its focus handling inside `WAnchor`, so `focusNode`/`autofocus` are
  unmappable on the Wind button, and `WInput` collapses keyboard type and obscuring into
  one `InputType` (§9).
- Keyboard/TV focus behaviour still needs hardware.
