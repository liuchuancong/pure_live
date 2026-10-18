# Changelog

All notable changes to `live_uikit` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- The `adaptive` module, ported from the standalone Fluent-inspired kit: the
  `AdaptiveBreakpoint` width classes (600 / 1024 / 1440) with `AdaptiveBreakpoints`
  helpers and `AdaptiveBreakpointBuilder`, `AdaptiveScaffold` resolving one of five
  `PureNavigationMode` surfaces (bottom bar, rail, labelled sidebar, drawer,
  focus-first TV rail), the `PureNavDestination` / `PureNavigationTile` vocabulary,
  `PureBottomNavigation`, `PureNavigationRail`, `DesktopNavigation`,
  `PureNavigationDrawer`, `PureTvNavigation`, `AdaptiveContentLayout`,
  `ResponsiveGrid` / `SliverResponsiveGrid` and `ResponsiveContent` /
  `SliverResponsiveContent`. The surfaces take their colours from the active design
  language through `AdaptiveSurfaceColors.of(context)` rather than a palette of
  their own, so the same shell structure serves every language the package ships.
- `LanguageButtonSpec.iconOnly` and `.selected`, so a textless or toggled button is
  contract data rather than a private rendering path. Every adapter honours both: no
  `Text` is painted for an icon-only spec, the glyph carries the tooltip as its
  `semanticLabel`, the control squares to its `ControlSize` height step, and a
  selected button takes the primary foreground or its library's own toggle.
- `LiveIconButton` builds a spec and calls `adapter.button(...)` like every other
  control, instead of painting a `LiveBox` of its own — icon buttons now re-skin with
  the selected language.
- `test/styling/live_icon_button_test.dart` (spec reaching the adapter, no `Text`,
  square geometry, semantics label, selected foreground) and
  `test/backgrounds/live_background_test.dart` for the blur affordance.
- `LanguageButtonSpec.style`, the button's inline override. `LiveButton` has accepted a
  `style:` parameter since it was written, but the spec it built had no field to carry
  it, so the override never reached any renderer; a button builder now passes it to
  `LiveBox` as `inlineStyle`, on top of the recipe.
- `test/styling/live_environment_test.dart` covers the layout axis: the breakpoint
  table, the per-mode `Geometry`, `LiveSizing`'s ladder and the numbers `Geometry`
  repeats from it, resize re-resolution, the grid's measured column count, and reading
  the environment with and without a `LiveLayoutBuilder`.
- `test/styling/live_config_provider_test.dart` covers the reporting surface.
- `test/styling/token_derivation_test.dart`, `test/styling/style_merge_test.dart` and
  `test/styling/recipe_test.dart` cover the surfaces the spec listed as untested: the
  seed → `DesignToken` pipeline pinned against Ant's published values, the `Style`
  cascade, and the button recipe's layers and precedence.
- `LiveTabs.enabled`, so a page can express what `LanguageTabsSpec` already carried.
- `SeedToken.copyWith` accepts `focusOutline`, which is how `UiConfig.focusOutline`
  now reaches the derived `motion.lineWidthFocus`.
- `README.md` documenting purpose, responsibilities, exclusions, entry points,
  integration, testing and limitations (§13.1 of the package standards).

### Changed

- **Every visual widget now dispatches to an official component.** The
  `PureDesignLanguage` switch in `PureSwitch`, `PureCheckbox`, `PureSlider`,
  `PureProgress`, `PureSegmented`, `PureSelect`, `PureTabs`, `PureButton`,
  `PureAvatar`, `PureBadge`, `PureAppBar`, `PureNavBar`, `PureScaffold`,
  `PureMenu`, `PureDialog`, `PureTooltip` and `PureToast` returns a widget from
  the active language's own library. Where a surface library genuinely ships
  no such component (glass, neumorphic, wind), the branch returns Flutter's
  official Material component rather than a hand-drawn imitation. Only
  controller adapters (Material/macOS tab controllers), the OS title-bar chrome,
  and non-visual layout mechanics remain custom.

- `docs/decisions/0004` records the icon-button decision as accepted and implemented;
  the mapping of `selected` inside third-party libraries is left as its documented
  remainder.
- `LiveButton.tooltip`, forwarded into `LanguageButtonSpec.tooltip`, and every button
  builder now wraps an expanded or hinted button the same way — so `expand` and
  `tooltip` are no longer spec fields with no producer.
- **The shared token renderer is gone, and with it the `token` language.**
  `SharedLanguageAdapter`, its `Token*` widgets, `LiveUiFallbackPolicy`,
  `LiveImplementationKind`, `LiveTheme.implementationKind` and the downgraded
  diagnostic codes (`adapterMissing`, `controlUnsupported`, `surfaceUnsupported`,
  `defaultAdapterMissing`) are deleted: the contract is now that every one of the
  seventeen `LiveUiControl` members and both `LiveUiSurface` members is drawn by the
  selected library, so a design language can no longer settle for another library's
  look. `LanguageRegistry` has no `fallback` slot, `UiConfig.language` is required,
  an unregistered language throws `LiveUiResolutionException`, a declaration without
  a method behind it throws `LiveUiCapabilityException`, and the only code a
  `LiveUiDiagnosticSink` still receives is `unsupportedEffect`.

### Fixed

- `Geometry` compared three of its twelve fields, so
  `LiveEnvironmentScope.updateShouldNotify` could report "nothing changed" while the card
  radius, section gap, nav height or content width had moved — a subtree behind a `const`
  widget silently kept the old layout. Equality and `hashCode` now cover every field, and
  a test keeps a const consumer re-notified when only a radius moves.
- **`Style.merge` cleared every property the upper layer did not name.** It delegated
  to Freezed's `copyWith`, which distinguishes an omitted argument from one passed as
  `null`, so merging a state delta (`Style(opacity: 0.65)`, or the `Style.empty` a
  resting control returns) erased the variant fill, the size padding, the base radius
  and the alignment beneath it — every token-drawn control lost its whole style as soon
  as a recipe layered anything on it. `merge` is now the documented cascade, written
  field by field, and `test/styling/style_merge_test.dart` holds it there.
- `Style.isEmpty` answered for ten of the twenty-one properties, reporting a style that
  set only `margin`, `minWidth` or a text role as empty. It now compares against
  `Style()`, so a property added later cannot be left out of it again.
- The segmented control claimed its parent's whole width whatever `expand` said: an
  `Expanded` child fills the row even under `MainAxisSize.min`. The flex child is now
  applied only on the `expand` branch, so a content-sized segmented control hugs its
  labels — the rule every adapter's segmented builder now follows.
- A tab strip ignored `LanguageTabsSpec.enabled`: it stayed tappable, focusable and
  pointer-cursored while reporting itself disabled. `enabled: false` and a null
  callback now both refuse input, in the core dispatcher and in every adapter.
- A text field dropped the caller's inline `style` entirely — a `style:` on a field
  painted nothing. The surface (fill, radius, border, padding, margin, min/max width,
  alignment, opacity) now takes the override last, like every other control.
- `LiveBackground` now honours the resolved affordance flag: with
  `UiConfig.reduceTransparency` set, or a host reporting no hardware blur, the frosted
  surface drops its `BackdropFilter` and keeps its translucent fill, and an image blur
  layer is skipped. Previously only `LiveBox` consulted `LiveTheme.canBlur`, so an
  accessibility setting the user had turned on was silently ignored by every page
  background. Outside a `LiveConfigProvider` the style is still honoured as written.
- The `LiveBackgroundStyle` documentation named a `LiveBackgroundPresets` type that does
  not exist as the place where that decision lived; it now points at the real gate.
- A switch announced `toggled` and `checked` on the same semantics node, which
  asserts inside the render tree as soon as a switch is built under a semantics
  owner; a switch is a toggle, so `checked` is dropped.
- `LiveTabs`' tab laid its ink bar out with `CrossAxisAlignment.stretch` inside the
  strip's `Row`, whose children get an unbounded main-axis width — the bar forced an
  infinite width and the strip failed to lay out. The tab is now bounded by its own
  intrinsic width, which is also what the ink bar is meant to span.

### Known limitations

- An adapter's own library effect (glass blur, fluent acrylic) never reads
  `LiveTheme.canBlur`, so a user's reduce-transparency setting is honoured by the core
  surfaces and not by the third-party ones.
- `LanguageButtonSpec.selected` has no library equivalent in most languages: forui maps
  it onto `FButton.selected`, and the others tint the control themselves and record in
  their §9 that the library has no toggled affordance to carry it.
- The environment axis lays out, it does not size controls: TV mode moves the page
  padding, icons, gaps and chrome heights, while control height stays a seed value a TV
  composition root has to raise itself. `LiveSizing` states the numbers; nothing in the
  core reads them.
