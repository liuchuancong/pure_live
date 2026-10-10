# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Added `DesignTokensTheme` (a `ThemeExtension`) plus `context.designTokens` / `context.themeTokens`, so
  density, input mode, focus weight and the motion budget can reach a widget at all: `ThemeData` has no slot
  for any of them. Reading outside a themed tree falls back to the platform's resolved default rather than
  throwing - a missing extension would otherwise take a route down over a spacing number.
- Added `rolesOfScheme`, the default `ColorRole -> Color` mapping, so a style overrides one entry instead of
  replacing a table, and `platformProfileOf` / `targetPlatformFor` for the translation Flutter cannot do
  itself (Android TV reports as android; the host has to say so rather than a width guessing it).
- `PosterCard`, `EmptyStateView`, `ErrorRetryView` and `SectionHeader` now take sizes from the tokens, and
  their text goes through `typeSize`, which is where the ten-foot readable floor actually applies.
- **Fixed**: `PosterCard.width` was declared and never used, so a caller who passed it got a different layout
  than one who did not - and neither was an error.
- `ErrorRetryView` accepts `title` / `retryLabel`: a base component that hardcodes "重试" is a base component
  every translated feature has to copy.
- Covers show a placeholder while loading, not only on error.
