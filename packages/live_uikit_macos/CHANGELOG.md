# Changelog

All notable changes to `live_uikit_macos` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- macOS `LanguageAdapter` (`MacosLanguageAdapter`, stable id `macos`) registered by
  the composition root via `createMacosUiAdapter()` / `macosUiAdapter`.
- Theme mapping from the resolved `DesignToken` to `MacosThemeData`, installed
  through a `MacosTheme` scope (`theme/`).
- Native macOS builders for button, text field, checkbox and slider; other
  controls fall back to the core shared token renderer.
- `macosUiCapabilities` declaring the natively rendered controls.
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

- The slider now passes `min`/`max` to the fork instead of relying on its 0..1 defaults;
  the text field takes `textInputAction`, `maxLines`, `prefix`/`suffix` and the inline
  `Style`, and draws the error caption; the button takes `expand`, `tooltip` and the
  accessible `semanticLabel`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite including the typed `select` fallback surviving a switch.

### Fixed

- Checkbox: a null `onChanged` disables the box instead of installing a closure that
  swallowed the value (§9/§15).
- A disabled slider routes to the shared token renderer: `MacosSlider.onChanged` is
  required, so the previous closure made a dead slider look live (§9/§15).

### Known limitations

- Card, switch, segmented, progress, select and tab bar use the shared renderer, and a
  disabled slider does too (§9).
- `PushButton` and `MacosSlider` accept no caller focus node, so `focusNode`/`autofocus`
  are unmappable on those two controls (§9).
