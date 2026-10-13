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

### Known limitations

- No widget-level or cross-style integration tests yet; segmented, select and tab
  bar are served by the shared renderer rather than native Fluent widgets.
