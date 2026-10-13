# `live_uikit_wind` Architecture and Integration Specification

- **Package:** `live_uikit_wind`
- **Parent package:** `live_uikit`
- **Implementation library:** `fluttersdk_wind`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_wind` is the Wind design-language adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `fluttersdk_wind` controls and Wind-specific visual behavior. It must not implement business pages or duplicate the core theme system.

Wind is a Windows-flavoured, Fluent-like style kit. It is a **distinct library from `fluent_ui`** and is served by a **distinct adapter package** (`live_uikit_wind`, not `live_uikit_fluent`); the two packages do not depend on each other and do not share mappings. Where this document overlaps concerns covered in depth for Fluent, it cross-references `live-uikit-fluent.md` rather than repeating them.

**Scope today.** Wind is the narrowest adapter in the family: it renders only **button, switch, and checkbox** natively. Every other control still resolves correctly, but through the core shared token renderer rather than a `fluttersdk_wind` widget. This is a deliberate foundation, not an omission — see §7 and §18.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_wind
       |
       v
fluttersdk_wind
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `fluttersdk_wind` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, the `LanguageAdapter`/`SharedLanguageAdapter` base, the capability model, the resolver/registry, and the diagnostic contract all belong to `live_uikit`.
2. **Wind owns Wind visuals.** Use native `fluttersdk_wind` controls wherever a clean mapping exists, rather than drawing Wind-style controls from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application. The Wind switch and checkbox builders are fully controlled — value, callback, and disabled flag pass straight through the spec.
5. **Runtime switching is supported.** Switching between Wind and any other style must not require business pages to import or construct different control classes.
6. **Honest capabilities.** `windUiCapabilities` declares exactly the three controls `WindLanguageAdapter` overrides. The remaining seven are *reported* as shared fallbacks by the resolver, not silently degraded.
7. **Platform-aware behavior.** Wind appearance can be selected on any supported platform, but native Windows system integrations must not be assumed on every platform.
8. **Graceful fallback.** Unsupported controls follow the fallback policy defined by `live_uikit` and surface a `controlUnsupported` diagnostic; they never change behavior in silence.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Wind theme mapping (`DesignToken` → `WindThemeData`, installed through a Wind theme scope).
- Wind widget construction for the three controls it maps natively: button, switch, checkbox.
- Wind-specific control defaults for those controls.
- Reporting the accurate, minimal capability set to the core registry.
- Adapter-level contract tests and capability-sync checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The multi-style selector UI.
- Shared design-token definitions (`DesignToken`, `SeedToken`, `ColorTokens`, …).
- Global configuration storage (`UiConfig`).
- Riverpod, GetX, or any other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Direct dependencies on any other style adapter, including `live_uikit_fluent`.

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts, tokens, resolver, diagnostics |
| `fluttersdk_wind` | Yes | Native Wind controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Wind and Fluent are separate adapters; no cross-dependency |
| `live_uikit_material_ui` | No | Adapters must remain independent |
| `live_uikit_cupertino_ui` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

The structure below reflects the files that exist today; the modules marked *(optional)* are expansion points that have not been created yet.

```text
packages/
└── live_uikit_wind/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_wind.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── wind_ui_adapter.dart
    │       │   ├── wind_ui_capabilities.dart
    │       │   └── wind_ui_registration.dart
    │       ├── theme/
    │       │   ├── wind_theme_mapper.dart
    │       │   ├── wind_theme_builder.dart
    │       │   └── wind_theme_scope.dart
    │       └── widgets/
    │           ├── wind_button_builder.dart
    │           ├── wind_switch_builder.dart
    │           └── wind_checkbox_builder.dart
    ├── test/
    │   └── adapter/
    │       └── wind_ui_contract_test.dart
    ├── interaction/        # (optional, not created) focus / keyboard / TV mapping
    ├── icons/              # (optional, not created) semantic-icon mapping
    ├── diagnostics/        # (optional, not created) adapter-local mapping diagnostics
    └── example/            # (optional, not created) integration demo
```

Do not create empty files just to match the optional directories. Add each module only when its functionality is implemented — and keep the capability declaration (§7) in sync with the overrides the moment a new control goes native.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | `WindLanguageAdapter`, the `windUiCapabilities` set, and the registration API |
| `theme/` | Translate the resolved `DesignToken` into `WindThemeData` and install it via a Wind scope |
| `widgets/` | Build native `fluttersdk_wind` controls from core `Language*Spec` objects |
| `test/` | Verify the contract, stable id/display name, and that capabilities match the overrides |
| `interaction/` *(optional)* | Map keyboard, focus, and TV-specific behavior once native surfaces justify it |
| `icons/` *(optional)* | Map supported semantic icons to Wind icons |
| `diagnostics/` *(optional)* | Report Wind-specific unmapped variants; core diagnostics already cover control fallbacks |
| `example/` *(optional)* | Demonstrate integration without business dependencies |

## 5. Package dependencies

The current `pubspec.yaml`:

```yaml
name: live_uikit_wind
description: Wind design-language adapter for live_uikit, rendering controls with fluttersdk_wind widgets.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  fluttersdk_wind: ^1.8.1
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Because PureLive uses a Pub workspace, `live_uikit` is resolved through the workspace rather than a hard-coded path, and the `resolution: workspace` directive makes this package a workspace member. Keep the `fluttersdk_wind` constraint aligned with the resolved workspace version before merging.

The adapter does not add `freezed`, `json_serializable`, or `build_runner`; its own code has no generation needs. The core `live_uikit` package already owns the serialisable configuration model.

## 6. Public API

The public entry point exposes only the registration API. This is intentional: builders, mappers, and the adapter class itself are implementation details, and third-party `fluttersdk_wind` types must not leak into business code.

```dart
// lib/live_uikit_wind.dart

/// Wind design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6).
library;

export 'package:live_uikit_wind/src/adapter/wind_ui_registration.dart';
```

`wind_ui_registration.dart` provides exactly three symbols:

```dart
const String windUiAdapterId = 'wind';
const LanguageAdapter windUiAdapter = WindLanguageAdapter();
LanguageAdapter createWindUiAdapter() => const WindLanguageAdapter();
```

No localization delegates are exported. Wind adds none of its own and relies entirely on the core localization setup (§14).

Do not export `WindLanguageAdapter`, the `Wind*Builder` classes, `WindThemeMapper`/`WindThemeScope`/`WindThemeBuilder`, or any `fluttersdk_wind` type from the barrel.

## 7. Adapter contract

`live_uikit` defines the contract as a finalized `abstract interface class LanguageAdapter`:

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

`SharedLanguageAdapter` is the token-driven base: every control has a working default built from the core token renderer, and `capabilities` is empty (`LiveUiCapabilities.none()`). Library adapters **extend** it and override only the controls they map natively, plus `wrap`. Wind does exactly this:

```dart
class WindLanguageAdapter extends SharedLanguageAdapter {
  const WindLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.wind;
  @override String get id => 'wind';
  @override String get displayName => 'Wind';
  @override LiveUiCapabilities get capabilities => windUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => WindButtonBuilder.build(context, spec, this);
  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => WindSwitchBuilder.build(context, spec);
  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => WindCheckboxBuilder.build(context, spec, this);
}
```

`card`, `textField`, `slider`, `segmented`, `progress`, `select`, and `tabBar` are **not** overridden — they inherit the shared token renderer.

### Adapter identifier

Use one stable machine-readable identifier everywhere:

```text
wind
```

It is the value used by the registry, persistence, and diagnostics — never a localized label. Do not use `fluttersdk_wind`, `Wind UI`, or a platform-dependent value as the runtime style id. `windUiAdapterId`, `WindLanguageAdapter.id`, and `LiveDesignLanguage.wind.name` all resolve to `wind`.

### Capability declaration

`windUiCapabilities` is a *declaration of fact* — it lists precisely the controls `WindLanguageAdapter` overrides with native `fluttersdk_wind` widgets:

```dart
const LiveUiCapabilities windUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
});
```

The full capability surface, mapped to the ten `LiveUiControl` values the resolver dispatches:

| Control (`LiveUiControl`) | Implementation | Kind (`LiveImplementationKind`) |
|---|---|---|
| `button` | Native `fluttersdk_wind` button | `adapterNative` |
| `switchWidget` | Native `fluttersdk_wind` switch | `adapterNative` |
| `checkbox` | Native `fluttersdk_wind` checkbox | `adapterNative` |
| `card` | Core shared token renderer | `shared` |
| `textField` | Core shared token renderer | `shared` |
| `slider` | Core shared token renderer | `shared` |
| `segmented` | Core shared token renderer | `shared` |
| `progress` | Core shared token renderer | `shared` |
| `select` | Core shared token renderer | `shared` |
| `tabBar` | Core shared token renderer | `shared` |

Three Native, seven Shared fallback. This is the narrowest native surface among the current adapters, and the declaration states so honestly. A declared control resolves to `adapterNative` with **no** diagnostic; an undeclared control resolves to `shared` and the resolver emits a `controlUnsupported` diagnostic (§15). The `wind_ui_contract_test.dart` asserts that the capability set lists exactly the overrides and that the fallback controls report `controlUnsupported`, so drift between declaration and implementation is caught before it ships (§17).

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized `DesignToken`. The Wind adapter translates that resolved token into `WindThemeData` and installs it in a Wind scope.

The data flow uses the real core types:

```text
UiConfig (the choice surface)
     |
     v
LiveConfigProvider -> SeedToken -> theme algorithm
     |
     v
DesignToken (resolved; what components read via LiveTheme.of)
     |
     v
WindThemeMapper.wrap(context, token, child)
     |
     v
WindThemeScope (StatelessWidget)
     |
     v
WindThemeBuilder.build(token) -> WindThemeData
     |
     v
wind.WindTheme(data:, child:) scope
     |
     v
fluttersdk_wind controls
```

The adapter's `wrap` is a one-line delegation to `WindThemeMapper`, which returns a `WindThemeScope`; the scope builds the theme data through `WindThemeBuilder` and installs it via `wind.WindTheme`:

```dart
class WindThemeBuilder {
  static wind.WindThemeData build(DesignToken token) =>
      wind.WindThemeData(brightness: token.isDark ? Brightness.dark : Brightness.light);
}
```

### 8.1 Theme properties to map

The current mapping is intentionally minimal — only brightness crosses over today. Later phases (§18) widen it toward the Fluent baseline:

| Core theme source (`DesignToken`) | Wind mapping | Status |
|---|---|---|
| `isDark` | `WindThemeData.brightness` | Mapped now |
| `color.primary` (accent) | Wind accent/seed color | Later phase |
| `type.fontFamily` | Wind font family | Later phase |
| `scale.controlHeight*` / density | Wind control sizing | Later phase |
| `color.bgContainer` / `bgElevated` | Wind surface colors | Later phase |
| `motion.durationFast/Mid/Slow` | Wind transitions | Later phase |

Do not assume every Wind widget responds to a token the same way. The core tokens define shared design intent; the Wind adapter translates that intent into the closest appropriate Wind presentation as the library's theme surface allows.

### 8.2 Theme scope

The adapter installs a Wind theme scope around the widgets it builds via `WindThemeScope`. It does not wrap the subtree in an application shell — a nested app widget would introduce competing navigation and configuration. Only the theme-scope mechanism (`wind.WindTheme`) is used.

### 8.3 Runtime updates

When the user changes brightness, accent, font, density, or style:

1. The application updates `UiConfig`.
2. `LiveConfigProvider` re-derives the `DesignToken`.
3. `WindThemeBuilder.build(token)` produces fresh `WindThemeData` on rebuild.
4. The Wind scope rebuilds; business state remains owned by the business widgets.

Do not cache a `WindThemeData` object permanently while its source token can change.

## 9. Control implementation rules

Each native builder converts a core `Language*Spec` into a `fluttersdk_wind` widget. Builders must map semantic intent, not inspect business page types — a button builder may read `spec.variant`, but must not special-case login, playback, or plugin screens.

### Button (`WindButtonBuilder.build`)

- Builds a `wind.WButton`; the press is wired only when `SharedLanguageAdapter.interactive(spec)` is true (enabled, not loading, has `onPressed`).
- Reuses the shared seam for the label and loading spinner via `buttonLabel(spec, theme)`, so loading, icon, and ellipsis behavior match every other adapter.
- Padding is token-driven (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`).
- `focusNode`, `autofocus`, `expand`, and `tooltip` come from `LanguageButtonSpec` and must be preserved.

### Switch (`WindSwitchBuilder.build`)

- Builds a `wind.WSwitch(value:, onChanged:, disabled:)` — fully controlled.
- `onChanged` is passed only when `spec.enabled`; otherwise `null`, matching the spec contract that a null callback disables the control.
- No local persistent state; the value lives with the caller.

### Checkbox (`WindCheckboxBuilder.build`)

- Builds a `wind.WCheckbox(value:, onChanged:, disabled:)` and wraps it through `SharedLanguageAdapter.labelled(context, spec.label, control)` so the optional trailing label renders consistently.
- Preserves the checked/unchecked value, the disabled flag, and the callback semantics.

### Card, text field, slider, segmented, progress, select, tab bar

These are **not** native yet. They resolve through the inherited `SharedLanguageAdapter` methods (`TokenCard`, `TokenTextField`, `TokenSlider`, `TokenSegmented`, `TokenProgress`, `TokenSelect`, `TokenTabs`) and report `controlUnsupported` (§15). They stay on-theme because they read the same `DesignToken` the Wind scope installs — the Wind look is carried by the token, even before a `fluttersdk_wind` widget stands behind each control. Promoting them to native builders is the expansion path in §18.

## 10. Runtime registration

The application composition root registers the adapter during startup. Wind exposes a const instance and a factory so the root can pick either:

```dart
// Using the exported API.
registry.add(createWindUiAdapter());   // or: registry.add(windUiAdapter);
```

The core `LanguageRegistry` maps `LiveDesignLanguage → LanguageAdapter` with a shared fallback, so an unregistered language still renders coherently:

```dart
const LanguageRegistry(adapters: {LiveDesignLanguage.wind: windUiAdapter}, fallback: SharedLanguageAdapter());
```

The composition root, not the adapter, is responsible for: registering the adapters included in the build, loading the user's style preference, selecting the active language, providing configuration persistence, and coordinating runtime theme changes. `live_uikit_wind` must not register itself through global static initializers or require the business layer to import it.

### Resolution behavior

The core `LiveUiResolver` is the single decision point. For Wind:

- A registered language resolves to `adapterNative` (`WindLanguageAdapter`).
- A declared control (`button`, `switchWidget`, `checkbox`) resolves native with no diagnostic.
- An undeclared control resolves to `shared` with a `controlUnsupported` diagnostic — never a silent lie about which widget drew it.
- If Wind were not registered at all, controls resolve to the shared fallback with an `adapterMissing` diagnostic. A missing default adapter is a startup fault surfaced as `defaultAdapterMissing`.

## 11. Runtime style switching

A business widget uses the core API only:

```dart
LiveButton(label: 'Save', onPressed: saveSettings)
```

It must not contain style-specific branching:

```dart
// Avoid style-specific branching in business packages.
if (language == LiveDesignLanguage.wind) {
  // build a WButton
} else {
  // build another library's button
}
```

The intended rendering flow:

```text
Business widget
      |
      v
LiveButton  ->  LanguageButtonSpec
      |
      v
LiveUiResolver / LiveUiRuntime
      |
      v
Selected adapter
      |
      +---- Wind adapter (native WButton)
      +---- Material adapter
      +---- Fluent adapter
      +---- Shared token renderer (any control an adapter does not override)
```

Switching from Wind to another style changes rendering and interaction presentation only. It must not replace business controllers, reset form values, or recreate unrelated services. Because Wind overrides only three controls, switching *into* Wind keeps card/field/slider/etc. rendering via the shared token renderer — the visible style shift is concentrated in buttons, switches, and checkboxes.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile, so the Wind adapter must be tested for more than mouse input.

Wind is Windows-flavoured, which makes keyboard-driven desktop the natural first-class context: Tab/shift-Tab traversal, visible focus indication, and Enter/Space activation should be verified against the native `WButton`/`WSwitch`/`WCheckbox`. Because `WindLanguageAdapter` inherits the shared token renderer for card, text field, and the other seven controls, those inherit the core's focus behavior — the `Language*Spec` objects carry `focusNode` and `autofocus` (button, card, switch, checkbox, slider, text field all do), and the adapter must forward them when a control later goes native.

For Android TV and remote-control D-pad navigation, do not assume desktop keyboard behavior transfers automatically; test with the supported TV input devices and rely on the core interaction policy to fill gaps. The deep Fluent-specific focus and reveal behaviors are documented in `live-uikit-fluent.md` and are not repeated here — Wind and Fluent are separate libraries with separate focus theming, so each adapter's focus guarantees must be verified independently.

At minimum account for:

- Focus traversal order and visible focus rings on native Wind controls.
- Enter/Space activation semantics for buttons.
- Disabled controls being skipped in traversal.
- Focus restoration after dialogs or navigation (later phases).
- D-pad navigation on Android TV.
- Accessibility semantics on interactive controls.

## 13. Platform behavior

Wind is a visual style choice, not a claim that every OS provides Windows-native controls.

| Platform | Expected behavior |
|---|---|
| Windows | Primary target: Wind styling with desktop keyboard and mouse support |
| macOS | Wind styling while retaining appropriate macOS application integration |
| Linux | Wind styling; verify platform-specific rendering and dependencies |
| Android | Wind styling with touch-friendly sizing |
| Android TV | Wind styling plus explicit D-pad and focus testing |
| iOS | Wind styling while retaining iOS lifecycle and accessibility behavior |

Effects the Wind library cannot express on a given platform must degrade through the shared token renderer, not fail. Native window APIs must not become a required dependency of the basic adapter. Cross-platform parity concerns and Fluent's platform matrix are covered in `live-uikit-fluent.md`.

## 14. Localization and accessibility

Wind adds **no localization delegates** of its own. Localization is provided entirely by the core `live_uikit` setup and the application composition root, and `live_uikit_wind` intentionally exports none.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings (labels come through the `Language*Spec` objects).
- Preserve semantic labels and hints on the controls it builds.
- Not introduce a second, conflicting locale source or override the global locale.
- Test long translated labels and right-to-left layouts on the native Wind controls.
- Verify focus visibility, text contrast, and touch target sizing.

## 15. Error handling and diagnostics

Diagnostics use the core contracts only — `LiveUiDiagnostic`, the `LiveUiDiagnosticCode` enum, and the host-supplied `LiveUiDiagnosticSink`. Wind does not depend on Talker or any concrete logging package.

The codes relevant to Wind:

| Code | When Wind hits it |
|---|---|
| `controlUnsupported` | A request for any of card, textField, slider, segmented, progress, select, tabBar — expected, not silent degrade |
| `adapterMissing` | Wind was selected but not registered — every control resolves to shared |
| `defaultAdapterMissing` | The shared fallback itself is unavailable — startup fault |
| `unsupportedEffect` | The environment cannot afford a Wind visual effect; a verified degraded visual stands in |

For the seven fallback controls, `controlUnsupported` is the **documented, expected** outcome at Wind's current scope, not a bug. The resolver returns the shared implementation with that diagnostic so a test can assert "this control, in the Wind style, was rendered by the shared token renderer for this reason." As each control graduates to native (§18), it moves from `shared` to `adapterNative`, the diagnostic disappears, and `windUiCapabilities` must be updated in the same change.

Expected behavior:

- Unsupported controls follow the core fallback policy; nothing blanks.
- Programming errors are not swallowed.
- Diagnostics avoid logging user-entered text, credentials, or sensitive content.

## 16. Testing strategy

### Unit / contract tests (`test/adapter/wind_ui_contract_test.dart`)

- Stable id (`wind`), display name (`Wind`), and language (`LiveDesignLanguage.wind`).
- The capability set lists exactly `{button, switchWidget, checkbox}`; the other seven are `false`.
- Through `LiveUiResolver` over a `LanguageRegistry`: a registered Wind resolves `adapterNative`; a declared control resolves native with no diagnostic; an undeclared control resolves `shared` and reports `controlUnsupported`.
- Brightness mapping (`isDark` → `WindThemeData.brightness`).

### Widget tests (as native surface expands)

- Button: callback, disabled/loading state, `focusNode`/`autofocus`, `expand`.
- Switch: value updates, `onChanged` null when disabled.
- Checkbox: state transitions, trailing label through `labelled`.
- Correct Wind theme scope applied.
- Layout under narrow and wide constraints; accessibility semantics.

### Integration tests

1. Register Wind alongside at least one other adapter.
2. Select Wind at runtime.
3. Render a mixed screen: native button/switch/checkbox plus fallback card/field.
4. Assert the fallback controls emit `controlUnsupported` and still render on-theme.
5. Change brightness/accent without restarting; switch away from Wind and back; confirm form values and controllers remain intact.

### Platform verification

Before declaring a platform supported, test on the corresponding runtime. At minimum, include Windows desktop, a mobile target, and Android TV in the validation matrix.

## 17. CI and architectural enforcement

Add checks to ensure that:

- `live_uikit_wind` depends on `live_uikit` and `fluttersdk_wind` only for its core integration.
- `live_uikit_wind` does not depend on any other style adapter, including `live_uikit_fluent`.
- The core package does not depend on `fluttersdk_wind`.
- Business packages do not import `package:fluttersdk_wind/fluttersdk_wind.dart`.
- Only the registration API is exported from the barrel; builders, mappers, and `fluttersdk_wind` types stay internal.
- The declared `windUiCapabilities` set matches the methods `WindLanguageAdapter` actually overrides (the contract test enforces this).
- Formatting, static analysis, and tests pass.

Example verification commands (run from the workspace root with the repository's normal Flutter SDK and workspace resolution):

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_wind
flutter analyze packages/live_uikit_wind
flutter test packages/live_uikit_wind
```

## 18. Implementation phases

Wind ships with three native controls and a minimal theme bridge. The phases below first harden that foundation, then widen the native surface so the shared-fallback count drops control by control.

### Phase 1 — Contracts and registration (done)

- `WindLanguageAdapter` implements the finalized core contract by extending `SharedLanguageAdapter`.
- Stable id `wind`, display name `Wind`, `LiveDesignLanguage.wind` language.
- `windUiAdapter`, `createWindUiAdapter()`, `windUiAdapterId` registration API; barrel exports only the registration.
- `wind_ui_contract_test.dart` covers id/capabilities/resolver behavior.

### Phase 2 — Theme integration foundation

- Keep brightness mapping; add accent color (`color.primary`) and font (`type.fontFamily`) into `WindThemeBuilder`.
- Verify the Wind scope rebuilds on runtime token changes.
- Extend theme tests for the newly mapped properties.

### Phase 3 — Harden the current native controls

- Complete button padding/sizing/`expand`/`tooltip` and focus wiring.
- Verify switch and checkbox fully-controlled behavior and label rendering.
- Add widget tests for the three native controls across brightness and density.

### Phase 4 — First high-value native surfaces

- Add `WindCardBuilder` and `WindTextFieldBuilder` (the two most-used fallbacks today).
- Override `card` and `textField` in `WindLanguageAdapter`; add both to `windUiCapabilities`.
- Confirm the contract test flips them from `controlUnsupported` to native and the theme mapper covers the surfaces they need.

### Phase 5 — Remaining controls

- Add `WindSliderBuilder`, `WindSegmentedBuilder`, `WindProgressBuilder`, then `select` and `tabBar`.
- Update `windUiCapabilities` and the contract test's `native`/`fallback` sets in lockstep for each.

### Phase 6 — Interaction, icons, and accessibility

- Introduce `interaction/` for keyboard/focus/TV mapping on the now-larger native surface.
- Introduce `icons/` for semantic icon mapping where Wind supports it.
- Validate focus traversal, D-pad behavior, and accessibility semantics on all native controls.

### Phase 7 — Production readiness

- Add integration tests for runtime style switching (Wind in and out).
- Add architectural CI checks (§17).
- Verify all claimed platforms with real tests.
- Document known limitations and `fluttersdk_wind` upgrade compatibility.

## 19. Acceptance checklist

- [ ] The package depends on `live_uikit` and `fluttersdk_wind` only for its core integration.
- [ ] It extends `SharedLanguageAdapter` and implements the actual `LanguageAdapter` contract.
- [ ] It uses the stable adapter id `wind` (with `windUiAdapterId`, `windUiAdapter`, `createWindUiAdapter()`).
- [ ] `windUiCapabilities` declares exactly `button`, `switchWidget`, `checkbox` as native.
- [ ] The other seven controls resolve through the shared token renderer and report `controlUnsupported`.
- [ ] The barrel exports only the registration API; no builders, mappers, or `fluttersdk_wind` types leak.
- [ ] It maps the resolved `DesignToken` into `WindThemeData` and installs a Wind theme scope (brightness today, widened per §18).
- [ ] It adds no localization delegates and relies on core localization.
- [ ] It does not depend on `live_uikit_fluent` or any other style adapter.
- [ ] It does not own business state, persistence, or a nested app shell.
- [ ] Native controls preserve value/callback/controller/focus semantics and pass fully controlled state through.
- [ ] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested for the native controls.
- [ ] Diagnostics use the shared core contract (`LiveUiDiagnostic`, `LiveUiDiagnosticSink`).
- [ ] The contract test keeps `windUiCapabilities` in sync with the overrides (§17).
- [ ] Tests and static analysis pass; platform claims are backed by real tests.

## 20. Final architecture decision

`live_uikit_wind` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, the `DesignToken` theme model, runtime selection (`LiveUiResolver` + `LanguageRegistry`), the capability model, and the fallback/diagnostic policy.
- `live_uikit_wind` maps those contracts to `fluttersdk_wind`, today for three native controls.
- `fluttersdk_wind` supplies the underlying Wind widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

Wind's deliberately small native surface is a foundation, not a ceiling: everything renders correctly and stays on theme through the shared token renderer, and each control graduates to native through the phases above while `windUiCapabilities` tracks the truth. This separation lets PureLive add or replace UI styles — including growing Wind — without forcing business packages to know which library is currently rendering their controls.
