# Changelog

All notable changes to `live_uikit_cupertino_ui` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Cupertino UI `LanguageAdapter` (`CupertinoUiLanguageAdapter`, stable id
  `cupertinoUi`) registered by the composition root via `createCupertinoUiAdapter()`
  / `cupertinoUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Cupertino theme scope
  (`theme/`).
- Native builders for button, text field, switch and slider; every other control
  falls back to the core shared token renderer.
- `cupertinoUiCapabilities` declaring the natively rendered controls.
- `cupertinoUiLocalizationsDelegates` for the fork's own Cupertino localizations.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Known limitations

- No widget-level or cross-style integration tests yet; only button, text field,
  switch and slider are native.
