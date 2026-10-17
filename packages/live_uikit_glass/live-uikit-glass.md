# `live_uikit_glass` Architecture and Integration Specification

- **Package:** `live_uikit_glass`
- **Parent package:** `live_uikit`
- **Implementation library:** `glass_morphism_plus`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_glass` is the Glass (glassmorphism) design-language adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into frosted-glass visuals drawn with `glass_morphism_plus`: that library's own widgets where it has them, its frosted surfaces and theme values composed into the shape the contract asks for where it does not. It must not implement business pages or duplicate the core theme system.

Glass differs from the other adapters in one load-bearing way: its signature visual — real-time blur, translucency, and backdrop filtering — is expensive to render. On devices that cannot afford it (low-end Android, Android TV), the adapter must substitute a verified degraded surface and report that through the core diagnostics contract rather than silently shipping an effect the device cannot produce. This document treats that effect budget as a first-class concern (§8, §13, §15).

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_glass
       |
       v
glass_morphism_plus
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `glass_morphism_plus` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **Glass owns glass visuals.** Use `glass_morphism_plus`'s own widgets wherever it has one, and compose the rest out of that library's own frosted surfaces and theme values rather than borrowing another library's shape.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from Glass to another style must not require business pages to import or construct different control classes.
6. **Effects are budgeted, not assumed.** Blur, transparency, and backdrop filters degrade to a verified solid/translucent surface when the environment cannot afford them, and every such downgrade is reported (§15).
7. **Honest capability set.** `glass_morphism_plus` is an early-version library (`^0.1.0`) with a narrow surface, so `glassCapabilities` declares all seventeen controls while only four of them are a library widget; the other thirteen are composed here from that same library's surfaces and theme values. The declaration is checked rather than trusted — `LiveUiResolver.requireControl` raises `LiveUiCapabilityException` for anything claimed without a matching override, and the architecture guard compares the set with the methods (§17).
8. **Faults are loud, effects are reported.** A control this adapter does not serve, or a surface it does not own, is a `LiveUiCapabilityException` rather than a quietly foreign-looking widget, and a language this build did not register is a `LiveUiResolutionException`; the only downgrade left to report is an effect the device cannot afford (§15).

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Glass theme mapping and the Glass theme scope.
- Construction of all seventeen controls of the contract from the core specifications: four with the library's own widgets, thirteen composed from its frosted surfaces and theme values.
- Glass-specific control defaults for the four mapped controls, and component-token geometry for the composed ones the library has no metrics for.
- Both structural surfaces: this language's own app host and the navigation shell this package composes.
- The frosted-surface effect budget: choosing a real blur or a verified degraded stand-in for the environment.
- Declaring the capabilities and surfaces the adapter actually serves, so the core resolver can check the claim.
- Adapter-level contract tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The multi-style selector UI.
- Shared design-token definitions.
- Global configuration storage.
- Riverpod, GetX, or other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Direct dependencies on other style adapters.
- Localization delegates (Glass adds none; see §14).

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts, tokens, resolver, diagnostics |
| `glass_morphism_plus` | Yes | Native frosted-glass widgets and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod / GetX / Bloc | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_cupertino` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_material` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

Current structure (real files):

```text
packages/
└── live_uikit_glass/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_glass.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── glass_adapter.dart
    │       │   ├── glass_capabilities.dart
    │       │   ├── glass_registration.dart
    │       │   └── glass_surfaces.dart
    │       ├── theme/
    │       │   ├── glass_theme_mapper.dart
    │       │   ├── glass_theme_builder.dart
    │       │   └── glass_theme_scope.dart
    │       └── widgets/
    │           ├── glass_app_bar_builder.dart
    │           ├── glass_button_builder.dart
    │           ├── glass_card_builder.dart
    │           ├── glass_checkbox_builder.dart
    │           ├── glass_dialog_builder.dart
    │           ├── glass_host_builder.dart
    │           ├── glass_list_row_builder.dart
    │           ├── glass_nav_bar_builder.dart
    │           ├── glass_progress_builder.dart
    │           ├── glass_scaffold_builder.dart
    │           ├── glass_segmented_builder.dart
    │           ├── glass_select_builder.dart
    │           ├── glass_shell_builder.dart
    │           ├── glass_slider_builder.dart
    │           ├── glass_switch_builder.dart
    │           ├── glass_tab_bar_builder.dart
    │           ├── glass_tab_view_builder.dart
    │           ├── glass_text_field_builder.dart
    │           └── glass_toast_builder.dart
    ├── live-uikit-glass.md
    └── test/
        ├── adapter/
        │   └── glass_contract_test.dart
        ├── theme/
        │   └── glass_theme_test.dart
        ├── widgets/
        │   ├── glass_native_controls_test.dart
        │   └── stub_router.dart
        └── integration/
            └── glass_style_switching_test.dart
```

The following are **optional and not-yet-created** — add them only as their functionality is implemented, never as empty placeholders:

```text
lib/src/interaction/     Glass focus and D-pad mapping for desktop and TV
lib/src/icons/           semantic icon -> glass icon mapping
lib/src/diagnostics/     Glass-specific effect-budget reporting
example/lib/main.dart    integration demo without business dependencies
```

### Module responsibilities

| Module | Responsibility | Status |
|---|---|---|
| `adapter/` | Adapter contract implementation, capability and surface declaration, registration | Present |
| `theme/` | Translate the resolved `DesignToken` into the Glass theme and install its scope | Present |
| `widgets/` | Build all seventeen controls from the core specifications, plus the app host and the composed shell | Present (one builder per control and one per surface) |
| `test/` | Verify contract compliance, the capability and surface declarations, and the rendered controls | Present |
| `interaction/` | Map keyboard, focus, and TV-specific behavior | Optional / not yet created |
| `icons/` | Map supported semantic icons to Glass icons | Optional / not yet created |
| `diagnostics/` | Report effects the environment cannot afford | Optional / not yet created |
| `example/` | Demonstrate integration without business dependencies | Optional / not yet created |

## 5. Package dependencies

Current `pubspec.yaml`:

```yaml
name: live_uikit_glass
description: Glass design-language adapter for live_uikit, rendering controls with glass_morphism_plus widgets.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  glass_morphism_plus: ^0.1.0
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

`glass_morphism_plus` is pinned at an early version (`^0.1.0`). Its API surface is intentionally narrow today — three surfaces, four controls, a theme and a Material `GlassAppBar`, in eight files — which is why four controls map onto a library widget here and thirteen are composed out of its frosted surfaces and theme values. Before merging, verify the resolved version against the workspace lockfile; a newer library that exposes a blur derived from the token, more controls, or effect-introspection APIs unlocks the phases in §18.

Because PureLive uses a Pub workspace, the `live_uikit` dependency is a workspace member resolved through the repository's path/workspace policy. Keep it aligned with the other adapters; do not version-pin the internal package independently.

The adapter must not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation.

## 6. Public API

The public entry point exposes only the registration API. No internal builders, mappers, theme scope, or third-party `glass_morphism_plus` types are exported.

Real entry point:

```dart
// lib/live_uikit_glass.dart
library;

export 'package:live_uikit_glass/src/adapter/glass_registration.dart';
```

`glass_registration.dart` provides the finalized core-contract symbols:

```dart
const String glassAdapterId = 'glass';
const LanguageAdapter glassAdapter = GlassLanguageAdapter();
LanguageAdapter createGlassAdapter() => const GlassLanguageAdapter();
```

Localization delegates are **not** exported and none are added; Glass relies on Flutter/core localization (§14). The theme scope and the nineteen builders — one per control, one for the app host, one for the shell — are implementation details reachable only through the adapter, never imported by callers.

## 7. Adapter contract

The adapter implements the finalized `live_uikit` contract `LanguageAdapter`, which is an `abstract interface class`: `GlassLanguageAdapter` implements it directly, there is no base class to extend, and every member is answered here. Every control of the contract and both structural surfaces come from this package's own builders — with `glass_morphism_plus`'s widget where the library has one and composed out of that library's own surfaces and theme values where it does not.

Real contract surface (from `live_uikit`):

```dart
abstract interface class LanguageAdapter {
  LiveDesignLanguage get language;
  String get id;
  String get displayName;
  LiveUiCapabilities get capabilities;
  LiveUiSurfaceCapabilities get surfaces;

  Widget wrap(BuildContext context, DesignToken token, Widget child);
  Widget button(BuildContext context, LanguageButtonSpec spec);
  Widget card(BuildContext context, LanguageCardSpec spec);
  Widget textField(BuildContext context, LanguageTextFieldSpec spec);
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec);
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec);
  Widget slider(BuildContext context, LanguageSliderSpec spec);
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec);
  Widget progress(BuildContext context, LanguageProgressSpec spec);
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec);
  Widget tabBar(BuildContext context, LanguageTabsSpec spec);
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec);
  Widget appBar(BuildContext context, LanguageAppBarSpec spec);
  Widget listRow(BuildContext context, LanguageListRowSpec spec);
  Widget navBar(BuildContext context, LanguageNavBarSpec spec);
  Widget toast(BuildContext context, LanguageToastSpec spec);
  Widget dialog(BuildContext context, LanguageDialogSpec spec);
  Widget tabView(BuildContext context, LanguageTabViewSpec spec);

  Widget appHost(BuildContext context, LanguageHostSpec spec);
  Widget shell(BuildContext context, LanguageShellSpec spec);
}
```

`GlassLanguageAdapter` overrides every one of those members — the five getters (`language`, `id`, `displayName`, `capabilities`, `surfaces`), `wrap`, the seventeen control builders, and the two surface builders — and delegates each control and surface to the matching file under `widgets/`.

```dart
class GlassLanguageAdapter implements LanguageAdapter {
  const GlassLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.glass;
  @override String get id => 'glass';
  @override String get displayName => 'Glass';
  @override LiveUiCapabilities get capabilities => glassCapabilities;
  @override LiveUiSurfaceCapabilities get surfaces => glassSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => GlassButtonBuilder.build(context, spec);
  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => GlassCardBuilder.build(context, spec);
  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => GlassTextFieldBuilder.build(context, spec);
  // …one override per remaining control, each handing the spec to its builder:
  // switchWidget, checkbox, slider, segmented, progress, select, tabBar,
  // scaffold, appBar, listRow, navBar, toast, dialog, tabView.
  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => GlassHostBuilder.build(context, spec);
  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => GlassShellBuilder.build(context, spec);
}
```

### Adapter identifier

Use one stable identifier everywhere:

```text
glass
```

The `id` (`glass`), the `glassAdapterId` constant, and `displayName` (`Glass`) are fixed. The identifier is machine-readable; do not use `glass_morphism_plus` or a platform-dependent value as the runtime style id.

### Capability declaration

`glassCapabilities` declares every control `GlassLanguageAdapter` overrides:

```dart
const LiveUiCapabilities glassCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.tabBar,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
  LiveUiControl.dialog,
  LiveUiControl.tabView,
});
```

The declaration says the adapter serves the control, not that a library widget exists for it. `glass_morphism_plus` ^0.1.0 is a surface library, so four controls are that library's own widgets and thirteen are composed from its sheets and theme values; each builder's doc comment records which of the two it is, and §9 lists them one by one.

| Control | How this adapter serves it | Realized as |
|---|---|---|
| Button | `GlassButton` with its content composed here | **Mapped** |
| Card | `GlassCard` | **Mapped** |
| Text field | `GlassTextField`, error caption composed | **Mapped** |
| List row | `GlassListTile` (+ `GlassDivider` when divided) | **Mapped** |
| Switch | `GlassContainer` track with a circular `GlassContainer` knob | **Composed** |
| Checkbox | `GlassContainer` box, ticked by tint and a token glyph | **Composed** |
| Slider | three `GlassContainer`s: rail, filled part, handle | **Composed** |
| Segmented | `GlassContainer` groove; the chosen segment on a brighter sheet | **Composed** |
| Progress | frosted groove with a solid fill, plus a sliding fill when indeterminate | **Composed** |
| Select | `GlassContainer` field with its option list as a second sheet in flow | **Composed** |
| Tab bar | `GlassContainer` sheet on the active tab plus the token's accent rule | **Composed** |
| Scaffold | one full-bleed `GlassContainer` sheet with its bars inside | **Composed** |
| App bar | floating `GlassContainer` sheet (`GlassAppBar` is not used; §9) | **Composed** |
| Nav bar | `GlassContainer` strip with a brighter sheet on the active destination | **Composed** |
| Toast | `GlassContainer` pill with the status glyph and message | **Composed** |
| Dialog | floating `GlassContainer` panel; the route and barrier stay the core's | **Composed** |
| Tab view | `PageView` on a `GlassContainer` sheet; the index stays the caller's | **Composed** |

The two structural surfaces are declared apart from the controls, in `glassSurfaces`, and this adapter owns both of them:

```dart
const LiveUiSurfaceCapabilities glassSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
```

`LiveUiControl` and `LiveUiSurface` are the source of truth for those two sets; do not add a parallel capability system. `LiveUiResolver.requireControl` and `requireSurface` throw `LiveUiCapabilityException` when a declaration claims something the adapter does not serve, and `LiveUiResolver.resolve` throws `LiveUiResolutionException` when this build registered no Glass adapter at all — there is no other implementation for either to settle for (§15).

## 8. Theme mapping

The core owns user preferences and resolves them into a `DesignToken`. The Glass adapter translates that token into a `glass_morphism_plus` theme and installs a scope around the subtree it builds.

The data flow is:

```text
LiveConfig
     |
     v
DesignToken
     |
     v
GlassThemeMapper.wrap(context, token, child)
     |
     v
GlassThemeScope
     |
     v
GlassThemeBuilder.build(token) -> glass.GlassThemeData
     |
     v
glass.GlassTheme  (frosted surface + controls)
```

`wrap` is the seam the resolver calls to install the theme, and `GlassLanguageAdapter.wrap` answers it with the frosted scope: `GlassThemeScope` around the subtree it is handed. The host spec carries no token of its own — `GlassHostBuilder` reads `LiveTheme.token` and installs the same scope inside the app so a route's overlay content resolves it too — so a preference change re-skins the host along with everything under it (§9).

### 8.1 Theme properties to map

| Core token concept | Glass mapping | Notes |
|---|---|---|
| Brightness | Surface tint from `token.color.bgContainer` | The token's dark/light answer reaches the sheet colour |
| Accent color | `theme.colors.primary` in the builders' own tints | Applied where a frosted sheet can carry it |
| Font family / text styles | The token's text roles in each builder | Map supported roles only |
| Density | Control padding from the token | Button padding is token-driven |
| **Blur radius** | `GlassThemeData(blur: 16)` | **The signature effect; the crux of §13/§15** |
| Translucency | Backdrop-filter surface | Must have a verified degraded stand-in |
| Focus / TV affordance | Not native to the current scope | Deferred to optional `interaction/` |

`GlassThemeBuilder.build` maps the surface the library does accept from a token: `color` from `token.color.bgContainer`, `borderRadius` from `token.scale.radii.lg`, and `shadowColor` from `token.color.shadowBase`. **`blur` stays a fixed `16`** — `glass_morphism_plus` `^0.1.0` exposes the radius as a plain double with no affordance introspection, so a token-driven blur cannot be verified and is not faked (§18 Phase 3). Note the consequence for accessibility: this library-level blur does not consult `LiveTheme.canBlur`, so `reduceTransparency` degrades the core's own surfaces and not the frosted adapter ones. Brightness is not a `GlassThemeData` field at all: the frosted surface reads what is behind it, so the token's dark/light intent arrives through the surfaces the builders paint, and no `brightness` flag is invented for it. Do not force every style library to use identical widget dimensions; the token defines shared intent, the Glass builder picks the closest frosted presentation the library supports.

### 8.2 Theme scope

The adapter installs the mapped theme via `glass.GlassTheme` around `child` (`GlassThemeScope`). Do not wrap the subtree in a competing application shell to apply the Glass style; a nested app widget introduces conflicting navigation, localization, and configuration. Use only the theme-scope mechanism the installed `glass_morphism_plus` version supports.

### 8.3 Runtime updates and effect invalidation

When the user changes brightness, accent, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `GlassLanguageAdapter.wrap` re-runs the mapper.
4. `GlassThemeScope` rebuilds the `GlassTheme`.
5. Existing business state remains owned by the business widgets and controllers.

The mapped `GlassThemeData` is rebuilt from the resolved token on every pass — its tint, radius and shadow follow the token, so it is never a `const` — and the composed builders read their blur, tint, opacity, radius and stroke back off `glass.GlassTheme.of(context)` rather than hardcoding them. The one value that does not follow the token is the blur radius, fixed at `16` by `GlassThemeBuilder` (§8.1); that is a library limitation, and it is not a licence to cache a scope permanently. Rebuild or invalidate the mapped theme whenever the resolved token changes, so the seam stays honest once the library exposes an affordance API (§18 Phase 3).

## 9. Control implementation rules

Each builder converts one core specification into this language's rendering of it: a `glass_morphism_plus` widget where the library has one, or that library's own frosted surfaces and theme values assembled into the shape the contract asks for where it does not. Builders must map semantic intent, never inspect business page types. Every builder's own doc comment states which of the two it is, and §15 records the spec fields it cannot express.

### Button (mapped to `GlassButton`)

`GlassButtonBuilder.build(context, spec)` renders a `glass.GlassButton`:

- Press eligibility is computed in the builder: enabled, not loading, and a callback — otherwise `onPressed` is null.
- Content is composed here from the library's parts: the label (ellipsised), an optional leading glyph, and the bare glyph of an icon-only button, whose empty label is never painted and whose tooltip becomes its `semanticLabel`.
- The loading state is a small frosted plate at the label step. The library ships no spinner, so the plate is built out of its own surface rather than borrowed from another.
- Horizontal padding is token-driven (`theme.button.paddingInline` plus the small step of the sizing scale) and passed through the library's own `padding`, not hand-wrapped. An icon-only button keeps that padding rather than squaring to `spec.size`, so its geometry is the text button's.
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` in the core's language-neutral `LiveTooltip`. `GlassButton` has no hint slot and no focus parameter, so `focusNode`/`autofocus` are recorded as unmappable (§15) rather than emulated with a second focus node that would not drive activation.
- `selected` is **not mapped**: this library gives its button no toggled affordance, and hand-painting one over it would be the overlay this section already refuses. A toggled button draws as an ordinary one, and the field is documented as unmappable here (the remainder of `docs/decisions/0004`).
- `style` is **not mapped** either. The button is the library's own widget and paints its own surface; applying a caller's `Style` would mean painting over it. The trade is the one recorded for `selected` (§15).
- No business action lives inside the builder.

### Card (mapped to `GlassCard`)

`GlassCardBuilder.build(context, spec)` renders a `glass.GlassCard`:

- A non-interactive card (`spec.onTap == null`) shows `spec.child` directly.
- An interactive card wraps the content in an opaque `GestureDetector` preserving `onTap` and `onLongPress`, so click behavior survives the frosted surface.
- Padding comes from the spec when supplied, otherwise the token padding, which the `dense` step tightens to two thirds of itself; `selected` and `bordered` have no frosted equivalent (the surface is translucent by definition) and are left to the library's own treatment rather than faked with an opaque outline (§15). The library exposes no focus slot or style slot either, so `focusNode`, `autofocus` and `style` are recorded as unmappable. Do not assume every card is interactive.

### Text field (mapped to `GlassTextField`)

`GlassTextFieldBuilder.build(context, spec)` renders a `glass.GlassTextField`:

- The caller's `controller` passes straight through; the builder never creates a second controller or silently owns lifecycle.
- `glass_morphism_plus` `^0.1.0` carries `hintText`, `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`, `textInputAction`, `prefixIcon`, `suffixIcon`, `focusNode`, `style`, `onChanged` and `onSubmitted`, so all of them pass through; the inline `Style` layers onto the token body text property by property, and an obscured field is held to one line whatever `maxLines` says.
- The one spec field the library cannot express is `errorText`: the builder draws a caption line in the token's error colour under the field, and the field keeps the library's own focus treatment rather than an approximation of a Material error border on a frosted surface (§15).

### List row (mapped to `GlassListTile`)

`GlassListRowBuilder.build(context, spec)` renders a `glass.GlassListTile`:

- The library's row carries the leading, title, subtitle and trailing slots the spec names, and the sheet, radius, blur and stroke are the library's inherited values.
- Two things the library hardcodes are handed back to the theme: its title and subtitle are styled white whatever the brightness, so each is wrapped in the token's text role; its own margin is kept, because a floating frosted row is what the surface is for.
- `selected` raises the sheet's opacity and takes the token's selected tint and accent border — the same way this adapter marks a choice everywhere. `divided` appends the library's own `GlassDivider`.
- A row with no callback stays inert rather than greyed: the library folds `enabled` into its Material row, which would dim labels the contract wants readable, so the nullability of the callbacks drives them instead.
- `focusNode` and `autofocus` have no slot: the row forwards no focus parameter, so a glass row is reached by the traversal around it (§15).

### Switch, checkbox, slider (composed sheets)

None of the three has a widget in this library, so each is a sheet with a sheet inside it, sized by its own component token because the library has no metrics for a control it does not ship.

- **Switch**: a `GlassContainer` track rounded to its own height, with a circular one for the knob. On means the track is tinted the primary colour at a raised opacity rather than filled opaque, so the page still reads through it; the knob skips the backdrop filter, because one blur for the whole control is the library's budget and a second inside the first would blur the track it sits on. The tap, the caller's focus node and the hover/press tint ride on the core's `LiveBox`, since handing the tap to `GlassContainer.onTap` would build a Material ink host with a focus node the spec could not reach (§15). Semantics reports `toggled`, never `checked` — announcing both asserts inside the render tree.
- **Checkbox**: a small `GlassContainer` whose radius, blur, tint and stroke are the theme's, checked by swapping that tint for the primary at a raised opacity, taking the accent border and dropping the token's tick into it. The label is the token's body role, because a glass surface says nothing about type. Tap and focus again ride on `LiveBox`.
- **Slider**: three `GlassContainer`s — a hairline rail that keeps the backdrop filter, a solid filled part and a circular handle that skip theirs, which is what keeps a drag from blurring the page three times over. Because a slider is dragged rather than tapped, its gesture layer is the widgets library's own `GestureDetector`; a `Focus` routes the spec's node and steps the value by a twentieth of the range on the arrow keys, and `Semantics` reports the number rather than the geometry.

### Segmented, tab bar, nav bar (selection on a brighter sheet)

Glassmorphism marks a selection with a lit surface rather than a filled shape, and these three all use that idiom: a `GlassContainer` carrying the choices, with the chosen one on a second, brighter sheet.

- **Segmented**: the groove is a sheet and only the active segment gets a pill; `expand` gives every segment an equal share of the row and the full width. A disabled group keeps its labels and stops reporting.
- **Tab bar**: the library has no tab widget, so the active tab is a raised sheet under the label, closed by a short accent rule along its bottom edge — a glass sheet cannot shade itself enough to carry a tab on its own, so the strip rules the accent as every language in this contract does. `spacing` maps to the gap between tabs, which this strip needs: the sheets are rounded, so adjacent tabs would otherwise read as one panel.
- **Nav bar**: one floating sheet holds the destinations and the active one sits on a brighter one inside it. Height and glyph size come from the layout geometry, or from `LiveSizing` when the environment supplies none. The library's only bar, `GlassAppBar`, is a Material `AppBar` under a frosted `flexibleSpace` and belongs to a Material frame, so it is not used here.

### Progress, select, toast (composed indicators, menus and messages)

- **Progress**: a frosted groove at the spec's height with a solid fill inside it (`isBlurEnabled: false` — one backdrop filter per bar is the library's budget), taking the primary colour or `barColor`, at full opacity so it reads as the lit part of the same sheet rather than a bar laid over it. `showLabel` puts the percentage beside it in the token's caption role. An indeterminate value has no library widget to lean on either — every spinner the library paints is Material's own — so the same frosted fill travels a third of the groove end to end on a loop, held at the leading edge when `UiConfig.animations` is off, because a device that cannot afford the motion should still show a bar (§13).
- **Select**: the library carries no dropdown. The field is a `GlassContainer` sheet with the chosen label (or the placeholder in the token's placeholder colour) and the token's chevron glyph; choosing opens the option list as a second frosted sheet *in flow*, under the field. It pushes the page rather than floating over it, which is the one behaviour a glass surface can do without taking the caller's overlay, and it is capped and scrollable so a long list cannot run the page off the screen (§15). The builder asserts nothing about `items`, so duplicate, null or off-list values draw as rows rather than throwing.
- **Toast**: the library has no message widget, so the pill is a `GlassContainer` sheet with the status glyph in the token's status colour and the message in its body role. Glass marks severity on the glyph and the tint rather than on a solid block, because a translucent surface cannot hold a Material-style colour band without ceasing to be glass. Only the surface is built here: the overlay it floats in, the fade and the removal timer belong to the core's `LiveToast.show`, which is why the spec's `duration` is not read by this builder.

### Scaffold and app bar (the page sheet and the header sheet)

- **Scaffold**: the library has no frame — `GlassAppBar` is its only structural widget and it is a Material bar — so the page is one full-bleed `GlassContainer` sheet blurring what the app paints behind it, which is the whole point of the language: a glass page is a lit panel over a background, not a colour. The dispatched bar sits above the content, or over it in a stack when `extendBodyBehindAppBar` asks for that reading; the bottom strip goes under; the floating action is pinned to the trailing corner inset by the page margin plus the open keyboard. `background` tints that sheet instead of replacing it, since a glass frame has no opaque side to swap. `avoidKeyboard` is answered with the view insets, because this frame is not a Material scaffold with a resize policy of its own. The frame paints no `Material` of its own: the library wraps an ink host inside any surface that takes a tap, and the page sheet takes none, so a frame that supplies no ink host is not one that crashes (§15).
- **App bar**: composed, and measured first. The library does have a `GlassAppBar`, but it is a Material `AppBar` with a frosted `flexibleSpace` pasted into it, and three things stop it being this contract's inline bar: it asserts `No MaterialLocalizations found.` outside a Material host; handed loose constraints it takes the whole window rather than its own toolbar height (measured: 800x600 where a bar is 56), because only a Material `Scaffold` sizes a `PreferredSizeWidget`; and its `bottom` slot wants a `PreferredSizeWidget` while the spec hands over whatever the caller dispatched — a tab strip is a `Row`. So the bar is the library's *surface* instead: a floating sheet squared along its bottom edge so it closes the header rather than hovering over it. `centerTitle` defaults to centred, because a glass header reads as an iOS-style sheet; a caller who wants the desktop reading passes `false`, and the title centres within the space the leading widget and the actions leave. `height` maps to the title row, `bottom` stacks under it, and `background` tints the sheet rather than replacing it.

### Dialog and tab view (surfaces the library has no widget for)

`glass_morphism_plus` 0.1.0 ships no dialog, no alert, no sheet and no page switcher: its whole set is `GlassContainer`, `GlassTile`, `GlassDivider`, `GlassButton`, `GlassCard`, `GlassTextField`, `GlassListTile` and a Material `GlassAppBar`.

- **Dialog**: the panel is assembled out of the library's own surface — a `GlassContainer` reading its blur, stroke and shadow from `glass.GlassTheme` and holding the glyph, heading, body and action row in the token's text roles, with its opacity floored so the barrier cannot show through the body text. iOS raises its alert as a single floating slab with the buttons inside it, so the actions stay a trailing row on the sheet rather than a separate band. Only the surface is built here: the route, the barrier colour, the fade-and-scale, the outside tap and the timeout belong to the core's `showLiveDialog`, which already frames what it is given, so this builder starts no `Navigator`, adds no `Center` of its own, and deliberately does not read `dismissible`, which is the core's barrier knob. The panel is not interactive, so it is the plain `GlassContainer`: the tappable variant wraps its child in its own `Material`/`InkWell` and gives away focus.
- **Tab view**: the view rides the framework's own `PageView` (from `package:flutter/widgets.dart`, so no Material renderer is borrowed) on a frosted sheet. The trade-off is stated because the languages differ on it: iOS swipes between tab pages and this language is the frosted reading of iOS, so the slide is kept; Fluent answers the same spec with an in-place cross-fade because Windows replaces a tab body without moving it. `onIndexChanged` is therefore honoured — swiping is allowed only where the caller can hear about it and there is more than one page — and `index` is followed by animating to it over `duration` rather than jumping, so a strip tap and a swipe read as one motion. The index stays the caller's.

### App host and shell (the two structural surfaces)

- **App host**: the library ships no application widget — it is a theme plus frosted surfaces, and nothing in it owns a route, a title or a locale — so `GlassHostBuilder` hosts the app on Flutter's own `WidgetsApp` with `GlassThemeScope` installed above the routed tree, and `color` taken from the theme's primary so the host's own chrome is on-theme. An app widget, not the controls, decides how a route slides in, which physics a scroll view obeys and where a dialog's modal barrier lives; `WidgetsApp` asks nothing of Material and gives nothing to it, so all three come from the widgets-layer defaults and the surface the barrier covers is the library's own frosted one. With no Material application widget above, the strings the composed controls and the library's own field ask for have to arrive through `LanguageHostSpec.localizationsDelegates`, which is why the composition root installs the core's delegates for every language up front (§14).
- **Shell**: the library ships no navigation structure either, so the column is composed out of the same pieces the nav bar and tab bar already use: one full-height frosted `GlassContainer` as the track and a brighter sheet behind the selected destination, with interaction on the core's `LiveBox` for the reason every composed glass control gives. `LiveShellPlacement` is honoured on the width the environment reports, so a narrow window switches form at the same width whichever language is active: `rail`, and an `adaptive` request with room for a pane, compose the column; `bottom` hands the strip back through this adapter's own `navBar`; `none`, or fewer than two destinations, gives the frame back to the page. `trailing` is pinned to the foot of the composed column, and the bottom form has no such slot, so it is dropped there rather than invented.

## 10. Runtime registration

The application composition root registers the adapter during startup, in the one place that knows which languages this build ships.

```dart
const appLanguageRegistry = LanguageRegistry(
  adapters: {LiveDesignLanguage.glass: glassAdapter},
);
```

`LanguageRegistry` takes the adapters map and nothing else. The composition root is responsible for registering the adapters included in the build, loading the user's style preference, selecting the active language (`UiConfig.language` is required), providing configuration persistence, and coordinating runtime theme changes. `live_uikit_glass` must not register itself through global static initialization or require the business layer to import it.

The const `glassAdapter` is available for hosts that prefer one shared const instance over calling `createGlassAdapter()`; both resolve to the same `GlassLanguageAdapter`.

### Registration and resolution failure

- **Glass selected with no adapter registered** — `LiveUiResolver.resolve` throws `LiveUiResolutionException`. There is no other implementation for the language to settle for, so this is a composition fault the app hears about at boot, not a degraded render (§7).
- **A control the declaration claims but the adapter does not serve** — `LiveUiResolver.requireControl` throws `LiveUiCapabilityException`; `requireSurface` does the same for the app host or the shell. Both are the assertion behind `glassCapabilities` and `glassSurfaces`, and the guard in §17 keeps the declarations honest so neither can fire in a shipped build.
- **An effect the device cannot afford** — the configuration asked for transparency the hardware cannot do, and the core reports `unsupportedEffect`, the only member `LiveUiDiagnosticCode` has, once when the answer changes; a verified degraded surface stands in (§13, §15).

Do not silently switch styles or swallow either exception.

## 11. Runtime style switching

A business widget uses the core API:

```dart
LiveButton(
  label: 'Save',
  onPressed: saveSettings,
)
```

It must not contain conditional style selection:

```dart
// Avoid style-specific branching in business packages.
if (style == 'glass') {
  // Build a Glass button.
} else {
  // Build another library's button.
}
```

The intended rendering flow:

```text
Business widget
      |
      v
LiveButton
      |
      v
LiveUiResolver + LanguageRegistry
      |
      v
Selected adapter
      |
      +---- Glass adapter (this package)
      +---- Fluent adapter
      +---- Material adapter
      +---- Other registered adapters
```

Switching to or from Glass changes rendering and the effect budget, but must not replace business controllers, reset form values, or recreate unrelated application services. A page that mixes this library's own widgets with the sheets this package composes — a `GlassButton` beside a composed frosted switch — is restyled entirely by another adapter, and the page changes no line to get there.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms, so Glass styling must be tested for more than mouse input.

The builders preserve the specification's focus affordances wherever the library or the composed control exposes a route for them: `GlassTextField` takes the caller's `FocusNode`, and the composed switch and checkbox carry it — plus `autofocus` — on the core's `LiveBox`, while the composed slider wraps the whole track in a `Focus` of its own and steps the value on the arrow keys. `GlassButton`, `GlassCard` and `GlassListTile` forward no focus parameter at all, so the focus fields on those specs are recorded as unmappable here (§15), and the segmented, tab bar, nav bar and select specs carry no focus field to map. The adapter should account for:

- Keyboard navigation and focus traversal.
- Visible focus indication on the frosted surface (contrast against a translucent background is harder to guarantee than on opaque surfaces).
- Enter and Space activation semantics.
- Disabled controls being skipped or handled correctly.
- Focus restoration after dialogs or menus.
- Remote-control D-pad navigation on Android TV.
- Predictable focus behavior after runtime style switching.

Dedicated focus and D-pad mapping is **not yet implemented**; it belongs to the optional `interaction/` module (§4). Until it exists, rely on the core interaction policy and on the focus each builder routes for itself, and do not claim TV focus parity without tests. Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility — test the actual controls with supported TV input devices.

## 13. Platform behavior

Glass is a visual style choice. Its defining effect — real-time blur and backdrop filtering — has a **different cost budget on each platform**, and the adapter must degrade it explicitly rather than ship an unaffordable effect.

| Platform | Expected behavior | Effect budget |
|---|---|---|
| Windows | Frosted Glass with desktop keyboard and mouse | Real blur affordable on typical desktop GPUs |
| macOS | Frosted Glass with appropriate macOS integration | Real blur affordable |
| Linux | Frosted Glass; verify platform rendering and dependencies | Real blur usually affordable; verify |
| Android | Frosted Glass with touch-friendly sizing | **High-end only; low-end devices must degrade** |
| Android TV | Frosted Glass plus explicit D-pad and focus testing | **Blur often unaffordable; degrade** |
| iOS | Frosted Glass with iOS lifecycle and accessibility behavior | Real blur affordable |

When the environment cannot afford real-time blur or backdrop filtering — commonly low-end Android and Android TV — the adapter substitutes a **verified degraded surface** (a solid or translucent stand-in that reads as the same design without live backdrop sampling) and reports `unsupportedEffect` through the core's `LiveUiDiagnostic` contract (§15). A degraded surface must be a deliberate, tested presentation, never an accidental visual glitch or a frozen backdrop. `glass_morphism_plus` `^0.1.0` exposes only a fixed frosted surface, so effect introspection and the degrade decision are gated on the library growing an affordance API; until then, treat blur affordability as an environment assumption to be verified per platform, and never make native window or system-compositing APIs a required dependency of the basic adapter. Nothing else about a Glass page is environment-dependent: the controls it draws and the host it sits in are this package's own on every platform in the table (§7).

## 14. Localization and accessibility

Glass adds **no** localization delegates. It relies entirely on Flutter and core localization configured by the application composition root, and must not introduce a second, conflicting locale source or override the global locale independently.

The host does still have to be *given* them. `GlassHostBuilder` hosts the app on `WidgetsApp`, so with no Material application widget above the routed tree, the strings the composed controls and the library's own text field ask for arrive only through `LanguageHostSpec.localizationsDelegates` — which is why the composition root installs `liveLocalizationsDelegates` there for every language (§9).

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints on every control, mapped or composed.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast against translucent surfaces, and touch target sizing.

Because frosted surfaces reduce contrast, verify text legibility over both the real-blur and degraded-surface presentations on each target platform.

## 15. Error handling and diagnostics

The adapter reports structured diagnostics through the core `LiveUiDiagnostic` contract, delivered to a host-supplied `LiveUiDiagnosticSink`. It must not depend on Talker or another concrete logging package.

Each `LiveUiDiagnostic` carries the `language`, a `LiveUiDiagnosticCode`, and — when the event concerns one thing rather than the whole window — the `control` or the `surface` it names. `unsupportedEffect` is the only member that code has: it reports what the *device* cannot afford. A language with no adapter, a control an adapter declares but does not serve, and a surface it does not own are not events to log; they are faults the resolver raises.

| Situation | How it surfaces | Shape |
|---|---|---|
| Blur/translucency/backdrop filter is unaffordable | `unsupportedEffect` on the sink, once when the answer flips | `control` and `surface` both null — environment-wide |
| Glass selected with no adapter registered | `LiveUiResolutionException` thrown by `LiveUiResolver.resolve` | a boot fault, never a diagnostic |
| A declared control or surface has no override behind it | `LiveUiCapabilityException` thrown by `requireControl` / `requireSurface` | names the control or the surface |

The two expectations that matter for Glass:

- **Capability claims are checked, not reported.** `glassCapabilities` declares all seventeen controls and `glassSurfaces` declares both surfaces, so a run that resolves Glass has nothing to announce — no control and no structural surface of the contract is answered by another adapter. The contract and integration tests assert precisely that emptiness (§16), and §17's guard compares both sets against the methods `GlassLanguageAdapter` overrides, so a drifted declaration fails CI instead of throwing in front of a user.
- **Effect downgrades must be visible.** When real-time blur is replaced by a degraded surface (§13), the host receives `unsupportedEffect` with both `control` and `surface` null so it reads as an environment-wide visual change, and the presentation that stood in is the documented one.

Expected behavior:

- An effect the environment cannot afford has a documented degraded presentation.
- Invalid control data follows core validation rules.
- Programming errors are not swallowed.
- Diagnostics never log user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Unit / contract tests

The existing `test/adapter/glass_contract_test.dart` verifies, through the real `LanguageRegistry` and `LiveUiResolver`:

- Stable `id` (`glass`), `displayName` (`Glass`), and `language` (`LiveDesignLanguage.glass`).
- `glassCapabilities` lists **exactly** the seventeen controls of the contract, and `LiveUiControl.values.toSet()` is the whole set — so a control added to the contract cannot go undeclared here.
- `glassSurfaces` lists both structural surfaces, checked the same derived way against `LiveUiSurface.values`.
- `resolve(glass)` hands back this adapter, and `requireControl` passes for every member of `LiveUiControl` — the assertion behind the declaration.
- A language this build did not register throws `LiveUiResolutionException` rather than resolving to somebody else's adapter.

Extend with:
- Effect-budget behavior once the library exposes affordance introspection (assert `unsupportedEffect` on a simulated low-budget environment).
- `requireControl`/`requireSurface` throwing `LiveUiCapabilityException`, which today can only be provoked against a deliberately short declaration.

### Widget tests (`test/widgets/glass_native_controls_test.dart`)

Every control is driven through the real dispatch path (`LiveConfigProvider` + `LanguageRegistry` + the `Live*` widgets), so what is asserted is what this adapter renders:

- Button: callback when enabled, input rejected while loading, and `expand` plus
  `tooltip` wrapped around the frosted control.
- Card: reporting the tap, keeping the token padding and the `dense` step, and gaining no
  gesture layer while it is not interactive. `onLongPress` is wired through the wrapper,
  but no test drives it yet.
- Text field: the caller's controller passing through with `onChanged` firing, placeholder,
  prefix, disabled state and the error caption reaching the library's field (§9), and the
  caller's `FocusNode` being the node that takes focus.
- The composed controls: a switch as a track sheet plus a knob sheet that reports its value
  and stops reporting when disabled; a checkbox with its tick and its label; a slider of
  three sheets that drags and reports; a segmented track where only the chosen label gets
  the brighter pill; a determinate groove with its percentage, and an indeterminate one
  that travels without borrowing a Material indicator; a select whose option list opens in
  flow and hands back a typed value; a tab strip that rules its active label; a destination
  strip that selects on a brighter sheet and refuses taps when disabled; and a toast drawn
  as a frosted pill inside the core's overlay, with the removal timer still the core's.
- The chrome: a page frame as one sheet with its bars inside it, a header taking its title,
  actions and dispatched strip while drawing no Material `AppBar`, and a row rendered by
  `GlassListTile` with both lines, its divider and its tap.
- The whole contract on one page: frame, header, strip, field, and the composed controls all
  resolve through Glass with no exception.
- The app shell: the composed rail, its `trailing` footer, a disabled destination kept in
  the layout but refused, the bottom form handed to `navBar` with the footer dropped, and a
  single destination giving the frame back to the page.
- The app host: pumped with no Material app above it, the tree is hosted by `WidgetsApp`
  under `glass.GlassTheme`, and no `MaterialApp` stands in.
- The overlay and the page switcher: a dialog as a frosted panel inside the core's route,
  and a tab view that slides to the caller's index on a frosted sheet.
- `test/theme/glass_theme_test.dart` covers the scope the builders sit in: panel tint,
  radius and shadow follow the token, the blur is a fixed library effect rather than a
  token value (§8.1), and a brightness change re-skins through `wrap`.

Not covered: accessibility semantics and contrast on real-blur versus degraded surfaces,
layout under narrow and wide constraints, and the effect-budget path — the library exposes
no affordance to introspect (§15) and there is still no `interaction/` directory.

### Integration tests (`test/integration/glass_style_switching_test.dart`)

- Every `LiveUiControl` and both `LiveUiSurface` members resolve to this adapter, and `requireControl`/`requireSurface` pass for all of them.
- A Glass run's diagnostic sink names no control and no surface: nothing in the contract is answered by another adapter (§15).
- Re-themeing through this language removes and restores none of `glass.GlassButton`/`GlassCard`/`GlassTextField`, keeps the composed progress bar rendered, and leaves the caller's controller text intact.
- `unsupportedEffect` for a simulated unaffordable device stays open: it needs the affordance detection §18 Phase 3 blocks on.

A cross-adapter switch (this language against Fluent, Material, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. The blur-budget claim (§13) requires at minimum a real-blur target (Windows/macOS), a mobile target, and an Android TV / low-end Android target to prove the degraded-surface path actually renders and reports.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_glass` depends on `live_uikit` and `glass_morphism_plus` only for its core integration.
- `live_uikit_glass` does not depend on other style adapters (`live_uikit_fluent`, `live_uikit_cupertino`, `live_uikit_macos`, `live_uikit_material`, `live_uikit_neumorphic`, `live_uikit_wind`).
- The core package does not depend on `glass_morphism_plus`.
- Business packages do not import `package:glass_morphism_plus/...`.
- All public exports are intentional (only the registration API).
- The declared `glassCapabilities` matches the control methods `GlassLanguageAdapter` actually overrides, and `glassSurfaces` matches the two surface methods it overrides — declaring a control with no builder behind it, or overriding one it does not declare, fails the gate (§7, §15).
- Every `package:glass_morphism_plus/` import inside this package uses the `as glass` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `glassCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands (run from the workspace root with the repository's normal Flutter SDK and workspace resolution):

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_glass
flutter analyze packages/live_uikit_glass
flutter test packages/live_uikit_glass
```

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Adapter aligns with the finalized core contract, the stable id `glass`, the seventeen-control capability set, the two-surface declaration, and the registration symbols.
- The contract test asserts id/displayName/language, that `glassCapabilities` is the whole `LiveUiControl` enum and `glassSurfaces` the whole `LiveUiSurface` enum, that every control and surface passes `requireControl`/`requireSurface`, and that a language this build did not register raises `LiveUiResolutionException`. **Done.**

### Phase 2 — Theme integration ✅

- `GlassThemeMapper` / `GlassThemeScope` / `GlassThemeBuilder` install the frosted surface `wrap` is handed, with its tint, radius and shadow derived from the resolved token and its blur held at the library's own constant (§8.1).
- `wrap` is the seam that carries the resolved `DesignToken`, so a blur radius taken from the token can drop into `GlassThemeBuilder` later without any caller changing.
- Test scope installation and theme invalidation on token change.

### Phase 3 — Effect budget (blocked on library)

- Add environment affordance detection and the verified degraded-surface path.
- Report `unsupportedEffect` on unaffordable platforms (low-end Android, Android TV).
- Blocked until `glass_morphism_plus` exposes blur/affordance introspection beyond the fixed surface.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: every builder preserves the caller's state and carries the spec fields its library widget or its composed sheets can express (§9), asserted in `test/widgets/`.
- Open, needs hardware: focus visibility on translucent surfaces and Android TV D-pad.
- Implement the optional `interaction/` module for keyboard, focus visibility on translucent surfaces, and Android TV D-pad.
- Validate semantics and contrast on both real-blur and degraded surfaces.
- Documented: the spec fields a library widget has no slot for are named where they fail — `focusNode`/`autofocus` and `style` on the button, the focus slots on card and list row, and `errorText`, which the field builder draws as a caption instead (§9, §15).

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Open: integration tests for style switching and the effect-degrade path.
- Verify all claimed platforms against their effect budgets.
- Document known limitations (four controls are the library's own widgets and thirteen are composed from its sheets; the blur stays a library constant until the library can report what the device affords).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `glass_morphism_plus` only for its core integration.
- [x] It implements the core adapter contract directly: `LanguageAdapter` is an `abstract interface class` and `GlassLanguageAdapter` implements it with no base class beneath it.
- [x] It uses the stable adapter ID `glass` and displayName `Glass`.
- [x] It declares all seventeen `LiveUiControl` members in `glassCapabilities` and both `LiveUiSurface` members in `glassSurfaces`, and overrides a builder for every one of them.
- [x] The four controls the library ships as widgets map onto `GlassButton`, `GlassCard`, `GlassTextField` and `GlassListTile`; the other thirteen are composed from this library's own frosted surfaces and theme values, and each builder's doc comment says which.
- [x] It maps the resolved `DesignToken` into the Glass theme and installs a `GlassTheme` scope via `wrap`.
- [x] It uses `glass_morphism_plus`'s own widgets where the library has one and composes its frosted sheets where it does not, without faking a spec field either form has no slot for.
- [ ] Blur/translucency degrade to a verified surface on unaffordable platforms, reported via `unsupportedEffect`.
- [x] It adds no localization delegates and uses core localization.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, contrast, and TV focus behavior are tested once `interaction/` exists — the caller's node reaching `GlassTextField`'s focus tree is now proven (§16), but there is no `interaction/` directory, no semantics assertion, and no effect-budget degradation to verify while the library exposes no affordance (§15).
- [x] Diagnostics use the core `LiveUiDiagnostic` / `LiveUiDiagnosticSink` contract, and the only code it can carry — `unsupportedEffect` — is the only downgrade this adapter reports.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual per-effect-budget tests.

## 20. Final architecture decision

`live_uikit_glass` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model (`LiveConfig` → `DesignToken`), and runtime selection (`LiveUiResolver` + `LanguageRegistry`); a language with no registered adapter or a capability an adapter does not serve is raised as a fault rather than rendered by somebody else.
- `live_uikit_glass` maps those contracts to glassmorphism: it implements `LanguageAdapter` outright, and answers `wrap`, all seventeen controls and both structural surfaces with this package's own code.
- `glass_morphism_plus` supplies the underlying frosted widgets and theme facilities — a narrow, early-version (`^0.1.0`) surface, which is why only four controls are that library's own widgets and thirteen are composed here from its sheets and theme values.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

The defining Glass concern — real-time blur and translucency — is treated as a budgeted effect: it renders where the device can afford it, degrades to a verified surface where not, and that downgrade is announced through the core's `LiveUiDiagnostic` contract rather than happening silently. Everything else the contract asks for is answered outright, so a Glass page never renders a control through another design language. This separation lets PureLive add or replace UI styles, and adjust the effect budget per device, without forcing business packages to know which library is rendering their controls or whether the current device can afford a frosted surface.
