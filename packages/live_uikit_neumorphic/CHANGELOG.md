# Changelog

All notable changes to `live_uikit_neumorphic` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Neumorphic `LanguageAdapter` (`NeumorphicLanguageAdapter`, stable id
  `neumorphic`) registered by the composition root via `createNeumorphicAdapter()`
  / `neumorphicAdapter`.
- Theme mapping from the resolved `DesignToken` into a Neumorphic theme scope
  (`theme/`).
- A builder for every one of the seventeen controls: `button`, `card`, `textField`,
  `switchWidget`, `checkbox`, `slider`, `progress` and `appBar` drawn with the
  `flutter_neumorphic_ui_kit` widget that already is that control, and `segmented`,
  `select`, `tabBar`, `scaffold`, `listRow`, `navBar`, `toast`, `dialog` and
  `tabView` composed from that library's own container faces and theme values.
- `neumorphicCapabilities` declaring the controls this adapter renders and
  `neumorphicSurfaces` declaring the app host and the shell it owns.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `NeumorphicLanguageAdapter` implements the core `LanguageAdapter` interface
  directly and answers the whole contract inside this package: all seventeen
  controls, the `WidgetsApp` app host and the composed shell are drawn from
  `flutter_neumorphic_ui_kit` — a widget of that library where it has one, composed
  from its own container faces and `NeuTheme` values where it has none
  (`neumorphicCapabilities`, `neumorphicSurfaces`) — so a Neumorphic page contains no
  widget from outside the dependency. The spec fields the library cannot state are
  recorded as unmappable in the builder that refuses them rather than emulated.
- The widget suite now asserts that a caller's `FocusNode` is the node the fork's text
  field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives its
  own focus works in this language. §16 lists the cases that exist rather than the ones
  that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This
  adapter does not map it: its button is the library's own widget and paints its own
  surface, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected`; the builder paints an icon-only button's
  glyph alone, with the tooltip as its accessible name, while `selected` stays
  documented as unmapped here (§9, `docs/decisions/0004`).

- The text field now carries hint, error, obscuring, line count, keyboard hints, leading
  and trailing slots, enable state and the inline `Style` instead of only controller and
  focus node; the card honours an explicit `padding`; the button takes `expand` and
  `tooltip`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a
  `test/integration/` suite for the resolution surface across the whole contract, with
  the caller's state preserved.

### Fixed

- Checkbox: the `bool?` bridge closure is built only when the caller can be called back, so
  a null callback renders disabled instead of live-but-deaf (§9/§15).

### Known limitations

- Nine controls and the shell are composed from the library's container faces rather
  than mapped to a widget of its own, and the select's option list opens inline because
  the core owns the overlay; `readOnly` has no `NeuTextField` parameter and
  `selected`/`bordered` have no soft-surface form (§9).
- Focus visibility on soft surfaces and Android TV D-pad still need hardware.
