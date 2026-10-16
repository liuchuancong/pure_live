# `live_uikit` Architecture and Integration Specification

- **Package:** `live_uikit`
- **Role:** UI core — design-token system, adapter contracts, runtime dispatch, shared renderer
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
   or the renderer's business.
3. **Every control has a working default.** `SharedLanguageAdapter` paints all ten
   controls from the tokens, so a language with no adapter — or a control no adapter
   overrides — is still functional and on-theme.
4. **Downgrades are observable.** A fallback is a fact the runtime reports through
   `LiveUiDiagnostic`, never a silent substitution (§10).
5. **Caller-owned state stays caller-owned.** Controllers, focus nodes, form values
   and business state belong to the caller; the core never creates a competing one.
6. **Adapters extend, they do not replace.** An adapter subclasses
   `SharedLanguageAdapter` and overrides only what it renders natively, so press,
   loading and label semantics cannot diverge between a native button and a
   token-rendered one.
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
- **Theme surface.** `LiveTheme` (`adapter`, `implementationKind`, `token`,
  `colors`, `text`, `button`, `card`, `input`, `slider`, `switchToken`, `tabs`,
  `listTile`, `checkbox`, `badge`, `select`, `duration`, `canBlur`, `isDark`,
  `resolveButton`, `supports`), `TextStyles`, and `LiveConfigProvider`.
- **Component tokens and recipes.** `ButtonComponentToken` + `ButtonRecipe`, and the
  component tokens for card, input, switch, tabs, list tile, checkbox, slider, badge
  and select.
- **The style model.** `Style` (a freezed, mergeable property bag: padding, margin,
  size bounds, background, foreground, border, radius, opacity, blur, shadow, font
  role, alignment, text align) and `InteractionState`
  (normal / hovered / pressed / focused / disabled).
- **Adapter contracts.** `LanguageAdapter`, the ten `Language*Spec` types,
  `LiveDesignLanguage`, `LiveUiControl`, `LiveUiCapabilities`,
  `LiveImplementationKind`.
- **Runtime dispatch.** `LanguageRegistry`, `LiveUiResolver`,
  `LiveUiFallbackPolicy`, `LiveUiResolution`, `LiveUiResolutionException`.
- **Diagnostics contract.** `LiveUiDiagnostic`, `LiveUiDiagnosticCode`,
  `LiveUiDiagnosticSink` — a plain typedef, so the core depends on no logging
  implementation.
- **Shared token renderer.** `SharedLanguageAdapter` and its `Token*` widgets, plus
  the seam helpers adapters reuse: `interactive()`, `buttonLabel()`, `labelled()`.
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
│       │   ├── contracts/               # LanguageAdapter, the specs, LiveUiCapabilities
│       │   ├── diagnostics/             # control/kind enums, diagnostic, codes, sink
│       │   ├── provider/                # LiveConfigProvider, LiveTheme, TextStyles
│       │   ├── resolution/              # registry, resolver, fallback policy
│       │   ├── shared/                  # SharedLanguageAdapter (the token renderer)
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
        ├── shared_renderer_test.dart      # the `Token*` renderer's spec fidelity
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
`SharedLanguageAdapter`, `LanguageRegistry`, `LiveUiResolver`, the diagnostics
types, `liveLocalizationsDelegates` and the static scales are the supported surface.
The exported widget files also carry their `Token*` fallback renderers: those are
visible because the shared renderer is a reusable composition a host may legitimately
embed, not because a page should paint a card by hand. What stays private is what the
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
a dedicated recipe (card, input, tabs, …) resolve their style inside the corresponding
`Token*` widget, following the same shape.

## 9. Adapter contract

```dart
abstract interface class LanguageAdapter {
  LiveDesignLanguage get language;
  String get id;
  String get displayName;
  LiveUiCapabilities get capabilities;

  Widget wrap(BuildContext context, DesignToken token, Widget child);

  Widget button(...); Widget card(...); Widget textField(...);
  Widget switchWidget(...); Widget checkbox(...); Widget slider(...);
  Widget segmented(...); Widget progress(...); Widget select<T>(...);
  Widget tabBar(...);
}
```

- `wrap` installs the language's theme scope; the shared adapter returns the child
  unchanged, because the token renderer reads `LiveTheme` directly.
- `id` is machine-readable and persisted; `displayName` is the selector label;
  `capabilities` is a declaration of fact about which methods the adapter overrides.
- `LiveUiControl` has exactly ten members and `LiveUiCapabilities.supports()` is what
  the resolver consults. A capability set that lists a control the adapter does not
  override, or omits one it does, is drift — asserted in every adapter's contract test
  and by the architecture guard.
- Specs are the whole crossing surface: they carry semantics plus caller-owned
  `controller`/`focusNode`/`autofocus`/`tooltip`/`style`, and nothing else. On the button
  that includes `iconOnly` (a textless control, named by its tooltip), `selected` (a mode
  that is on) and `style` — the caller's top layer, which `LiveButton` accepted as a
  parameter long before the spec could carry it. A spec field a library cannot express is
  documented as unmappable in that adapter's §9, never faked by a hand-painted substitute.

`SharedLanguageAdapter implements LanguageAdapter` (its `language` is
`LiveDesignLanguage.token`, its capabilities are empty) and additionally exposes
the seam helpers `interactive(spec)`, `buttonLabel(spec, theme)` and
`labelled(context, label, control)` that adapters call from their own builders.

## 10. Runtime dispatch and diagnostics

```dart
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.material: materialAdapter},
  fallback: SharedLanguageAdapter(),
);
const resolver = LiveUiResolver(registry: registry);
```

- `LanguageRegistry` is keyed by `LiveDesignLanguage`, not by the string id;
  `defaultLanguageRegistry` registers nothing, so an app that forgets to wire
  adapters still renders, and reports it.
- `LiveUiResolver.resolve(language)` answers *who renders this language*: a
  registered adapter yields `adapterNative` with no diagnostic; a missing one yields
  the shared fallback plus `adapterMissing`. `resolveControl(language, control)`
  answers the per-control question: an undeclared control on a registered adapter
  yields `shared` plus `controlUnsupported`.
- `LiveUiFallbackPolicy` makes the three gap cases independently configurable:
  `onMissingAdapter` and `onUnsupportedControl` default to `fallbackToShared`, while
  `onMissingDefaultAdapter` defaults to `failFast` — a registry that cannot even
  supply its fallback is a startup fault, surfaced as `LiveUiResolutionException`,
  never recovered silently.
- `LiveConfigProvider` performs the resolution **once per language change** and
  carries the verdict into `LiveTheme.adapter` / `implementationKind`, so a widget
  re-resolves nothing and a test can assert the decision. `adapterMissing` fires at
  most once per language change; a host's sink must not treat it as an error.
- Diagnostics reach a host-supplied `LiveUiDiagnosticSink` typedef; the core imports
  no logger.

The provider reports the language-wide gap once per language change, and — when the
language *does* have an adapter — resolves all ten controls through
`resolveControl` and reports each undeclared one once. So a host with a wired sink
learns which controls the active library draws from the shared renderer instead of
discovering it visually, and `controlUnsupported` is emitted where the decision is
made (§15.5). Rebuilds with the same language report nothing new; switching languages
re-reports for the new adapter. A host with no sink stays quiet, and a fail-fast policy
turns the same call into a loud fault rather than a report.

## 11. The shared token renderer

`SharedLanguageAdapter` is the base every language inherits and the fallback every
gap resolves to. Its `Token*` widgets (`TokenCard`, `TokenTextField`, `TokenSwitch`,
`TokenCheckbox`, `TokenSlider`, `TokenSegmented`, `TokenProgress`, `TokenSelect`,
`TokenTabs`) compose `LiveBox` + the resolved component tokens, honour the caller's
`focusNode`/`autofocus`, clamp values into range, treat a null callback as disabled,
and wrap an expanded button in a full-width box — the exact conventions adapters are
required to match, which is why adapters reuse `interactive()`, `buttonLabel()` and
`labelled()` instead of reimplementing them.

Four of those conventions are the renderer's own, not inherited from an adapter, and
each was verified by a test that first failed:

- The button renderer hands the caller's `style` to `LiveBox` as `inlineStyle`, so an
  override lands on top of `base ⊕ variant ⊕ size ⊕ state` instead of being dropped —
  `LiveButton` had been accepting `style:` and building a spec that could not carry it.
- `TokenTextField` paints the caller's `style` last, over the input component token —
  fill, radius, border, padding, margin, min/max width, alignment and opacity. Blur is
  a `LiveBox` effect and a field has no frosted state, so an inline `blur` on a field
  stays unpainted by design.
- `TokenSegmented` only stretches its labels when `expand` is set. `Expanded` claims
  the whole remaining width even under `MainAxisSize.min`, so a flex child is applied
  on the `expand` branch alone; otherwise `expand: false` looked identical to
  `expand: true`.
- `TokenTabs` treats `enabled` and a null callback as disabled: no tap handler, no
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

- `test/styling/live_ui_resolver_test.dart` covers dispatch: registered → native with
  no diagnostic; unregistered → shared plus `adapterMissing`; fail-fast → throws.
- `test/styling/live_config_provider_test.dart` covers the reporting surface: a partial
  adapter reports each undeclared control once and nothing more on rebuild, a language
  switch re-reports, a language with no adapter reports only `adapterMissing` (not the
  control set), and a host without a sink stays quiet.
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
- `test/styling/shared_renderer_test.dart` covers the `Token*` renderer the way the
  adapters are covered — every spec field either reaches the screen or the suite says
  so — plus a smoke pass that renders all ten controls with no adapter registered.
- `test/styling/live_environment_test.dart` covers the third axis: the breakpoint table
  (719 mobile, 720 desktop, TV outranking any width), the per-mode `Geometry` numbers and
  their token-derived radii, `LiveSizing`'s ladder and the rail/nav values `Geometry`
  repeats, `maybeOf`/`of` outside a builder, a resize re-resolving the same builder, and
  the grid's column count measured from tile positions at 420 and 1400. Its
  equality group asserts a change to *every* `Geometry` field is visible, and one test
  keeps a const subtree re-notified when only the radius moves — the case
  `LiveEnvironmentScope.updateShouldNotify` used to miss.
- The adapter suites carry the rest of the dispatch contract end to end, including a
  switch to the core base and back with caller-owned state preserved
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

- [x] Owns tokens, contracts, dispatch, diagnostics and the shared renderer; owns no
  application policy, persistence, navigation or state management.
- [x] Depends on no third-party UI library and on no adapter.
- [x] Every control has a token-driven default, and every default honours
  caller-owned controllers, focus nodes and inline style.
- [x] A language with no adapter renders and reports; a missing default adapter fails
  loudly.
- [x] `LiveUiControl`/`LiveUiCapabilities` are the single capability surface adapters
  declare against.
- [x] `controlUnsupported` is emitted from the render path, once per language
  change, and asserted there (§10).
- [x] `LiveIconButton` dispatches through the adapter like every other control, carrying
  `iconOnly`/`selected` on the spec (`docs/decisions/0004-…-adapter.md`): the shared
  `buttonLabel` makes textless rendering automatic for every adapter, and each spec's §9
  records that `selected` is mapped by the token base alone.
- [x] Token derivation, `Style` merge, recipes and the `Token*` renderer have their
  own tests (§14) — and the merge fix they forced (`merge` had been clearing the layer
  below, so no token-drawn control ever kept its base style through a state change) is
  asserted there.
- [x] `UiConfig.reduceTransparency` and the resolved `canBlur` are honoured by the core
  surfaces that blur (`LiveBox`, `LiveBackground`), with tests (§12/§14). Adapter-level
  library effects remain the open part (§12).
- [x] Every spec field a caller can set reaches a renderer or is recorded as unmappable:
  the button spec now carries `iconOnly`, `selected`, `tooltip` and `style`, the last of
  which `LiveButton` accepted but never forwarded (§9/§11).
- [x] The environment axis resolves from the window plus the declared form factor, is
  read by the grid and the state views, re-notifies on any `Geometry` change, and owns no
  separate widget set — with tests (§12/§14).
