# Changelog

All notable changes to `live_uikit_glass` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Glass `LanguageAdapter` (`GlassLanguageAdapter`, stable id `glass`) registered by
  the composition root via `createGlassAdapter()` / `glassAdapter`.
- Theme mapping from the resolved `DesignToken` into a Glass theme scope (`theme/`).
- A builder for every one of the seventeen controls: `button`, `card`, `text field`
  and `list row` drawn with the `glass_morphism_plus` widgets that exist, the other
  thirteen composed from that library's own frosted parts, and both structural
  surfaces — the app host and the shell — built here as well.
- `glassCapabilities` declaring the controls the adapter overrides and `glassSurfaces`
  declaring the surfaces it owns.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `GlassLanguageAdapter` implements the `LanguageAdapter` interface outright and
  answers all seventeen controls plus the app host and the shell from
  `glass_morphism_plus` — the library's own widget where it has one, a composition of
  its frosted surfaces and theme values where it does not. `README.md` and
  `live-uikit-glass.md` now say which of the two each control is, and the failure
  sections name the two answers the core actually gives: `LiveUiResolutionException`
  for a language this build did not register, and the `unsupportedEffect` diagnostic
  for a device that cannot afford the blur.
- The widget suite now asserts that a caller's `FocusNode` is the node the library's
  text field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives
  its own focus works in this language. §16 lists the cases that exist rather than the ones
  that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This
  adapter does not map it: its button is the library's own widget and paints its own
  surface, and §9 records that trade.
- An icon-only or toggled button reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected`; the builder paints the bare glyph for a
  textless button, and `selected` stays documented as unmapped here because this
  library's button has no toggled affordance (§9, `docs/decisions/0004`).
- The text field passes `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`,
  `textInputAction`, `prefix`, `suffix`, `focusNode` and the inline `Style` through, with
  `errorText` drawn as a caption; the card honours `padding` and the `dense` step; the
  button takes `expand`/`tooltip` and uses the library's own `padding`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and a re-theme that must
  preserve the caller's controller.

### Known limitations

- Only button, card, text field and list row are the library's own widgets; the other
  thirteen are composed from its frosted sheets. `selected`/`bordered` have no frosted
  equivalent, `focusNode`/`autofocus` have no slot on button, card or list row, and
  `errorText` is drawn as a caption (§9).
- Blur/backdrop effects must degrade where the platform cannot afford them, and the
  affordance detection that would report `unsupportedEffect` is still blocked on the
  library (§18 Phase 3).
