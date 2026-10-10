# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- **Breaking (internally)**: `StyleThemeFactory` now receives `DesignTokens` instead of a `TextTheme?`, and
  `themeFor` gained an optional `{tokens}`. The shared part of a theme moved into `_applyTokens`, which runs
  after the style's factory: switching to Fluent used to also switch to a mouse's density, so a Fluent build
  on a TV shipped a 36-pixel button. Density, tap-target size, control heights, toolbar height, the six text
  roles, list padding, focus weight and the splash now come from the tokens for every style.
- The registry installs `DesignTokensTheme` (from ui_kit) on the theme it produces, so components read the
  same numbers the app agreed to.
- `visualDensity` maps to the three constants the SDK guarantees (standard / comfortable / compact); route
  transitions are deliberately not mapped, because `PageTransitionsTheme` falls back to a platform builder
  for anything it does not list and an empty map would mean "keep animating".
- Styles keep only their decoration: corners, surfaces, control shapes, platform family.
- Declared `pure_live_design` and `pure_live_ui_kit`, and documented the ui-layer ordering
  (`design -> ui_kit -> adaptive`) in dependency-rules section 3 and section 4.
