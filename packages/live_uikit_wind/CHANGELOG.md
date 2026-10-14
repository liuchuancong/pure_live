# Changelog

All notable changes to `live_uikit_wind` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Wind `LanguageAdapter` (`WindLanguageAdapter`, stable id `wind`) registered by
  the composition root via `createWindUiAdapter()` / `windUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Wind theme scope (`theme/`).
- Native builders for button, switch and checkbox; every other control falls back
  to the core shared token renderer.
- `windUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- §16 and §19 describe what this package actually delivers today: five native controls
  with the capability/override drift gate holding them together, the theme scope mapping
  brightness, the accent swatch and a configured global font, and the button's focus
  fields recorded as unexpressible on `WAnchor`. The acceptance boxes verified against
  the code are ticked; the hardware half is left open and named.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe, which
  the shared token renderer now honours. This adapter does not map it: its button is
  the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted by the core's token
  box; textless rendering comes for free from the shared `buttonLabel`, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- `card` and `text field` went native: `WindCardBuilder` (fork structure with the token
  surface) and `WindTextFieldBuilder` (`wind.WInput`, with the fork `InputType` collapse
  and the error caption), both declared in `windUiCapabilities` and flipped in the contract
  test in the same change.
- Button: `disabled` now follows the seam verdict, `expand` uses the fork's `w-full`
  class, and `tooltip`/`semanticLabel` are carried; the interactive card stretches its body
  so the hit area matches the painted surface.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and the switch to the core base.

### Fixed

- Switch and checkbox: a null callback now drives the fork `disabled` flag as well as the
  callback, so the painted state never disagrees with the callback it has (§9/§15).

### Known limitations

- Slider, segmented, progress, select and tab bar use the shared renderer.
- `WButton` owns its focus handling inside `WAnchor`, so `focusNode`/`autofocus` are
  unmappable on the Wind button, and `WInput` collapses keyboard type and obscuring into
  one `InputType` (§9).
- Keyboard/TV focus behaviour still needs hardware.
