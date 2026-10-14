# Changelog

All notable changes to `live_uikit_fluent` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Fluent `LanguageAdapter` (`FluentLanguageAdapter`, stable id `fluent`) registered
  by the application composition root via `createFluentUiAdapter()` /
  `fluentUiAdapter`.
- Theme mapping from the resolved `DesignToken` to `FluentThemeData`, installed
  through a `FluentTheme` scope (`theme/`).
- Native Fluent builders for button, card, text field, switch, checkbox, slider
  and progress (`widgets/`); unimplemented controls fall back to the core shared
  token renderer.
- `fluentUiCapabilities` declaring the natively rendered controls, and
  `fluentLocalizationsDelegates` for the app shell.
- Capability/resolver contract test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe, which
  the shared token renderer now honours. This adapter does not map it: its button is
  the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted by the core's token
  box; textless rendering comes for free from the shared `buttonLabel`, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- Theme mapping now carries the token accent into `AccentColor.swatch` alongside
  brightness and the global font.
- The progress build moved into `FluentProgressBuilder`, which maps `height` to
  `strokeWidth` and `barColor` to `activeColor`; the card honours `padding`, `dense`,
  `selected` and `bordered`; the text field takes `prefix`/`suffix`/`maxLines` and the
  inline `Style` and draws the error caption; the button takes `expand` and `tooltip`.
- New `test/theme/`, `test/widgets/` and `test/integration/` suites for the mapping, the
  eight native controls, and the switch to the core base with state preserved.

### Fixed

- Checkbox: the `bool?` bridge closure is built only when the caller can be called back, so
  a null callback renders disabled instead of live-but-deaf (§9/§15).

### Known limitations

- Segmented and tab bar use the shared renderer; `errorText` is drawn as a caption because
  a bare `TextBox` has no error slot (§9).
- Keyboard navigation, focus rings and the Windows/TV platform claims need real targets.
