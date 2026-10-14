# Changelog

All notable changes to `live_uikit_glass` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Glass `LanguageAdapter` (`GlassLanguageAdapter`, stable id `glass`) registered by
  the composition root via `createGlassUiAdapter()` / `glassUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Glass theme scope (`theme/`).
- Native builders for button, card and text field; every other control falls back
  to the core shared token renderer.
- `glassUiCapabilities` declaring the natively rendered controls.
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

- The text field passes `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`,
  `textInputAction`, `prefix`, `suffix`, `focusNode` and the inline `Style` through, with
  `errorText` drawn as a caption; the card honours `padding` and the `dense` step; the
  button takes `expand`/`tooltip` and uses the fork's own `padding`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and the switch to the core base.

### Known limitations

- Only button, card and text field are native; `selected`/`bordered` have no frosted
  equivalent and `errorText` is drawn as a caption (§9).
- Blur/backdrop effects must degrade where the platform cannot afford them, and the
  affordance detection that would report `unsupportedEffect` is still blocked on the
  library (§18 Phase 3).
