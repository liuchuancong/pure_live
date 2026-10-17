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
  and progress (`widgets/`).
- `fluentUiCapabilities` declaring the natively rendered controls, and
  `fluentLocalizationsDelegates` for the app shell.
- Capability/resolver contract test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This
  adapter does not map it: its button is the library's own widget, and §9 records
  that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` rather than a private path; the icon-only
  rendering — no `Text`, the tooltip as the semantic label, the square height step —
  is this package's own button builder's, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- Theme mapping now carries the token accent into `AccentColor.swatch` alongside
  brightness and the global font.
- The progress build moved into `FluentProgressBuilder`, which maps `height` to
  `strokeWidth` and `barColor` to `activeColor`; the card honours `padding`, `dense`,
  `selected` and `bordered`; the text field takes `prefix`/`suffix`/`maxLines` and the
  inline `Style` and draws the error caption; the button takes `expand` and `tooltip`.
- New `test/theme/`, `test/widgets/` and `test/integration/` suites for the mapping, the
  eight native controls, and the switch to the core base with state preserved.
- `FluentLanguageAdapter` implements `LanguageAdapter` directly and answers the
  whole contract in this language's own terms: all seventeen controls and both
  structural surfaces. `scaffold` is `fluent.ScaffoldPage`, `appBar` a
  `fluent.PageHeader` with the actions in its command-bar slot, `listRow` a
  `fluent.ListTile`, `toast` a `fluent.InfoBar` at the spec's severity, `dialog` a
  `fluent.ContentDialog` used as a plain surface, `tabView` an `AnimatedSwitcher`
  page swap in the library's own motion vocabulary, `tabBar` a `HoverButton` strip
  with Fluent's accent underline, and `segmented` and `navBar` groups of
  `fluent.ToggleButton`. `appHost` is `FluentApp.router` and `shell` is
  `fluent.NavigationView`; `fluentCapabilities` declares the seventeen and the new
  `fluentSurfaces` declares both surfaces, each matching the methods the adapter
  overrides.
- Resolution is a fault rather than a degrade: `LiveUiResolver.resolve` raises
  `LiveUiResolutionException` for a language this build did not register, and
  `requireControl`/`requireSurface` raise `LiveUiCapabilityException` for a
  declaration the adapter cannot serve. `unsupportedEffect` is the only diagnostic
  code a Fluent run can report.
- `README.md` and `live-uikit-fluent.md` realigned with the implemented interface:
  every control is now listed as mapped or composed, the capability section states
  the full seventeen-control declaration, and the spec fields `fluent_ui` has no
  slot for are recorded as unmapped (§2/§4/§7/§9/§10/§13/§15/§16/§17/§19).

### Fixed

- Checkbox: the `bool?` bridge closure is built only when the caller can be called back, so
  a null callback renders disabled instead of live-but-deaf (§9/§15).

### Known limitations

- `errorText` is drawn as a caption because a bare `TextBox` has no error slot (§9).
- Keyboard navigation, focus rings and the Windows/TV platform claims need real targets.
