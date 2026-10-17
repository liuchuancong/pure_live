# `live_uikit` Architecture and Integration Specification

- **Package:** `live_uikit`
- **Role:** UI core — design-token system, adapter contracts, runtime dispatch
- **Status:** Architecture specification (describes the implemented system)
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit` is PureLive's unified UI system: the design-token core, the
language-agnostic component set, and the runtime that decides which widget library
actually draws a control.

One `UiConfig` resolves through a seed → derived-token pipeline into a
`DesignToken`, is installed by `LiveConfigProvider`, and is read as `LiveTheme`.
Every `Live*` component builds a neutral `Language*Spec` and hands it to the active
`LanguageAdapter`. Business pages therefore depend on this package and never on a
design-language library: switching the language re-skins the subtree without a page
changing a line.

The package follows this dependency direction:

```text
PureLive application / composition root
       |
       v
   live_uikit  <———————— live_uikit_<style> adapters
       |                            |
   (no UI library)            material_ui, fluent_ui, macos_ui,
                              cupertino_ui, glass_morphism_plus,
                              flutter_neumorphic_ui_kit, fluttersdk_wind
```

The left column is the rule the architecture guard enforces: **the core depends on
no third-party UI library**; adapters depend on the core, never the reverse, and
never on each other.

## 2. Design principles

1. **Tokens are the only source of visual truth.** Colour, type, spacing, radius,
   motion and shadows are derived from a `SeedToken`; no component hardcodes a
   colour or a size.
2. **Semantics, not appearance, cross the contract boundary.** A caller says
   `variant: danger`, `size: lg`, `loading: true`. How that looks is the adapter's
   business alone.
3. **Every language brings its own renderer.** An adapter implements all seventeen
   `LiveUiControl` members plus `appHost()` and `shell()`; the core paints nothing,
   so a control is always drawn by the library the user selected.
4. **What the device cannot afford is observable.** `LiveUiDiagnostic` reports the
   one remaining gap — an effect the hardware cannot afford, `unsupportedEffect` —
   and never a silent substitution (§10).
5. **Caller-owned state stays caller-owned.** Controllers, focus nodes, form values
   and business state belong to the caller; the core never creates a competing one.
6. **Adapters implement, they do not inherit.** Each adapter package
   `implements LanguageAdapter` and draws every control itself, mapping a library
   widget where its library has one and composing that library's own parts where it
   does not, so press, loading and label semantics cannot diverge between two
   languages.
7. **The core owns no policy decisions.** Which language is active, how it is
   persisted, and what the style selector looks like belong to the application.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- **Token pipeline.** `SeedToken`, `DesignToken` (`ColorTokens`, `TypeTokens`,
  `ScaleTokens`, `MotionTokens`), `ColorEngine`, and `ThemeAlgorithms`
  (default / dark / compact, composed by `resolve`).
- **Configuration model.** `UiConfig` (language, brightness, accent, pure black,
  density, font family, font scale, transparency, reduced transparency, animations,
  focus outline) with JSON persistence, and its `SeedToken` projection.
- **Theme surface.** `LiveTheme` (`adapter`, `token`,
  `colors`, `text`, `button`, `card`, `input`, `slider`, `switchToken`, `tabs`,
  `listTile`, `checkbox`, `badge`, `select`, `duration`, `canBlur`, `isDark`,
  `resolveButton`, `supports`, `supportsSurface`), `TextStyles`, and
  `LiveConfigProvider`.
- **Component tokens and recipes.** `ButtonComponentToken` + `ButtonRecipe`, and the
  component tokens for card, input, switch, tabs, list tile, checkbox, slider, badge
  and select.
- **The style model.** `Style` (a freezed, mergeable property bag: padding, margin,
  size bounds, background, foreground, border, radius, opacity, blur, shadow, font
  role, alignment, text align) and `InteractionState`
  (normal / hovered / pressed / focused / disabled).
- **Adapter contracts.** `LanguageAdapter`, the seventeen `Language*Spec` types,
  `LiveDesignLanguage`, `LiveUiControl`, `LiveUiCapabilities`, `LiveUiSurface`,
  `LiveUiSurfaceCapabilities`, `LanguageHostSpec`, `LanguageShellSpec`.
- **Runtime dispatch.** `LanguageRegistry`, `LiveUiResolver`,
  `LiveUiResolutionException`, `LiveUiCapabilityException`.
- **Diagnostics contract.** `LiveUiDiagnostic`, `LiveUiDiagnosticCode`,
  `LiveUiDiagnosticSink` — a plain typedef, so the core depends on no logging
  implementation.
- **The surface adapters paint from.** The resolved `DesignToken`, the component
  tokens, `Style` and `LiveBox`. The core ships no control renderer of its own.
- **Components.** Controls: `LiveBox`, `LiveButton`, `LiveIconButton`, `LiveCard`,
  `LiveTextField`, `LiveSwitch`, `LiveCheckbox`, `LiveSlider`, `LiveSegmented`,
  `LiveSelect<T>`, `LiveTabs`/`LiveTab`, `LiveProgress`, `LiveSpinner`,
  `LiveTooltip`, `LiveMenu`/`LiveMenuItem`, `LiveAvatar`, `LiveBadge`,
  `LiveNumberStepper`, `LiveListRow`; state views `LiveEmpty`, `LiveError`,
  `LiveLoading`; overlays as functions: `showLiveDialog<T>`, `styledToast`.
- **Layout and environment.** `LiveEnvironment`, `LiveEnvironmentScope`,
  `LiveLayoutMode`, `LiveBreakpoints`, `Geometry`, `LiveLayoutBuilder`,
  `LiveContentGrid` — including the TV mode and 10-foot geometry.
- **Backgrounds.** `LiveBackground` with `LiveBackgroundStyle` (solid, gradient,
  image, glass, raised).
- **Static scales.** `LiveRadii`, `LiveSpacing`, `LiveSizing` (including
  `minTouchTarget`, `minRemoteTarget`, `controlHeightTv`).
- **Localization surface.** `liveLocalizationsDelegates`.

### 3.2 What this package must not own

- Any third-party UI library, in code or in `pubspec.yaml`.
- State management frameworks (Riverpod, GetX), navigation, or routing.
- Persistence of the user's preference, the style-selector UI, or application
  settings screens.
- Playback, media sessions, platform windows, plugins or permissions.
- Business feature widgets — those live in `packages/features/*`.

### 3.3 Dependency rules

| Dependency | Allowed | Reason |
|---|---|---|
| `flutter`, `flutter_localizations` | Yes | Widget primitives and the global delegates |
| `freezed_annotation`, `json_annotation` (`build_runner`, `freezed`, `json_serializable` in dev) | Yes | `UiConfig` and `BackgroundStyle` are generated value types |
| `meta` | Yes | Annotations |
| `fluent_ui`, `macos_ui`, `material_ui`, `cupertino_ui`, `glass_morphism_plus`, `flutter_neumorphic_ui_kit`, `fluttersdk_wind` | **No** | Each belongs to its own adapter package; the guard fails the build on any of them |
| Any `live_uikit_<style>` adapter | **No** | Adapters depend on the core, never the reverse |
| Feature/service packages | **No** | Lower-level layer must not depend upward |

## 4. Package directory

```text
packages/live_uikit/
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── analysis_options.yaml
├── live-uikit.md
├── lib/
│   ├── live_uikit.dart                  # the only public barrel
│   └── src/
│       ├── backgrounds/                 # LiveBackground + LiveBackgroundStyle (+ generated)
│       ├── scales/                      # radii, sizing, spacing — the static host-facing scales
│       └── styling/
│           ├── styling.dart             # the curated surface the barrel re-exports
│       │   ├── tokens/                  # seed_token, design_token, component_token,
│       │   │                            # color_engine, theme_algorithm
│       │   ├── style/                   # Style + InteractionState (+ generated), recipe
│       │   ├── config/                  # UiConfig (+ generated), liveLocalizationsDelegates
│       │   ├── contracts/               # LanguageAdapter, the specs, control + surface capabilities
│       │   ├── diagnostics/             # the control enum, diagnostic, codes, sink
│       │   ├── provider/                # LiveConfigProvider, LiveTheme, TextStyles
│       │   ├── resolution/              # registry, resolver
│       │   └── widgets/
│       │       ├── chrome/              # LiveApp (host), LiveAppShell (shell),
│       │       │                        # LiveScaffold, LiveAppBar, LiveNavBar
│       │       ├── controls/            # button, field, switch, checkbox, slider,
│       │       │                        # segmented, select, progress, tabs, stepper
│       │       ├── overlays/            # dialog, menu, toast, tooltip
│       │       ├── content/             # card (+ list row), avatar, badge, state views
│       │       └── layout/              # LiveBox, LiveLayoutBuilder/environment
└── test/
    ├── backgrounds/
    │   └── live_background_test.dart      # the resolved blur affordance (§12)
    └── styling/
        ├── token_derivation_test.dart     # the pipeline pinned to Ant's published numbers
        ├── style_merge_test.dart          # the cascade, property by property
        ├── recipe_test.dart               # base ⊕ variant ⊕ size ⊕ state
        ├── live_environment_test.dart     # breakpoints, geometry, scope notifications
        ├── live_ui_resolver_test.dart     # dispatch and diagnostics (§10)
        ├── live_config_provider_test.dart # what a host is told (§15.5)
        ├── live_icon_button_test.dart     # ADR 0004 through the contract
        ├── live_chrome_test.dart          # the chrome + host specs forward every field
        └── stub_router.dart               # the no-op RouterConfig the host tests pump
```

## 5. Package dependencies

The pubspec declares `resolution: workspace`, `sdk: ^3.13.0`,
`flutter: ">=3.47.0"`, the Flutter SDK plus `flutter_localizations`, the annotation
packages, and `dev_dependencies` for `build_runner`, `freezed`, `json_serializable`
and `very_good_analysis`. Regenerate after editing the config models:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## 6. Public API and entry points

One barrel:

- `package:live_uikit/live_uikit.dart` — what an application *and* every adapter
  package imports. The token/contract/renderer surface it exposes is assembled in
  `src/styling/styling.dart`, which is now internal: two entry points let a
  consumer pick the layer it meant, and that ambiguity showed up as adapters
  importing the app-facing barrel and apps importing the adapter-facing one.

Public surface is exactly what that barrel re-exports — a curated list of
`src/` files, not the whole tree. `LiveConfigProvider`, `LiveTheme`, `UiConfig`,
`SeedToken`, `DesignToken`, `Style`, the `Live*` widgets, `LanguageAdapter`,
`LiveUiCapabilities`, `LiveUiSurfaceCapabilities`, `LanguageRegistry`,
`LiveUiResolver`, the diagnostics types, `liveLocalizationsDelegates` and the static
scales are the supported surface.
The exported widget files are the language-agnostic `Live*` components that dispatch
through the active adapter; the core carries no renderer a control could fall through
to. What stays private is what the
barrels do not name at all — for example `_LiveThemeScope` and the widget files'
private helpers — and any package importing `package:live_uikit/src/...` directly is
the violation §15 guards against.

## 7. Token pipeline

```text
UiConfig ──toSeed()──> SeedToken ──seed override hook──> SeedToken
                                                        |
                              ThemeAlgorithms.resolve(default/dark/compact)
                                                        |
                                                        v
                                                   DesignToken
                            (ColorTokens, TypeTokens, ScaleTokens, MotionTokens)
                                                        |
                             component tokens: Button/Card/Input/Switch/Tabs/
                                               ListTile/Checkbox/Slider/Badge/Select
                                                        |
                                    ButtonRecipe ⊕ state ⇒ Style ⇒ LiveBox
```

- `SeedToken` holds only authored inputs: the five role colours, optional text and
  background bases, font families, base font size, line width, radius, the size
  unit/step and control height, z-indices, image opacity, motion unit/base/flags,
  `focusOutline`, `pureBlack` and the wireframe flag.
- `DesignToken.derive` is Ant's `derivative` + `formatToken`: it builds the ten-step
  primary/success/warning/error/info ramps, the neutral text, fill and background
  ramps, the font/size/radius/height scales, then the semantic aliases and shadows.
  Dark mode and `pureBlack` collapse the background base.
- `ThemeAlgorithms.compactAlgorithm` re-derives from the previous token with
  `controlHeight - 4` and `sizeStep - 2`, keeping the light/dark variant it was
  handed — density is a token transform, not a per-widget flag. `resolve` threads the
  intermediate token through the algorithm list in order, which is what lets a
  post-algorithm like compact see the variant it is tightening.
- `UiConfig` decides *which* algorithms run (`algorithms(dark:)`) and how the
  brightness policy resolves (`useDark(platformDark:)`); the provider calls them. Its
  `toSeed()` folds `accent`, `fontFamily`, `animations`, `pureBlack` and
  `focusOutline` into the seed (plus the spacious density's size step and control
  height), so the accessibility settings reach the derived tokens rather than only the
  widgets that happen to read the config — `focusOutline` is what zeroes
  `motion.lineWidthFocus`.

The layering rule: colours and sizes are read from the resolved token; a component
never derives a colour by hand (`ColorEngine` is the only place mixing happens).

## 8. Style model and recipes

`Style` is the mergeable property bag every renderer paints from; `Style.merge`
layers one on another, and a widget supplies an `inlineStyle` so a caller's `style=`
override wins over the recipe — the precedence every adapter must reproduce.
`InteractionState` is the resolved state a recipe is keyed on
(normal / hovered / pressed / focused / disabled).

Merge obeys one rule that the rest of the system is built on: **null means *unset*,
not *clear***. A state delta (`Style(opacity: 0.65)`) must leave the variant's fill,
the size's padding and the base radius in place, so `merge` is hand-written field by
field (`other.x ?? x`) rather than through Freezed's `copyWith`, which tells "argument
omitted" apart from "argument passed as null" and would erase the layer below. The same
reasoning keeps `Style.isEmpty` a comparison against `Style()` instead of a list of
fields, so a property added later cannot be silently left out of it.

`ButtonRecipe` is the pattern: `base ⊕ variant ⊕ size ⊕ state`, fed only by the
resolved `DesignToken` and `ButtonComponentToken`. `LiveTheme.resolveButton` is the
single entry a widget calls; it never inspects the language. Component tokens without
a dedicated recipe (card, input, tabs, …) are read by whichever adapter draws that
control, following the same shape.

## 9. Adapter contract

```dart
abstract interface class LanguageAdapter {
  LiveDesignLanguage get language;
  String get id;
  String get displayName;
  LiveUiCapabilities get capabilities;
  LiveUiSurfaceCapabilities get surfaces;

  Widget wrap(BuildContext context, DesignToken token, Widget child);

  Widget button(...); Widget card(...); Widget textField(...);
  Widget switchWidget(...); Widget checkbox(...); Widget slider(...);
  Widget segmented(...); Widget progress(...); Widget select<T>(...);
  Widget tabBar(...); Widget scaffold(...); Widget appBar(...);
  Widget listRow(...); Widget navBar(...); Widget toast(...);
  Widget dialog(...); Widget tabView(...);

  Widget appHost(BuildContext context, LanguageHostSpec spec);
  Widget shell(BuildContext context, LanguageShellSpec spec);
}
```

- `wrap` installs the language's theme scope around the subtree it renders.
- `id` is machine-readable and persisted; `displayName` is the selector label;
  `capabilities` and `surfaces` declare what the adapter actually overrides.
- `LiveUiControl` has exactly seventeen members and `LiveUiCapabilities.supports()`
  is what `requireControl` consults; `LiveUiSurface` has two and
  `LiveUiSurfaceCapabilities.supports()` is what `requireSurface` consults. A
  declaration that names a control the adapter does not override, or omits one it
  does, is drift: `requireControl`/`requireSurface` raise
  `LiveUiCapabilityException`, every adapter's contract test asserts the pair, and
  the architecture guard compares the two sets.
- Specs are the whole crossing surface: they carry semantics plus caller-owned
  `controller`/`focusNode`/`autofocus`/`tooltip`/`style`, and nothing else. On the button
  that includes `iconOnly` (a textless control, named by its tooltip), `selected` (a mode
  that is on) and `style` — the caller's top layer, which `LiveButton` accepted as a
  parameter long before the spec could carry it. A spec field a library cannot express is
  documented as unmappable in that adapter's §9, never faked by a hand-painted substitute.

Every adapter package implements this interface directly — the core exports no
shared base to extend. Each draws all seventeen controls plus `appHost()` and
`shell()` from its own library, mapping a widget of that library where the library
has one and composing its parts where it does not, and every builder comment says
which of the two it is.

## 10. Runtime dispatch and diagnostics

```dart
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.material: materialAdapter},
);
final adapter = LiveUiResolver(registry: registry).resolve(language);
```

- `LanguageRegistry` is keyed by `LiveDesignLanguage`, not by the string id, and has
  no fallback slot: a language this build claims to support must bring its own
  adapter, and `UiConfig.language` is required because there is no default language.
- `LiveUiResolver.resolve(language)` returns the `LanguageAdapter` that renders that
  language. An unregistered language throws `LiveUiResolutionException`: there is
  nothing underneath to stand in, so the alternative to throwing is a window painted
  by a library the user did not choose.
- `requireControl(language, control)` and `requireSurface(language, surface)` check a
  declaration against the methods behind it and throw `LiveUiCapabilityException`
  when an adapter claims a control it does not override or a surface it does not own.
- `LiveConfigProvider` performs the resolution **once per language change** and puts
  the adapter itself on `LiveTheme.adapter`, so a widget re-resolves nothing and a
  test can assert the decision.
- Diagnostics reach a host-supplied `LiveUiDiagnosticSink` typedef; the core imports
  no logger. The one code left is `unsupportedEffect` — an effect the device cannot
  afford — because a dispatch result is no longer a reportable downgrade.

The provider reports an unaffordable effect once per language change: rebuilds with
the same language report nothing new, and switching languages re-reports for the new
library. A host with no sink stays quiet. There is no per-control downgrade left to
report — a control is either drawn by the selected library or the build fails loudly
at resolution time (§15.5).

## 11. Adapter rendering conventions

The core ships no renderer. Each of the eight adapter packages draws the whole
contract from its own library, so the conventions below are obligations every
adapter reproduces — mapping a library widget where the library has one, composing
that library's parts where it does not — and each adapter's §16 suite pins them:
honour the caller's `focusNode`/`autofocus`, clamp a value into range, treat a null
callback as disabled, and let `expand` fill the parent's width.

Four of them were settled on the way, and each was verified by a test that first
failed:

- A button builder hands the caller's `style` to `LiveBox` as `inlineStyle`, so an
  override lands on top of `base ⊕ variant ⊕ size ⊕ state` instead of being dropped —
  `LiveButton` had been accepting `style:` and building a spec that could not carry it.
- A text field paints the caller's `style` last, over the input component token —
  fill, radius, border, padding, margin, min/max width, alignment and opacity. Blur is
  a `LiveBox` effect and a field has no frosted state, so an inline `blur` on a field
  stays unpainted by design.
- A segmented control stretches its labels only when `expand` is set. `Expanded` claims
  the whole remaining width even under `MainAxisSize.min`, so a flex child is applied
  on the `expand` branch alone; otherwise `expand: false` looked identical to
  `expand: true`.
- A tab strip treats `enabled` and a null callback as disabled: no tap handler, no
  focus request, a deferred cursor. `LiveTabs` exposes `enabled` so a page can express
  what the spec already carried.

## 12. Components, layout and backgrounds

- Dispatch rule: every `Live*` control builds a spec and calls
  `LiveTheme.of(context).adapter.<control>(context, spec)`.
- Overlay rule: dialogs and toasts are functions, so they inherit the ambient
  `LiveConfigProvider` scope rather than a second theme object.
- Environment rule: `LiveEnvironmentScope` publishes `LiveEnvironment` (layout mode,
  TV flag, `Geometry`); `LiveLayoutBuilder` computes it from the live width plus the
  declared form factor, and `LiveContentGrid` and the state views read it (the state
  views fall back to desktop geometry when no builder is above them). TV mode raises the
  *layout* numbers — page padding 48, icons 28, a 96-high nav bar, no rail, a 1920
  canvas, more elevation — and never a separate widget set. Control heights are not one
  of those numbers: they come from the seed, so a TV composition root raises them there
  (`LiveConfigProvider(seed: (base) => base.copyWith(controlHeight: LiveSizing.controlHeightTv))`).
  `LiveSizing` is the host-facing static scale — nothing in the core reads it, and the
  desktop/mobile rail and nav numbers `Geometry` spells are asserted equal to it.
- Background rule: `LiveBackground` paints behind content from `LiveBackgroundStyle`
  (solid, gradient, image, glass, raised).
- Blur rule: `LiveTheme.canBlur` is the resolved answer to "may a backdrop filter be
  drawn at all" — `UiConfig.allowsTransparency` (which folds `reduceTransparency` and the
  opacity multiplier) intersected once with the host-reported `hardwareBlur` in
  `LiveConfigProvider`. Two core surfaces consume it: `LiveBox`, where a resolved
  `Style.blur` names the effect, and `LiveBackground`, where the frosted surface drops
  its `BackdropFilter` and keeps the translucent fill, and an image blur layer is
  skipped. Outside a provider `LiveBackground` honours the style as written, because
  nothing has resolved an affordance to overrule it.
- Open half of that rule: an adapter's own library effect never reads the flag. Glass's
  fixed `blur: 16` and Fluent's acrylic surfaces are their libraries' decisions, and no
  adapter theme scope can currently overrule them (§15 of those specs).
- Accessibility surface: `UiConfig.reduceTransparency`, `.animations`,
  `.focusOutline` and `.fontScale` are honoured centrally, so a per-component opt-out
  cannot silently defeat a user's platform setting. `focusOutline` is folded into the
  seed, which is what makes the derived `motion.lineWidthFocus` (and any component that
  later sizes a ring from it) answer the setting rather than the Ant default.

## 13. Overlap to settle

`live_uikit_background` owns a second, unrelated `LiveBackground` — a
config/sealed-union pipeline for solid/gradient/image/video backgrounds with layer
stacks, overlays, letterbox fill and a `BackgroundVideoSource` seam to the player
kernel. The two packages do not depend on each other, the adapters may not import
either-by-name exception (§3.3), and today only
`apps/pure_live/lib/background_demo_page.dart` renders one of each. Which package
owns the name `LiveBackground`, and whether the token surface should delegate media
to the other, is an open decision recorded in `docs/decisions/0005-two-livebackground-widgets-in-the-uikit-family.md`.

## 14. Testing strategy

- `test/styling/live_ui_resolver_test.dart` covers dispatch: a registered language
  resolves to its own adapter; an unregistered one throws
  `LiveUiResolutionException`; `requireControl`/`requireSurface` throw
  `LiveUiCapabilityException` against a declaration that has no method behind it.
- `test/styling/live_config_provider_test.dart` covers the reporting surface: an
  effect the device cannot afford is reported once, a rebuild reports nothing new, a
  language switch re-reports, and a host without a sink stays quiet.
- `test/backgrounds/live_background_test.dart` covers the affordance surface: a frosted
  background blurs while the theme allows it, `reduceTransparency: true` and
  `hardwareBlur: false` each drop the `BackdropFilter` while keeping the translucent
  fill, and a background outside any provider keeps the style as written.
- Still untested: whether an adapter's own library effect honours the flag — it does not
  read it at all today (§12), so there is nothing to assert until the libraries expose a
  knob for it.
- `test/styling/token_derivation_test.dart` pins the pipeline to Ant's published
  numbers: the ramp keeps the seed at level 6 and lands on `#e6f4ff` / `#4096ff` /
  `#0958d9` within rounding, the neutral alphas (0.88/0.65/0.45/0.25, and 0.85 with the
  dark text base), the surfaces (`#f5f5f5`, `#d9d9d9`, `#f0f0f0` light; `#141414`,
  `#1f1f1f`, `#424242`, `#303030` dark), `pureBlack` as a dark-only collapse of a seeded
  `colorBgBase`, the modular type scale and its `(size+8)/size` leading, the size/radius/
  height tables, the motion steps, and the algorithm composition — compact tightens
  height and size only, and keeps the light/dark variant it was handed. It also covers
  `UiConfig` → seed → algorithm, including `focusOutline` reaching the seed so
  `lineWidthFocus` answers the user rather than the default.
- `test/styling/style_merge_test.dart` covers the cascade itself: a later layer wins
  only what it names, merging `null` is the same object, `Style.empty` is a no-op, a
  property cannot be unset by merging, `isEmpty` reacts to every property (including
  margin and the text roles), and `applyText` / `toDecoration` paint exactly what is
  named — a border needs both a colour and a positive width.
- `test/styling/recipe_test.dart` covers the four recipe layers and their precedence,
  including the deltas that name nothing (`pressed` on `secondary`/`ghost` keeps the
  variant fill) and that a component-token override repaints the button without moving
  the global primary, through `LiveTheme.resolveButton`.
- `test/styling/live_environment_test.dart` covers the third axis: the breakpoint table
  (719 mobile, 720 desktop, TV outranking any width), the per-mode `Geometry` numbers and
  their token-derived radii, `LiveSizing`'s ladder and the rail/nav values `Geometry`
  repeats, `maybeOf`/`of` outside a builder, a resize re-resolving the same builder, and
  the grid's column count measured from tile positions at 420 and 1400. Its
  equality group asserts a change to *every* `Geometry` field is visible, and one test
  keeps a const subtree re-notified when only the radius moves — the case
  `LiveEnvironmentScope.updateShouldNotify` used to miss.
- The adapter suites carry the rest of the dispatch contract end to end: all
  seventeen controls and both surfaces resolve through the real registry, and a
  switch to another language and back preserves caller-owned state
  (`packages/live_uikit_*/test/integration/`).

## 15. CI and architectural enforcement

`tool/check_architecture.ps1` (fatal in `.github/workflows/architecture.yml`) enforces
this package's boundaries: no concrete UI library in `live_uikit`'s sources or
pubspec, no adapter-to-adapter dependency, and no package outside an adapter
importing or depending on that adapter's library. It also checks §4's tree against the
package — every file the current-layout tree names must exist, and every `test/**_test.dart`
on disk must be named in it, so the directory listing stays an index rather than a
memory. Formatting, analysis and tests are gated the same way as every package.

## 16. Acceptance checklist

- [x] Owns tokens, contracts, dispatch and diagnostics; owns no application policy,
  persistence, navigation, state management — and no control renderer.
- [x] Depends on no third-party UI library and on no adapter.
- [x] Every language draws every control itself, and the contract keeps
  caller-owned controllers, focus nodes and inline style reachable (§11).
- [x] A language with no adapter fails loudly at resolution time; nothing settles
  for a foreign look.
- [x] `LiveUiControl`/`LiveUiCapabilities` and `LiveUiSurface`/
  `LiveUiSurfaceCapabilities` are the capability surfaces adapters declare against.
- [x] `unsupportedEffect` is emitted from the render path, once per language change,
  and asserted there (§10).
- [x] `LiveIconButton` dispatches through the adapter like every other control, carrying
  `iconOnly`/`selected` on the spec (`docs/decisions/0004-…-adapter.md`): each spec's §9
  records whether that language's library has a toggled affordance to map onto.
- [x] Token derivation, `Style` merge and the recipes have their own tests (§14) —
  and the merge fix they forced (`merge` had been clearing the layer below, so no
  styled control ever kept its base style through a state change) is asserted there.
- [x] `UiConfig.reduceTransparency` and the resolved `canBlur` are honoured by the core
  surfaces that blur (`LiveBox`, `LiveBackground`), with tests (§12/§14). Adapter-level
  library effects remain the open part (§12).
- [x] Every spec field a caller can set reaches a renderer or is recorded as unmappable:
  the button spec now carries `iconOnly`, `selected`, `tooltip` and `style`, the last of
  which `LiveButton` accepted but never forwarded (§9/§11).
- [x] The environment axis resolves from the window plus the declared form factor, is
  read by the grid and the state views, re-notifies on any `Geometry` change, and owns no
  separate widget set — with tests (§12/§14).
