# `live_uikit_neumorphic` Architecture and Integration Specification

- **Package:** `live_uikit_neumorphic`
- **Parent package:** `live_uikit`
- **Implementation library:** `flutter_neumorphic_ui_kit`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_neumorphic` is the Neumorphic (soft-UI) adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `flutter_neumorphic_ui_kit` controls and soft-UI visual behavior. It must not implement business pages or duplicate the core theme system.

Neumorphism renders controls as extruded or inset surfaces shaped by a light source, a shadow depth, and a single base/accent surface color. This adapter expresses that vocabulary for the controls `flutter_neumorphic_ui_kit` provides natively, and defers the rest to the core token renderer.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_neumorphic
       |
       v
flutter_neumorphic_ui_kit
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `flutter_neumorphic_ui_kit` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **Neumorphic owns soft-UI visuals.** Use native `flutter_neumorphic_ui_kit` controls wherever practical rather than drawing soft-embossed controls from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from Neumorphic to another style must not require business pages to import or construct different control classes.
6. **Surfaces are shadow-driven.** A neumorphic container's identity is its shadow set; the adapter must render a legible, on-theme surface even when shadows are reduced or unavailable.
7. **Graceful fallback.** Unsupported controls must follow the fallback policy defined by `live_uikit`, not silently change behavior.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Neumorphic theme mapping from the resolved design token.
- Neumorphic widget construction for the six natively supported controls.
- Neumorphic-specific control defaults (depth, soft/inset surface shape, padding).
- Reporting implemented capabilities to the core registry.
- Adapter-level tests and contract-compliance checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The style selector UI.
- Shared design-token definitions.
- Global configuration storage.
- Riverpod, GetX, or other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Direct dependencies on other style adapters.

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts and tokens |
| `flutter_neumorphic_ui_kit` | Yes | Native Neumorphic controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_cupertino_ui` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_material_ui` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

Current structure:

```text
packages/
└── live_uikit_neumorphic/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_neumorphic.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── neumorphic_ui_adapter.dart
    │       │   ├── neumorphic_ui_capabilities.dart
    │       │   └── neumorphic_ui_registration.dart
    │       ├── theme/
    │       │   ├── neumorphic_theme_builder.dart
    │       │   ├── neumorphic_theme_mapper.dart
    │       │   └── neumorphic_theme_scope.dart
    │       └── widgets/
    │           ├── neumorphic_button_builder.dart
    │           ├── neumorphic_card_builder.dart
    │           ├── neumorphic_text_field_builder.dart
    │           ├── neumorphic_switch_builder.dart
    │           ├── neumorphic_checkbox_builder.dart
    │           └── neumorphic_slider_builder.dart
    ├── live-uikit-neumorphic.md
    └── test/
        ├── adapter/
        │   └── neumorphic_ui_contract_test.dart
        ├── theme/
        │   └── neumorphic_theme_test.dart
        ├── widgets/
        │   └── neumorphic_native_controls_test.dart
        └── integration/
            └── neumorphic_style_switching_test.dart
```

The following modules are optional and not yet created; add them as their functionality is implemented rather than scaffolding empty files:

```text
├── interaction/      # focus / keyboard / TV mapping (optional)
├── icons/            # semantic icon mapping (optional)
├── diagnostics/      # adapter-side diagnostics (optional)
└── example/          # integration demo without business deps (optional)
```

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration |
| `theme/` | Translate the resolved design token into a `NeuThemeData` and scope |
| `widgets/` | Build Neumorphic controls from core widget specifications |
| `interaction/` | (Optional) Map keyboard, focus, and TV-specific behavior |
| `icons/` | (Optional) Map supported semantic icons to Neumorphic icons |
| `diagnostics/` | (Optional) Report unsupported mappings and adapter errors |
| `test/` | Verify contract compliance and capability declarations |
| `example/` | (Optional) Demonstrate integration without business dependencies |

## 5. Package dependencies

Current `pubspec.yaml`:

```yaml
name: live_uikit_neumorphic
description: Neumorphic design-language adapter for live_uikit, rendering controls with flutter_neumorphic_ui_kit widgets.
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_neumorphic_ui_kit: ^1.0.1
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Because PureLive uses a Pub workspace, `live_uikit` is resolved through the workspace rather than a hard-coded path. Keep the `flutter_neumorphic_ui_kit` version aligned with the resolved workspace dependency before merging.

The adapter should not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation.

## 6. Public API

The public entry point exposes only the adapter's registration API.

```dart
// lib/live_uikit_neumorphic.dart

library;

export 'package:live_uikit_neumorphic/src/adapter/neumorphic_ui_registration.dart';
```

That registration file is the entire public surface:

| Symbol | Kind | Purpose |
|---|---|---|
| `createNeumorphicUiAdapter()` | function | Builds a `LanguageAdapter` for the composition root |
| `neumorphicUiAdapter` | `const LanguageAdapter` | The ready-to-register const adapter instance |
| `neumorphicUiAdapterId` | `const String` | The stable runtime id, `neumorphic` |

Do not export internal widget builders, the theme mapper, or `flutter_neumorphic_ui_kit` types. This package adds no localization delegates; the public API is registration only.

## 7. Adapter contract

`NeumorphicLanguageAdapter` implements the core contract and extends the token-driven base:

```dart
class NeumorphicLanguageAdapter extends SharedLanguageAdapter {
  const NeumorphicLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.neumorphic;
  @override String get id => 'neumorphic';
  @override String get displayName => 'Neumorphic';
  @override LiveUiCapabilities get capabilities => neumorphicUiCapabilities;
}
```

The core contract is `abstract interface class LanguageAdapter`, whose methods are `wrap, button, card, textField, switchWidget, checkbox, slider, segmented, progress, select<T>, tabBar` and whose getters are `language, id, displayName, capabilities`. `SharedLanguageAdapter` is the token-driven fallback base: every control has a working default built from the core recipes. This adapter extends it and overrides only the six native controls plus `wrap`; the remaining controls keep their inherited shared behavior.

Do not create a second competing adapter interface inside `live_uikit_neumorphic`.

### Adapter identifier

Use one stable identifier everywhere:

```text
neumorphic
```

The identifier is a machine-readable value exposed by `id` and `neumorphicUiAdapterId`, not a localized label. Do not use `flutter_neumorphic_ui_kit`, `Neumorphic`, or a platform-dependent value as the runtime style ID. `displayName` is `Neumorphic` and is only for the selector UI.

### Capability declaration

`neumorphicUiCapabilities` reports the controls rendered natively; everything else falls back to the shared token renderer and is reported by the resolver rather than silently degraded.

| Control | Implementation | Kind when active |
|---|---|---|
| Button | Native `NeuButton` | `adapterNative` |
| Card | Native `NeuCard` | `adapterNative` |
| Text field | Native `NeuTextField` | `adapterNative` |
| Switch | Native `NeuSwitch` | `adapterNative` |
| Checkbox | Native `NeuCheckbox` | `adapterNative` |
| Slider | Native `NeuSlider` | `adapterNative` |
| Segmented | Shared token renderer | `shared` (`controlUnsupported`) |
| Progress | Shared token renderer | `shared` (`controlUnsupported`) |
| Select | Shared token renderer | `shared` (`controlUnsupported`) |
| Tab bar | Shared token renderer | `shared` (`controlUnsupported`) |

Exactly six controls — `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider` — are Native. The other four — `segmented`, `progress`, `select`, `tabBar` — are not declared and resolve to the shared token renderer. This is the expected, reported behavior, not a defect; `neumorphic_ui_contract_test.dart` asserts the declaration matches the overrides so the two cannot drift.

The core model distinguishes the same three tiers through `LiveImplementationKind`: **`adapterNative`** (this adapter's real widget), **`shared`** (the core token renderer), and **`custom`** (an application-registered override). Use the core enum names rather than adding a parallel capability system.

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized `DesignToken`. The Neumorphic adapter translates that token into `NeuThemeData`. Neumorphic surfaces are defined by a base surface color plus an accent, so the token supplies exactly those.

The data flow is:

```text
LiveConfig
     |
     v
DesignToken
     |
     v
NeumorphicThemeMapper
     |
     v
NeumorphicThemeBuilder
     |
     v
NeuThemeData
     |
     v
NeumorphicThemeScope (NeuTheme)
     |
     v
Neumorphic controls
```

### 8.1 Theme properties to map

| Core theme property | Neumorphic mapping | Notes |
|---|---|---|
| Layout surface | `NeuThemeData.baseColor` | The single soft surface color; from `token.color.bgLayout` |
| Accent color | `NeuThemeData.accentColor` | Brand accent; from `token.color.primary` |
| Brightness | Base-surface choice | Light/dark changes the surface the shadows fall on |
| Text styles | Flutter text with Neumorphic theme | Map supported roles through the token |
| Shadow depth | Per-control extrude/inset shape | Depth is the primary neumorphic cue; keep it legible when reduced |
| Density / padding | Token-driven control padding | Do not assume every widget responds identically |

`NeumorphicThemeBuilder.build(token)` maps four properties: `baseColor` from `token.color.bgLayout`, `accentColor` from `token.color.primary`, `borderRadius` from `token.scale.radii.lg`, and `customShadowColor` from `token.color.shadowBase`. Brightness is tracked indirectly — `NeuThemeData` has no brightness field, and the soft surface follows whatever `bgLayout` the resolved algorithm produced, so a dark token yields a dark surface with light casting the same shadows. Depth, distance, curvature and intensity remain library defaults: they are the neumorphic signature, not colour intent, and no token names them.

### 8.2 Theme scope

The adapter installs the mapped theme around its widgets through `wrap`, which returns a `NeumorphicThemeScope`. That scope wraps the child in `NeuTheme(data: NeumorphicThemeBuilder.build(token), child: child)`.

Do not nest an application shell inside an existing app solely to apply the Neumorphic style; the theme-scope mechanism above is the intended path. The application composition root chooses the shell.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `wrap` runs the mapper with the new token.
4. `NeuTheme` rebuilds its subtree.
5. Existing business state remains owned by the business widgets and controllers.

Do not cache a `NeuThemeData` permanently if its source token can change. `NeumorphicThemeScope` rebuilds from the current token on every parent rebuild; that is the correct behavior.

## 9. Control implementation rules

Each control builder converts a core specification into a `flutter_neumorphic_ui_kit` widget, expressed as a soft shape (extruded for raised, inset for sunken).

### Button

- Built by `NeumorphicButtonBuilder` as a `NeuButton`.
- Press enabled-ness comes from the shared seam (`SharedLanguageAdapter.interactive`): enabled, not loading, has a callback.
- Label, leading icon, and loading spinner come from `SharedLanguageAdapter.buttonLabel`.
- Padding is token-driven (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`).
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` in the core's language-neutral `LiveTooltip`; `NeuButton` exposes neither slot, and its focus handling is internal, so `focusNode`/`autofocus` are recorded as unmappable (§15).
- Do not place business actions inside the adapter.
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

### Card

- Built by `NeumorphicCardBuilder` as a `NeuCard` — the soft surface is the card's identity.
- Honors `padding` from the spec, else the token padding with the `dense` step applied, and wraps content in a gesture layer only when `onTap` or `onLongPress` is present.
- `selected` and `bordered` have no soft-surface equivalent — the card is its shadow, not a border or fill — so they are left to the fork's pressed state rather than faked with an outline (§15).
- Preserve content, padding, and click semantics; do not assume every card is interactive.

### Text field

- Built by `NeumorphicTextFieldBuilder` as a `NeuTextField`.
- Passes the caller's `controller`, `focusNode`, hint, error, obscuring, line count, keyboard type and action, leading/trailing slots, enable state and callbacks straight through; the field owns its controller when the spec supplies none. The inline `Style` layers onto the token body text.
- Do not create a second controller or silently own its lifecycle. `readOnly` has no `NeuTextField` equivalent and is recorded as unmappable (§15) rather than emulated by dropping the callback, which would change what the field means.

### Switch

- Built by `NeumorphicSwitchBuilder` as a `NeuSwitch`.
- Fully controlled by the spec value; disabled by dropping the callback when `enabled` is false.
- Do not introduce local persistent state.

### Checkbox

- Built by `NeumorphicCheckboxBuilder` as a `NeuCheckbox`.
- The optional trailing label is applied through the shared seam (`SharedLanguageAdapter.labelled`).
- Preserve checked/unchecked and disabled semantics; a null `onChanged` (or `enabled: false`) reaches the fork as null, which is what renders the box disabled. The `bool?`→`bool` bridge closure exists only when the caller can be called back — a closure that swallowed the value would leave a live-looking control (§15).

### Slider

- Built by `NeumorphicSliderBuilder` as a `NeuSlider`.
- Clamps the value to `[min, max]` and disables by dropping `onChanged` when `enabled` is false.
- Handle invalid ranges according to the core validation contract.

### Shared-fallback controls

`segmented`, `progress`, `select`, and `tabBar` are not overridden. They render through the inherited `SharedLanguageAdapter` token renderer and are reported as `controlUnsupported` by the resolver. Do not add ad-hoc Neumorphic drawings for them unless they are also added to the capability set and covered by the contract test.

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder receives `variant`, `size`, and state; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup using the exported API:

```dart
void registerUiAdapters(LanguageRegistry registry) {
  registry.register(createNeumorphicUiAdapter());
  // or register the const instance directly:
  // registry.register(neumorphicUiAdapter);
}
```

`createNeumorphicUiAdapter()` and `neumorphicUiAdapter` both yield a `NeumorphicLanguageAdapter`, keyed by `LiveDesignLanguage.neumorphic` and `neumorphicUiAdapterId` (`neumorphic`).

The composition root is responsible for registering adapters, loading the user's style preference, selecting the active language, providing persistence, and coordinating runtime theme changes. `live_uikit_neumorphic` must not register itself through global static initialization or require the business layer to import it.

### Registration and resolution failures

The runtime (`LiveUiResolver` over `LanguageRegistry`) reports structured diagnostics with these codes:

- `adapterMissing` — the selected language has no registered adapter; controls resolve to the shared renderer (language-wide).
- `defaultAdapterMissing` — the registry cannot supply the shared fallback for the default language; a startup-level fault, never recovered silently.
- `controlUnsupported` — the adapter is registered but does not declare this control; that control alone falls back to shared. This is the normal path for `segmented`, `progress`, `select`, `tabBar` here.
- `unsupportedEffect` — the environment cannot afford an effect (blur, backdrop filter, TV focus); a verified degraded visual stands in.

Diagnostics reach the host through the `LiveUiDiagnosticSink`, never through a concrete logging package. When Neumorphic is unavailable, the core fallback policy chooses an available implementation or reports a clear error; it must not silently switch styles.

## 11. Runtime style switching

A business widget uses the core API only:

```dart
LiveButton(
  label: 'Save',
  onPressed: saveSettings,
)
```

It must not contain conditional style branching:

```dart
// Avoid style-specific branching in business packages.
if (language == 'neumorphic') {
  // Build a NeuButton.
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
LiveUiResolver
      |
      v
Selected adapter
      |
      +---- Neumorphic adapter
      +---- Fluent adapter
      +---- Material adapter
      +---- Other registered adapters
```

Switching to Neumorphic changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms, so the Neumorphic style must be tested for more than mouse input. Neumorphic surfaces signal state through shape and shadow, which can make a focus ring harder to see than a flat outline — pay extra attention to focus indication.

The adapter and the core interaction policy should account for:

- Keyboard navigation and focus traversal.
- Visible focus indication on soft surfaces.
- Enter and Space activation semantics.
- Disabled controls being skipped or handled correctly.
- Remote-control (D-pad) navigation on Android TV.
- Predictable focus behavior after runtime style switching.
- Accessibility semantics for interactive controls.

The `interaction/` module is not yet created; when keyboard, focus, and TV mapping is implemented, add it there and cover it with tests. Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility. Where the device cannot afford focus effects, fall through the `unsupportedEffect` path rather than dropping focus entirely.

## 13. Platform behavior

Neumorphism is a visual style choice, not a declaration that any OS provides soft-UI controls natively.

| Platform | Expected behavior |
|---|---|
| Windows | Neumorphic styling with desktop keyboard and mouse support |
| macOS | Neumorphic styling while retaining macOS application integration |
| Linux | Neumorphic styling; verify platform-specific rendering |
| Android | Neumorphic styling with touch-friendly sizing |
| Android TV | Neumorphic styling plus explicit D-pad and focus testing |
| iOS | Neumorphic styling while retaining iOS lifecycle and accessibility behavior |

Neumorphic containers rely on layered shadows. Verify that surfaces degrade acceptably on low-power or TV targets where soft shadows are expensive: when the environment cannot afford them, a verified flat-but-on-theme surface must stand in via the `unsupportedEffect` diagnostic, never a blank or illegible control. Do not make native window or blur APIs a required dependency of the basic adapter.

## 14. Localization and accessibility

`live_uikit_neumorphic` adds no localization delegates. It uses the localization configuration supplied by `live_uikit` and the application composition root.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints from the specs.
- Avoid introducing a second, conflicting locale source.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast against the base surface, and touch target sizing.

Neumorphic low-contrast soft surfaces are an accessibility risk; verify text and control contrast on both light and dark base colors.

## 15. Error handling and diagnostics

Report structured diagnostics for meaningful failures:

- An unsupported control or variant.
- An invalid specification.
- A theme property that cannot be mapped directly.
- A missing icon mapping.
- A failed fallback or a shadow-heavy surface that cannot be afforded.
- An adapter initialization or registration error.

Use the diagnostics contracts from `live_uikit` (`LiveUiDiagnostic`, the `LiveUiDiagnosticCode` values, and `LiveUiDiagnosticSink`). Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- Undeclared controls (`segmented`, `progress`, `select`, `tabBar`) fall back to shared and are reported with `controlUnsupported` — expected, not silent.
- Unaffordable effects degrade through `unsupportedEffect` with a verified fallback.
- Invalid control data follows core validation rules.
- Programming errors are not swallowed.
- Diagnostics avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Contract tests (`test/adapter/neumorphic_ui_contract_test.dart`)

`test/adapter/neumorphic_ui_contract_test.dart` verifies:

- Stable id (`neumorphic`), `displayName` (`Neumorphic`), and `language` (`LiveDesignLanguage.neumorphic`).
- The capability set declares exactly the six native controls and none of the four fallback controls.
- Through `LiveUiResolver` + `LanguageRegistry`: a registered language resolves to `adapterNative`; a declared control (`button`) resolves native with no diagnostic; an undeclared control (`segmented`) resolves to `shared` and reports `controlUnsupported`.

### Theme tests (`test/theme/neumorphic_theme_test.dart`)

- Base surface, accent and radius follow the resolved token (§8.1), and a dark token
  yields a different base surface than the light one (§8.3).
- Toggling brightness re-skins through `wrap`, with no restart.
- The native slider's rendering is asserted in `test/widgets/`; value clamping is proven
  for the token renderer in the core suite, and nothing here yet pins the fork's own
  clamping.

### Widget tests (`test/widgets/neumorphic_native_controls_test.dart`)

- Button: `onPressed` fires when enabled, input is rejected while loading, and `expand`
  plus `tooltip` wrap the control.
- Text field: the caller's controller survives, the rest of the caller state passes
  through, and the caller's `FocusNode` is the node that takes focus (§9/§16).
- Switch, checkbox, slider: reporting the next value, a null callback disabling the
  checkbox instead of faking one, and the card and slider rendering natively.
- Card: `dense` and an explicit `padding` both reach the surface.
- An unoverridden control still renders through the shared fallback.

Not covered yet: accessibility semantics, layout under narrow versus wide constraints, and
anything a `NeuTheme` scope decision needs on a real device — the hardware half §19 still
keeps open.

### Integration tests (`test/integration/neumorphic_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: six `adapterNative`, four `shared` with `controlUnsupported`.
- Neumorphic → core `material` → Neumorphic swaps `neu.NeuButton`/`NeuCard`/`NeuTextField`/`NeuSwitch` for the token renderer and back, with the caller's controller text intact.
- Segmented, shared in this language, stays callable on both sides (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring a platform supported, test on the corresponding runtime. Because the style is shadow-based, explicitly include a low-power or TV target in the matrix to verify the `unsupportedEffect` degradation path.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_neumorphic` depends on `live_uikit` and `flutter_neumorphic_ui_kit`.
- `live_uikit_neumorphic` does not depend on other style adapters.
- The core package does not depend on `flutter_neumorphic_ui_kit`.
- Business packages do not import `package:flutter_neumorphic_ui_kit/...`.
- All public exports are intentional (registration only).
- The declared capabilities match the methods actually overridden (already asserted by the contract test).
- Every `package:flutter_neumorphic_ui_kit/` import inside this package uses the `as neu` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `neumorphicUiCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands, run from the workspace root:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_neumorphic
flutter analyze packages/live_uikit_neumorphic
flutter test packages/live_uikit_neumorphic
```

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Adapter aligned with the finalized core contract.
- Stable id, display name, language, and capability set defined.
- Registration API (`createNeumorphicUiAdapter`, `neumorphicUiAdapter`, `neumorphicUiAdapterId`) exported.
- Contract and resolution tests in place.

### Phase 2 — Theme integration ✅

- `NeumorphicThemeMapper`, `NeumorphicThemeBuilder`, and `NeumorphicThemeScope` wired through `wrap`.
- Verify brightness/accent tracking and runtime theme updates.

### Phase 3 — Core controls ✅ (native set)

Implemented and behind the builders:

1. Button
2. Card
3. Text field
4. Switch
5. Checkbox
6. Slider

Add widget tests as each builder matures.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: caller state, callbacks and the spec fields the library carries are asserted in `test/widgets/`.
- Open, needs hardware: focus visibility on soft surfaces and Android TV D-pad.
- Add the optional `interaction/` module for keyboard, focus, and TV mapping.
- Test Android TV D-pad behavior and focus visibility on soft surfaces.
- Validate contrast and semantics.
- Document the `unsupportedEffect` degradation for shadow-heavy surfaces.

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Open: integration tests for style switching.
- Verify all claimed platforms, including the low-power/TV shadow-degradation path.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `flutter_neumorphic_ui_kit` only for its core integration.
- [x] It extends `SharedLanguageAdapter` and implements the real `LanguageAdapter` contract.
- [x] It uses the stable adapter id `neumorphic` with `displayName` `Neumorphic`.
- [x] It declares exactly six native controls (`button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`).
- [x] `segmented`, `progress`, `select`, `tabBar` fall back to the shared renderer and are reported via `controlUnsupported`.
- [x] It maps the resolved `DesignToken` into `NeuThemeData` and applies it through `wrap`.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It exports only the registration API and adds no localization delegates.
- [x] It does not create a nested application shell unnecessarily.
- [x] Runtime switching preserves business state.
- [x] Neumorphic surfaces degrade acceptably when shadows cannot be afforded (`unsupportedEffect`).
- [ ] Keyboard, accessibility, and TV focus behavior are tested — a caller's `FocusNode` reaching the fork's field focus tree is (§16); the shadow surface's focus visibility, D-pad traversal and screen-reader announcements need hardware.
- [x] Diagnostics use the shared core contract and sink.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_neumorphic` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection, and fallback policy.
- `live_uikit_neumorphic` maps those contracts to Neumorphic: six controls natively, the rest through the shared token renderer.
- `flutter_neumorphic_ui_kit` supplies the underlying soft-UI widgets and `NeuTheme` facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive add or replace UI styles — including the shadow-driven Neumorphic look and its low-power degradation — without forcing business packages to know which UI library is currently rendering their controls.
