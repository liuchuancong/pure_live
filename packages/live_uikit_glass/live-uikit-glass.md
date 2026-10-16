# `live_uikit_glass` Architecture and Integration Specification

- **Package:** `live_uikit_glass`
- **Parent package:** `live_uikit`
- **Implementation library:** `glass_morphism_plus`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_glass` is the Glass (glassmorphism) design-language adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into frosted-glass visuals drawn with `glass_morphism_plus` widgets. It must not implement business pages or duplicate the core theme system.

Glass differs from the other adapters in one load-bearing way: its signature visual — real-time blur, translucency, and backdrop filtering — is expensive to render. On devices that cannot afford it (low-end Android, Android TV), the adapter must fall back to a verified degraded surface and report that downgrade through the shared diagnostics contract rather than silently shipping an effect the device cannot produce. This document treats that effect budget as a first-class concern (§8, §13, §15).

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
2. **Glass owns glass visuals.** Use native `glass_morphism_plus` widgets wherever practical rather than drawing frosted surfaces from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from Glass to another style must not require business pages to import or construct different control classes.
6. **Effects are budgeted, not assumed.** Blur, transparency, and backdrop filters degrade to a verified solid/translucent surface when the environment cannot afford them, and every such downgrade is reported (§15).
7. **Honest capability set.** `glass_morphism_plus` is an early-version library (`^0.1.0`) with a narrow surface, so only three controls are native. The rest fall back to the shared token renderer and are reported by the resolver, not pretended to be native.
8. **Graceful fallback.** Unsupported controls follow the fallback policy defined by `live_uikit`; they never silently change behavior.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Glass theme mapping and the Glass theme scope.
- Construction of the three natively supported controls from core specifications.
- Glass-specific control defaults for button, card, and text field.
- The frosted-surface effect budget: choosing a real blur or a verified degraded stand-in for the environment.
- Reporting implemented capabilities to the core registry.
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
    │       │   └── glass_registration.dart
    │       ├── theme/
    │       │   ├── glass_theme_mapper.dart
    │       │   ├── glass_theme_builder.dart
    │       │   └── glass_theme_scope.dart
    │       └── widgets/
    │           ├── glass_button_builder.dart
    │           ├── glass_card_builder.dart
    │           └── glass_text_field_builder.dart
    ├── live-uikit-glass.md
    └── test/
        ├── adapter/
        │   └── glass_contract_test.dart
        ├── theme/
        │   └── glass_theme_test.dart
        ├── widgets/
        │   └── glass_native_controls_test.dart
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
| `adapter/` | Adapter contract implementation, capability declaration, registration | Present |
| `theme/` | Translate the resolved `DesignToken` into the Glass theme and install its scope | Present |
| `widgets/` | Build the three native controls from core specifications | Present (button, card, text field) |
| `test/` | Verify contract compliance and capability declarations | Present |
| `interaction/` | Map keyboard, focus, and TV-specific behavior | Optional / not yet created |
| `icons/` | Map supported semantic icons to Glass icons | Optional / not yet created |
| `diagnostics/` | Report unsupported effects and adapter errors | Optional / not yet created |
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

`glass_morphism_plus` is pinned at an early version (`^0.1.0`). Its API surface is intentionally narrow today — a fixed frosted surface and a small widget set — which is precisely why only button, card, and text field are native in this adapter. Before merging, verify the resolved version against the workspace lockfile; a newer library that exposes token-driven blur, more controls, or effect-introspection APIs unlocks the phases in §18.

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

Localization delegates are **not** exported and none are added; Glass relies on Flutter/core localization (§14). The theme scope and the three widget builders are implementation details reachable only through the adapter, never imported by callers.

## 7. Adapter contract

The adapter implements the finalized `live_uikit` contract `LanguageAdapter`, extending the token-driven base `SharedLanguageAdapter` so unoverridden controls still render on-theme.

Real contract surface (from `live_uikit`):

```dart
abstract interface class LanguageAdapter {
  LiveDesignLanguage get language;
  String get id;
  String get displayName;
  LiveUiCapabilities get capabilities;

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
}
```

`GlassLanguageAdapter` overrides only `language`, `id`, `displayName`, `capabilities`, `wrap`, `button`, `card`, and `textField`. The remaining control methods are inherited unchanged from `SharedLanguageAdapter` and route to the shared token renderer.

```dart
class GlassLanguageAdapter extends SharedLanguageAdapter {
  const GlassLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.glass;
  @override String get id => 'glass';
  @override String get displayName => 'Glass';
  @override LiveUiCapabilities get capabilities => glassCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => GlassButtonBuilder.build(context, spec, this);
  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => GlassCardBuilder.build(context, spec);
  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => GlassTextFieldBuilder.build(context, spec);
}
```

### Adapter identifier

Use one stable identifier everywhere:

```text
glass
```

The `id` (`glass`), the `glassAdapterId` constant, and `displayName` (`Glass`) are fixed. The identifier is machine-readable; do not use `glass_morphism_plus` or a platform-dependent value as the runtime style id.

### Capability declaration

`glassCapabilities` reports only the controls the adapter actually overrides:

```dart
const LiveUiCapabilities glassCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
});
```

| Control | Implementation | Kind |
|---|---|---|
| Button | Native `GlassButton` | **Native** |
| Card | Native `GlassCard` | **Native** |
| Text field | Native `GlassTextField` | **Native** |
| Switch | Shared token renderer (`TokenSwitch`) | Shared fallback |
| Checkbox | Shared token renderer (`TokenCheckbox`) | Shared fallback |
| Slider | Shared token renderer (`TokenSlider`) | Shared fallback |
| Segmented | Shared token renderer (`TokenSegmented`) | Shared fallback |
| Progress | Shared token renderer (`TokenProgress`) | Shared fallback |
| Select | Shared token renderer (`TokenSelect`) | Shared fallback |
| Tab bar | Shared token renderer (`TokenTabs`) | Shared fallback |

Exactly three controls are `Native` and seven are `Shared` fallback. The core's `LiveUiControl` enum and `LiveImplementationKind` (`adapterNative`, `shared`, `custom`) are the source of truth; do not add a parallel capability system. Because only three controls are native, the other seven render via the shared token renderer and are reported by the resolver as `controlUnsupported` — an expected, announced downgrade, never a silent one (§15).

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

`wrap` is the seam the resolver calls to install the theme; the base `SharedLanguageAdapter.wrap` returns `child` unchanged, and `GlassLanguageAdapter.wrap` replaces it with the frosted scope.

### 8.1 Theme properties to map

| Core token concept | Glass mapping | Notes |
|---|---|---|
| Brightness | Glass surface tint | Fixed frosted surface today |
| Accent color | Glass surface / content color | Applied where the library allows |
| Font family / text styles | Inherited Flutter text styling | Map supported roles only |
| Density | Control padding from the token | Button padding is token-driven |
| **Blur radius** | `GlassThemeData(blur: 16)` | **The signature effect; the crux of §13/§15** |
| Translucency | Backdrop-filter surface | Must have a verified degraded stand-in |
| Focus / TV affordance | Not native to the current scope | Deferred to optional `interaction/` |

`GlassThemeBuilder.build` maps the surface the fork does accept from a token: `color` from `token.color.bgContainer`, `borderRadius` from `token.scale.radii.lg`, and `shadowColor` from `token.color.shadowBase`. **`blur` stays a fixed `16`** — `glass_morphism_plus` `^0.1.0` exposes the radius as a plain double with no affordance introspection, so a token-driven blur cannot be verified and is not faked (§18 Phase 3). Note the consequence for accessibility: this library-level blur does not consult `LiveTheme.canBlur`, so `reduceTransparency` degrades the core's own surfaces and not the frosted adapter ones. Brightness is not a `GlassThemeData` field at all: the frosted surface reads what is behind it, so the token's dark/light intent arrives through the surfaces the builders paint, and no `brightness` flag is invented for it. Do not force every style library to use identical widget dimensions; the token defines shared intent, the Glass builder picks the closest frosted presentation the library supports.

### 8.2 Theme scope

The adapter installs the mapped theme via `glass.GlassTheme` around `child` (`GlassThemeScope`). Do not wrap the subtree in a competing application shell to apply the Glass style; a nested app widget introduces conflicting navigation, localization, and configuration. Use only the theme-scope mechanism the installed `glass_morphism_plus` version supports.

### 8.3 Runtime updates and effect invalidation

When the user changes brightness, accent, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `GlassLanguageAdapter.wrap` re-runs the mapper.
4. `GlassThemeScope` rebuilds the `GlassTheme`.
5. Existing business state remains owned by the business widgets and controllers.

Because the current `GlassThemeData` is a fixed constant, theme changes may not visibly alter the frosted surface yet; that is a library limitation, not a license to cache a scope permanently. Rebuild or invalidate the mapped theme whenever the resolved token changes so the seam stays honest once token-driven effects exist.

## 9. Control implementation rules

Each native builder converts a core specification into a `glass_morphism_plus` widget. Builders must map semantic intent, never inspect business page types.

### Button (native)

`GlassButtonBuilder.build(context, spec, seam)` renders a `glass.GlassButton`:

- Press eligibility comes from the shared seam (`seam.interactive(spec)`): enabled, not loading, has a callback; otherwise `onPressed` is null.
- Content comes from the shared seam (`seam.buttonLabel(spec, theme)`), preserving label, icon, and loading spinner.
- Horizontal padding is token-driven (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`) and passed through the fork's own `padding`, not hand-wrapped.
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` in the core's language-neutral `LiveTooltip`. `GlassButton` has no hint slot and no focus parameter, so `focusNode`/`autofocus` are recorded as unmappable (§15) rather than emulated with a second focus node that would not drive activation.
- No business action lives inside the builder.
- `iconOnly` needs no builder code: the shared `buttonLabel` returns the glyph alone
  (with the tooltip as its `semanticLabel`), so a textless button built by
  `LiveIconButton` arrives here already correct.
- `selected` is **not mapped by this adapter today**. The token base tints a toggled
  button with the primary foreground; reproducing that here needs this library's own
  selected affordance rather than a hand-painted overlay on its button. Recorded as the
  documented remainder of `docs/decisions/0004` (§15).
- `style` is **not mapped by this adapter either**. Its button is the library's own
  widget and paints its own surface; applying a caller's `Style` to it would mean
  hand-painting an overlay over that widget, the trade this section already refuses
  for `selected`. The shared token renderer does honour the field, so a language with
  no native button keeps the override (`live-uikit.md` §11).

### Card (native)

`GlassCardBuilder.build(context, spec)` renders a `glass.GlassCard`:

- A non-interactive card (`spec.onTap == null`) shows `spec.child` directly.
- An interactive card wraps the content in an opaque `GestureDetector` preserving `onTap` and `onLongPress`, so click behavior survives the frosted surface.
- Padding comes from the spec when supplied, otherwise the token padding with the `dense` step applied; `selected` and `bordered` have no frosted equivalent (the surface is translucent by definition) and are left to the library's own treatment rather than faked with an outline (§15). Do not assume every card is interactive.

### Text field (native, partial)

`GlassTextFieldBuilder.build(context, spec)` renders a `glass.GlassTextField`:

- The caller's `controller` passes straight through; the builder never creates a second controller or silently owns lifecycle.
- `glass_morphism_plus` `^0.1.0` carries `hintText`, `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`, `textInputAction`, `prefixIcon`, `suffixIcon`, `focusNode`, `style`, `onChanged` and `onSubmitted`, so all of them pass through; the inline `Style` layers onto the token body text property by property.
- The one spec field the library cannot express is `errorText`: it draws a caption line in the token error colour under the field, exactly as the token renderer draws it, rather than approximating a Material error border on a frosted surface (§15).

### Switch, checkbox, slider, segmented, progress, select, tab bar (shared fallback)

These seven controls are **not** overridden. They inherit `SharedLanguageAdapter` and render through the token renderer (`TokenSwitch`, `TokenCheckbox`, `TokenSlider`, `TokenSegmented`, `TokenProgress`, `TokenSelect`, `TokenTabs`). The resolver reports a `controlUnsupported` diagnostic for each under the Glass language (§15) so the fallback is visible in tests and telemetry. Value/callback/range semantics are preserved by the shared renderer; no persistent local state is introduced.

## 10. Runtime registration

The application composition root registers the adapter during startup through the core `LanguageRegistry`.

```dart
void registerUiAdapters(LanguageRegistry registry) {
  registry.register(createGlassAdapter());
}
```

The composition root is responsible for registering the adapters included in the build, loading the user's style preference, selecting the active language, providing configuration persistence, and coordinating runtime theme changes. `live_uikit_glass` must not register itself through global static initialization or require the business layer to import it.

The const `glassAdapter` is available for hosts that prefer a shared instance over `createGlassAdapter()`; both resolve to the same `GlassLanguageAdapter`.

### Registration and resolution failure

The core `LiveUiResolver` and `LanguageRegistry` detect, via `LiveUiDiagnosticCode`:

- `adapterMissing` — Glass selected but no adapter registered; controls resolve to the shared renderer, reported once per language change.
- `defaultAdapterMissing` — the registry cannot supply even the shared fallback for the default language; a startup fault, never recovered silently.
- `controlUnsupported` — the adapter does not declare a control (the seven fallback controls); resolves shared for just that control.
- `unsupportedEffect` — the environment cannot afford blur/translucency; a verified degraded surface stands in (§13, §15).

When Glass is unavailable, the core fallback policy chooses an available implementation or reports a clear error. Do not silently switch styles outside that policy.

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

Switching to or from Glass changes rendering and the effect budget, but must not replace business controllers, reset form values, or recreate unrelated application services. Because only three controls are native, a business page can show a native frosted button next to a token-rendered switch simultaneously; switching to another adapter restyles both without the page changing a line.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms, so Glass styling must be tested for more than mouse input.

The three native builders preserve the specification's focus affordances where they exist — `focusNode` and `autofocus` are carried on button and card specs, and the shared renderer handles focus for the fallback controls. The adapter should account for:

- Keyboard navigation and focus traversal.
- Visible focus indication on the frosted surface (contrast against a translucent background is harder to guarantee than on opaque surfaces).
- Enter and Space activation semantics.
- Disabled controls being skipped or handled correctly.
- Focus restoration after dialogs or menus.
- Remote-control D-pad navigation on Android TV.
- Predictable focus behavior after runtime style switching.

Dedicated focus and D-pad mapping is **not yet implemented**; it belongs to the optional `interaction/` module (§4). Until it exists, rely on the core interaction policy and the shared renderer's focus handling, and do not claim TV focus parity without tests. Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility — test the actual controls with supported TV input devices.

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

When the environment cannot afford real-time blur or backdrop filtering — commonly low-end Android and Android TV — the adapter substitutes a **verified degraded surface** (a solid or translucent fallback that reads as the same design without live backdrop sampling) and reports `unsupportedEffect` through the shared diagnostics contract (§15). A degraded surface must be a deliberate, tested presentation, never an accidental visual glitch or a frozen backdrop. `glass_morphism_plus` `^0.1.0` exposes only a fixed frosted surface, so effect introspection and the degrade decision are gated on the library growing an affordance API; until then, treat blur affordability as an environment assumption to be verified per platform, and never make native window or system-compositing APIs a required dependency of the basic adapter.

## 14. Localization and accessibility

Glass adds **no** localization delegates. It relies entirely on Flutter and core localization configured by the application composition root, and must not introduce a second, conflicting locale source or override the global locale independently.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints on every control, native or fallback.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast against translucent surfaces, and touch target sizing.

Because frosted surfaces reduce contrast, verify text legibility over both the real-blur and degraded-surface presentations on each target platform.

## 15. Error handling and diagnostics

The adapter reports structured diagnostics through the core `LiveUiDiagnostic` contract, delivered to a host-supplied `LiveUiDiagnosticSink`. It must not depend on Talker or another concrete logging package.

Each `LiveUiDiagnostic` carries the `language`, the `control` (null for a language-wide or environment-wide downgrade), the resolved `LiveImplementationKind` (`adapterNative` / `shared` / `custom`), and a `LiveUiDiagnosticCode`. The Glass-relevant cases:

| Code | When it fires for Glass | `control` | Fallback `kind` |
|---|---|---|---|
| `controlUnsupported` | One of the seven fallback controls is requested | The control | `shared` |
| `unsupportedEffect` | Blur/translucency/backdrop filter is unaffordable | null (environment-wide) | degraded surface |
| `adapterMissing` | Glass selected but no adapter registered | null (language-wide) | `shared` |
| `defaultAdapterMissing` | No fallback for the default language | null | startup fault |

The two Glass-specific downgrades are expected and stronger here than in opaque-surface adapters:

- **Capability downgrades are the norm, not an exception.** Because only button, card, and text field are native, the seven fallback controls resolve to the shared renderer on **every** platform and must surface `controlUnsupported` every time — the contract test asserts this (§16) so drift between `glassCapabilities` and the actual overrides fails CI.
- **Effect downgrades must be visible.** When real-time blur is replaced by a degraded surface (§13), report `unsupportedEffect` with `control == null` so the host sees an environment-wide visual change, and record the degraded stand-in it chose. No downgrade — capability or effect — happens without one of these codes.

Expected behavior:

- Unsupported visual variants may use a documented fallback.
- Invalid control data follows core validation rules.
- Programming errors are not swallowed.
- Diagnostics never log user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Unit / contract tests

The existing `test/adapter/glass_contract_test.dart` verifies, through the real `LanguageRegistry` and `LiveUiResolver`:

- Stable `id` (`glass`), `displayName` (`Glass`), and `language` (`LiveDesignLanguage.glass`).
- Capability set lists **exactly** `{button, card, textField}` as native and the other seven as non-native.
- A registered Glass language resolves to `adapterNative`.
- A declared control (button) resolves native with **no** diagnostic.
- An undeclared control (checkbox) resolves to `shared` and reports `controlUnsupported` naming that control.

Extend with:
- Theme scope installation and mapper behavior.
- Effect-budget behavior once the library exposes affordance introspection (assert `unsupportedEffect` on a simulated low-budget environment).
- Theme invalidation when the resolved token changes.

### Widget tests (`test/widgets/glass_native_controls_test.dart`)

- Button: callback when enabled, input rejected while loading, and `expand` plus
  `tooltip` wrapped around the frosted control.
- Card: reporting the tap, keeping the token padding and the `dense` step, and gaining no
  gesture layer while it is not interactive. `onLongPress` is wired through the wrapper,
  but no test drives it yet.
- Text field: the caller's controller passing through with `onChanged` firing, placeholder,
  prefix, disabled state and the error caption reaching the fork (§9), and the caller's
  `FocusNode` being the node that takes focus (§16).
- An unoverridden control still renders through the shared fallback.
- `test/theme/glass_theme_test.dart` covers the scope the builders sit in: panel tint,
  radius and shadow follow the token, the blur is a fixed library effect rather than a
  token-driven one (§8.1), and a brightness change re-skins through `wrap`.

Not covered: accessibility semantics and contrast on real-blur versus degraded surfaces,
layout under narrow and wide constraints, and the effect-budget path — the library exposes
no affordance to introspect (§15) and there is still no `interaction/` directory.

### Integration tests (`test/integration/glass_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: three `adapterNative`, seven `shared` with `controlUnsupported`.
- Glass → the `token` base → Glass removes and restores `glass.GlassButton`/`GlassCard`/`GlassTextField`, with the caller's controller text intact.
- The fallback controls (progress here) render on both sides of the switch.
- `unsupportedEffect` for a simulated unaffordable device stays open: it needs the affordance detection §18 Phase 3 blocks on.

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

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
- The declared `glassCapabilities` matches the methods `GlassLanguageAdapter` actually overrides — the fallback controls resolve shared and report `controlUnsupported`, never silent.
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

- Adapter aligns with the finalized core contract, stable id `glass`, three-control capability set, registration symbols.
- Contract test asserts id/displayName/language, exact native set, and resolver fallback + `controlUnsupported` reporting. **Done.**

### Phase 2 — Theme integration ✅

- `GlassThemeMapper` / `GlassThemeScope` / `GlassThemeBuilder` install the fixed frosted surface via `wrap`.
- Keep the `token` seam so token-driven blur drops in without touching callers.
- Test scope installation and theme invalidation on token change.

### Phase 3 — Effect budget (blocked on library)

- Add environment affordance detection and the verified degraded-surface path.
- Report `unsupportedEffect` on unaffordable platforms (low-end Android, Android TV).
- Blocked until `glass_morphism_plus` exposes blur/affordance introspection beyond the fixed surface.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: the native controls preserve caller state and the spec fields the library can carry (§9), asserted in `test/widgets/`.
- Open, needs hardware: focus visibility on translucent surfaces and Android TV D-pad.
- Implement the optional `interaction/` module for keyboard, focus visibility on translucent surfaces, and Android TV D-pad.
- Validate semantics and contrast on both real-blur and degraded surfaces.
- Document fallbacks for the spec fields `GlassTextField` cannot represent.

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Open: integration tests for style switching and the effect-degrade path.
- Verify all claimed platforms against their effect budgets.
- Document known limitations (native surface only for three controls; fixed blur until the library supports token-driven effects).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `glass_morphism_plus` only for its core integration.
- [x] It implements the actual core adapter contract by extending `SharedLanguageAdapter`.
- [x] It uses the stable adapter ID `glass` and displayName `Glass`.
- [x] It declares exactly `{button, card, textField}` as native and nothing else.
- [x] The seven fallback controls render via the shared token renderer and report `controlUnsupported`.
- [x] It maps the resolved `DesignToken` into the Glass theme and installs a `GlassTheme` scope via `wrap`.
- [x] It uses native `glass_morphism_plus` widgets where supported, without faking unsupported spec fields.
- [ ] Blur/translucency degrade to a verified surface on unaffordable platforms, reported via `unsupportedEffect`.
- [x] It adds no localization delegates and uses core localization.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, contrast, and TV focus behavior are tested once `interaction/` exists — the caller's node reaching `GlassTextField`'s focus tree is now proven (§16), but there is no `interaction/` directory, no semantics assertion, and no effect-budget degradation to verify while the library exposes no affordance (§15).
- [x] Diagnostics use the shared core `LiveUiDiagnostic` / `LiveUiDiagnosticSink` contract.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual per-effect-budget tests.

## 20. Final architecture decision

`live_uikit_glass` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model (`LiveConfig` → `DesignToken`), runtime selection (`LiveUiResolver` + `LanguageRegistry`), and fallback policy.
- `live_uikit_glass` maps those contracts to glassmorphism, overriding only `wrap`, `button`, `card`, and `textField` on top of `SharedLanguageAdapter`.
- `glass_morphism_plus` supplies the underlying frosted widgets and theme facilities — a narrow, early-version (`^0.1.0`) surface that is why only three controls are native.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

The defining Glass concern — real-time blur and translucency — is treated as a budgeted effect: it renders natively where affordable, degrades to a verified surface where not, and every capability or effect downgrade is announced through the shared diagnostics contract rather than happening silently. This separation lets PureLive add or replace UI styles, and adjust the effect budget per device, without forcing business packages to know which library is rendering their controls or whether the current device can afford a frosted surface.
