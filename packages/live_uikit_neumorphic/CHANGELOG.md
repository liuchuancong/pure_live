# Changelog

All notable changes to `live_uikit_neumorphic` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Neumorphic `LanguageAdapter` (`NeumorphicLanguageAdapter`, stable id
  `neumorphic`) registered by the composition root via `createNeumorphicUiAdapter()`
  / `neumorphicUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Neumorphic theme scope
  (`theme/`).
- Native builders for button, card, text field, switch, checkbox and slider; other
  controls fall back to the core shared token renderer.
- `neumorphicUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- The widget suite now asserts that a caller's `FocusNode` is the node the fork's text
  field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives its
  own focus works in this language. §16 lists the cases that exist rather than the ones
  that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe, which
  the shared token renderer now honours. This adapter does not map it: its button is
  the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted by the core's token
  box; textless rendering comes for free from the shared `buttonLabel`, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- The text field now carries hint, error, obscuring, line count, keyboard hints, leading
  and trailing slots, enable state and the inline `Style` instead of only controller and
  focus node; the card honours an explicit `padding`; the button takes `expand` and
  `tooltip`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and the switch to the core base.

### Fixed

- Checkbox: the `bool?` bridge closure is built only when the caller can be called back, so
  a null callback renders disabled instead of live-but-deaf (§9/§15).

### Known limitations

- Segmented, progress, select and tab bar use the shared renderer; `readOnly` has no
  `NeuTextField` equivalent and `selected`/`bordered` have no soft-surface form (§9).
- Focus visibility on soft surfaces and Android TV D-pad still need hardware.
