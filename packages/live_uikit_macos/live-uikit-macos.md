# `live_uikit_macos` Architecture and Integration Specification

- **Package:** `live_uikit_macos`
- **Parent package:** `live_uikit`
- **Implementation library:** `macos_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_macos` is the macOS design-language adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `macos_ui` controls and macOS-specific visual behavior. It must not implement business pages or duplicate the core theme system.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_macos
       |
       v
   macos_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `macos_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **macOS owns macOS visuals.** Use native `macos_ui` controls wherever practical rather than drawing macOS-style controls from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from the macOS style to another style must not require business pages to import or construct different control classes.
6. **Platform-aware behavior.** The macOS style can be selected on any supported platform, but native macOS window chrome and system integrations must not be assumed on every platform.
7. **Graceful fallback.** Only four controls are implemented natively; every other control falls back to the core shared token renderer and is reported through a `controlUnsupported` diagnostic. Fallback is expected and observable, never silent.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- macOS theme mapping from the resolved `DesignToken` into a `macos_ui` theme and scope.
- macOS widget construction for the four natively supported controls.
- macOS-specific control defaults.
- Focus and keyboard interaction behavior for the native controls.
- Mapping shared control specifications to `macos_ui` controls.
- Reporting implemented capabilities to the core registry through `macosUiCapabilities`.
- Adapter-level tests and contract-compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The multi-style selector UI.
- Shared design-token definitions.
- Global configuration storage.
- Riverpod, GetX, or other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Localization delegates (see §14).
- Direct dependencies on other style adapters.

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts and tokens |
| `macos_ui` | Yes | Native macOS controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_cupertino_ui` | No | Adapters must remain independent |
| `live_uikit_material_ui` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

Current real structure:

```text
packages/
└── live_uikit_macos/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_macos.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── macos_ui_adapter.dart
    │       │   ├── macos_ui_capabilities.dart
    │       │   └── macos_ui_registration.dart
    │       ├── theme/
    │       │   ├── macos_theme_builder.dart
    │       │   ├── macos_theme_mapper.dart
    │       │   └── macos_theme_scope.dart
    │       └── widgets/
    │           ├── macos_button_builder.dart
    │           ├── macos_text_field_builder.dart
    │           ├── macos_checkbox_builder.dart
    │           └── macos_slider_builder.dart
    ├── live-uikit-macos.md
    └── test/
        ├── adapter/
        │   └── macos_ui_contract_test.dart
        ├── theme/
        │   └── macos_theme_test.dart
        ├── widgets/
        │   └── macos_native_controls_test.dart
        └── integration/
            └── macos_style_switching_test.dart
```

Note the naming conventions in this package: the theme modules are prefixed `macos_` (not `macos_ui_`), while the adapter modules are prefixed `macos_ui_`. Keep the builder set limited to the four native controls; a builder for a shared-fallback control must not be added unless that control is promoted to native and registered in `macosUiCapabilities`.

Optional modules, not yet created. Add them only when the corresponding functionality is implemented:

```text
    │       ├── interaction/   # keyboard, focus, and TV-specific mapping
    │       ├── icons/         # semantic icon -> macos_ui icon mapping
    │       └── diagnostics/   # adapter-local diagnostics (uses core contracts)
    └── example/
        └── lib/
            └── main.dart
```

Do not create empty files just to match a tree.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration |
| `theme/` | Translate the resolved `DesignToken` into `macos_ui` theme values and scope |
| `widgets/` | Build the four native `macos_ui` controls from core widget specifications |
| `interaction/` | Map keyboard, focus, and TV-specific behavior (optional, not yet created) |
| `icons/` | Map supported semantic icons to `macos_ui` icons (optional, not yet created) |
| `diagnostics/` | Report unsupported mappings and adapter errors (optional, not yet created) |
| `test/` | Verify contract compliance and macOS rendering |
| `example/` | Demonstrate integration without business dependencies (optional, not yet created) |

## 5. Package dependencies

Current `pubspec.yaml`:

```yaml
name: live_uikit_macos
description: macOS design-language adapter for live_uikit, rendering controls with macos_ui widgets.
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  live_uikit:
  macos_ui: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Because PureLive uses a Pub workspace, `live_uikit` is provided as a workspace member rather than a pinned path. Keep that dependency aligned with the repository's workspace conventions; if all internal packages are workspace members, use the repository's chosen workspace dependency policy consistently.

The adapter should not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation.

## 6. Public API

The public entry point exposes only the adapter's registration API. Nothing else is exported.

Real entry point:

```dart
// lib/live_uikit_macos.dart

/// macOS design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6).
library;

export 'package:live_uikit_macos/src/adapter/macos_ui_registration.dart';
```

The registration surface is:

| Symbol | Kind | Purpose |
|---|---|---|
| `createMacosUiAdapter()` | function | Returns the macOS adapter for the composition root to register |
| `macosUiAdapter` | `const LanguageAdapter` | The const adapter instance |
| `macosUiAdapterId` | `const String` | The stable runtime id `'macos'` |

Do not export internal widget builders, the theme mapper/scope/builder, the capabilities constant, or third-party `macos_ui` types. Consumers reach capabilities through the adapter instance, not through a package-level export.

## 7. Adapter contract

The adapter implements the finalized core contract; the names below are fact, not aspiration.

`live_uikit` declares:

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

`SharedLanguageAdapter` is the token-driven base renderer: it provides a working default for every control built from the core `LiveBox` and recipes, plus helpers (`interactive`, `labelled`, `buttonLabel`) adapters reuse. A library adapter extends `SharedLanguageAdapter` and overrides only the controls it maps to a real widget, plus `wrap`. Unoverridden controls keep rendering on-theme through the base.

This package's implementation:

```dart
class MacosLanguageAdapter extends SharedLanguageAdapter {
  const MacosLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.macos;
  @override String get id => 'macos';
  @override String get displayName => 'macOS';
  @override LiveUiCapabilities get capabilities => macosUiCapabilities;

  @override Widget wrap(BuildContext context, DesignToken token, Widget child);
  @override Widget button(BuildContext context, LanguageButtonSpec spec);
  @override Widget textField(BuildContext context, LanguageTextFieldSpec spec);
  @override Widget checkbox(BuildContext context, LanguageCheckboxSpec spec);
  @override Widget slider(BuildContext context, LanguageSliderSpec spec);
}
```

### Adapter identifier

Use one stable identifier everywhere:

```text
macos
```

The identifier is a machine-readable value used by the registry, persistence, and diagnostics — not a localized label. Do not use `macos_ui`, `macOS UI`, or a platform-dependent identifier as the runtime style id. The human-facing name for the style selector is `macOS`, carried by `displayName`.

### Capability declaration

The adapter reports actual supported controls, not blanket support. `macosUiCapabilities` declares exactly four:

```dart
const LiveUiCapabilities macosUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
});
```

`LiveUiCapabilities` wraps a `Set<LiveUiControl>` and exposes `supports(control)`. `LiveUiControl` is the resolver's stable control identity: `button, card, textField, switchWidget, checkbox, slider, segmented, progress, select, tabBar`.

| Control | Implementation | Reported kind |
|---|---|---|
| Button | Native `macos_ui` button | `adapterNative` |
| Text field | Native `macos_ui` text input | `adapterNative` |
| Checkbox | Native `macos_ui` checkbox | `adapterNative` |
| Slider | Native `macos_ui` slider | `adapterNative` |
| Card | Core shared token renderer | `shared` + `controlUnsupported` |
| Switch | Core shared token renderer | `shared` + `controlUnsupported` |
| Segmented | Core shared token renderer | `shared` + `controlUnsupported` |
| Progress | Core shared token renderer | `shared` + `controlUnsupported` |
| Select | Core shared token renderer | `shared` + `controlUnsupported` |
| Tab bar | Core shared token renderer | `shared` + `controlUnsupported` |

The capability model distinguishes:

- **Native** (`LiveImplementationKind.adapterNative`): built with a real `macos_ui` widget by this adapter.
- **Shared** (`LiveImplementationKind.shared`): served by the core token renderer — either because no adapter is registered or because the adapter does not declare the control.
- **Custom** (`LiveImplementationKind.custom`): an application-registered override for that control at the composition root.

This set must stay in sync with the methods `MacosLanguageAdapter` actually overrides; §17 makes that a CI assertion and §16 a test.

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized `DesignToken`. This adapter translates that token into `macos_ui` theme values and installs the matching scope.

The data flow is:

```text
LiveConfig
     |
     v
  DesignToken  (resolved by the core)
     |
     v
MacosThemeMapper.wrap(context, token, child)
     |
     v
MacosThemeScope
     |
     v
macos_ui themed controls
```

`MacosLanguageAdapter.wrap` delegates to `MacosThemeMapper`, which returns `MacosThemeScope(token: token, child: child)`. Theme value construction lives in `macos_theme_builder.dart`; the scope wires the resulting `macos_ui` theme into the subtree.

### 8.1 Theme properties to map

`MacosThemeBuilder.build` maps three properties today. The remaining rows are the
properties `macos_ui` can in principle carry but which this adapter deliberately does
not wire, because the fork's equivalents are fixed-typed or per-control — §8.1 forbids
half-mapping them into the token and calling it a theme.

| Core theme property | macOS mapping | Status |
|---|---|---|
| Brightness | `MacosThemeData.brightness` from `token.isDark` | Mapped |
| Accent / primary color | `MacosThemeData.primaryColor` from `token.color.primary` | Mapped |
| Surface / background | `MacosThemeData.canvasColor` from `token.color.surface` | Mapped |
| Font family | `MacosThemeData.typography` family | Not mapped — `typography` is a fixed `Typography` object the fork builds from its own SF sizes, so a token family cannot be folded in without replacing the whole scale |
| Text styles | `macos_ui` typography roles | Not mapped — same reason; role styles come from `LiveTheme.text` at the builder level |
| Density | Control-specific sizing (`ControlSize` on the button spec) | Control-level only; no token-driven global density |
| Focus appearance | Keyboard focus ring | Fork default; verify against the resolved `macos_ui` version before claiming token control (§12) |
| Transparency | Vibrancy / material effects | Not mapped — the library's vibrancy is per-surface, and the resolved `canBlur` affordance flag is not read here (it gates `LiveBox` blur in the token renderer today) |
| Motion | Supported `macos_ui` transitions | Not mapped — do not imply global animation control |

Avoid forcing every style adapter to use identical widget dimensions. The core tokens define shared design intent; this adapter translates that intent into the closest appropriate macOS presentation.

### 8.2 Theme scope

The adapter must provide a macOS theme scope around the widgets it builds. Prefer `MacosTheme`-style scoping supplied by `macos_ui`.

Do not nest a `MacosApp` application shell inside an existing PureLive app solely to apply macOS styling. A nested application widget introduces competing navigation, localization, and application-level configuration. Use an application shell only when the composition root deliberately chooses it.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `MacosThemeMapper.wrap` runs again with the new token.
4. `MacosThemeScope` rebuilds.
5. Business state remains owned by the business widgets and controllers.

Do not cache a mapped macOS theme permanently if its source configuration can change; rebuild or invalidate when the resolved token changes.

## 9. Control implementation rules

Each native builder converts a core specification into a `macos_ui` widget.

### Button (`MacosButtonBuilder`)

- Map primary, secondary, subtle, and destructive intent to supported `macos_ui` button variants; the core `ControlSize` maps onto `macos_ui`'s small/regular/large sizes.
- Press eligibility, loading spinner and label+icon layout come from `SharedLanguageAdapter.interactive` and `buttonLabel`, so a macOS button cannot disagree with a token-rendered one (§2.3).
- `expand` wraps the button in `SizedBox(width: double.infinity)`; `tooltip` wraps it in the core's language-neutral `LiveTooltip` and is also passed as the fork's `semanticLabel`, which is the accessible name an icon-only button needs.
- `focusNode` and `autofocus` are **not expressible**: `PushButton` creates and owns its focus handling, and wrapping the button in a second `Focus` would hold the focus that actually performs keyboard activation. Recorded as an unmappable spec field (§15); `test/widgets/` asserts nothing crashes when they are supplied.
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

### Text field (`MacosTextFieldBuilder`)

- Use the native `macos_ui` text input.
- Preserve the supplied controller, focus node, callbacks, enabled/read-only/obscure state, `maxLines`, keyboard type and action, prefix/suffix, and `style` override.
- Do not create a second controller or silently own its lifecycle; when the spec's controller is null, the field owns the one it creates.
- The fork has no error slot: `errorText` redraws the decoration border in the token error colour and adds the caption line beneath, the same two signals the token renderer sends (§15).

### Checkbox (`MacosCheckboxBuilder`)

- Use the native `macos_ui` checkbox.
- Preserve value, `onChanged`, `label`, `enabled`, `focusNode`, and `autofocus`.
- A null `onChanged` or `enabled: false` must render disabled without swallowing state.
- If `macos_ui` lacks a requested state under the core contract, fall through to the shared renderer and let the resolver report it.

### Slider (`MacosSliderBuilder`)

- Use the native `macos_ui` slider, passing `min`/`max` to the fork (it asserts `min <= value <= max`) and clamping the value to the range.
- `MacosSlider.onChanged` is required and non-nullable, so a disabled slider — `enabled: false` or a null `onChanged` — has no native form. `MacosLanguageAdapter.slider` routes exactly that case to `super.slider`, the shared token renderer, instead of passing a closure that swallows the value (§15). An earlier version did precisely that, which made a dead slider look live.
- `focusNode` is not a parameter of `MacosSlider` and is recorded as unmappable rather than emulated.

### Shared-fallback controls

Card, switch, segmented, progress, select, and tab bar are **not** overridden. They render through `SharedLanguageAdapter` using the token renderer, so they still appear on-theme inside the macOS scope, and the resolver reports each one with a `controlUnsupported` diagnostic whose `kind` is `shared`. This is the expected configuration, not a defect and not a silent degradation. Promoting any of them to native requires: adding a builder, overriding the adapter method, and adding the `LiveUiControl` to `macosUiCapabilities` in the same change.

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder may receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup.

```dart
void registerUiAdapters(LanguageRegistry registry) {
  registry.register(createMacosUiAdapter());
}
```

Registration surface (see §6): `createMacosUiAdapter()`, `macosUiAdapter` (const), `macosUiAdapterId`.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active language through `UiConfig.language`.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_macos` must not register itself through global static initialization or require the business layer to import it.

### Resolution and failure

Runtime resolution is performed by `LiveUiResolver` against the `LanguageRegistry`, emitting `LiveUiDiagnostic` events. The relevant codes are:

| Code | Condition |
|---|---|
| `adapterMissing` | The selected language has no registered adapter; everything renders shared |
| `defaultAdapterMissing` | No default/fallback adapter is available to resolve against |
| `controlUnsupported` | The adapter is present but does not declare this control; shared renderer used |
| `unsupportedEffect` | A requested visual effect cannot be produced; documented fallback used |

Diagnostics are delivered to a host-supplied `LiveUiDiagnosticSink`, never to a concrete logging package.

The registry should detect duplicate adapter ids, invalid capability declarations, and unsupported control requests. When macOS is unavailable, the core fallback policy chooses an available implementation or reports a clear error; do not silently switch styles.

## 11. Runtime style switching

A business widget uses only the core API:

```dart
LiveButton(
  label: 'Save',
  onPressed: saveSettings,
)
```

It must not contain conditional style selection:

```dart
// Avoid style-specific branching in business packages.
if (style == 'macos') {
  // Build a macos_ui button.
} else {
  // Build another library's button.
}
```

The rendering flow is:

```text
Business widget
      |
      v
  LiveButton
      |
      v
 LiveUiResolver  (LanguageRegistry + UiConfig.language)
      |
      v
Selected adapter
      |
      +---- macOS adapter (live_uikit_macos)
      +---- Fluent adapter
      +---- Material adapter
      +---- Cupertino adapter
      +---- Other registered adapters
```

Switching adapters changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services.

## 12. Keyboard, focus, and pointer support

macOS is a desktop-first aesthetic, so this adapter is expected to be exercised with keyboard and pointer input. PureLive also targets Android TV and mobile, so the same adapters must degrade sensibly under touch and D-pad.

The adapter should account for:

- Keyboard navigation and focus traversal order.
- Visible focus indication consistent with macOS conventions.
- Enter and Space activation semantics.
- Disabled controls being skipped in traversal.
- Focus restoration after dialogs or menus.
- Pointer hover feedback on native controls where `macos_ui` provides it.
- Predictable focus behavior after runtime style switching.
- Accessibility semantics for interactive controls.
- Remote-control navigation on Android TV when the macOS style is selected there.

Focus-related plumbing beyond the four native controls is not yet factored into an `interaction/` module; add it when behavior needs a home rather than scattering it across builders (see §4).

Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility. Test the actual controls with supported TV input devices and use the core interaction policy to fill gaps.

## 13. Platform behavior

The macOS style is a visual choice, not a declaration that every operating system provides native macOS controls. The adapter can be selected on any platform; the primary fit is macOS desktop.

| Platform | Expected behavior |
|---|---|
| macOS | Primary fit: native `macos_ui` controls, desktop keyboard, pointer and hover, native application integration |
| Windows | macOS visual style with graceful fallback; retain appropriate Windows integration |
| Linux | macOS visual style; verify platform-specific rendering and dependencies |
| Android | macOS visual style with touch-friendly sizing |
| Android TV | macOS visual style plus explicit D-pad and focus testing |
| iOS | macOS visual style while retaining iOS lifecycle and accessibility behavior |

Vibrancy, transparency, and window-material effects must degrade gracefully where unavailable or inappropriate. Native macOS window APIs must never become a required dependency of the basic adapter.

## 14. Localization and accessibility

This adapter deliberately adds **no localization delegates**. `macos_ui` widgets reuse the Material/Cupertino localization already supplied by the core, so `live_uikit_macos` exports nothing beyond its registration API (see §6). This is a distinguishing point against the Fluent, Material-UI, and Cupertino-UI adapters, which may require additional delegates coordinated through the composition root.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints from the specs.
- Use the application's localization configuration as the single locale source.
- Never independently override the global locale.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast, and pointer/touch target sizing.

If a future native control genuinely requires an extra delegate, document the requirement and wire it through the application composition root; do not add it silently inside this package.

## 15. Error handling and diagnostics

Report structured diagnostics for meaningful failures, such as:

- An unsupported control or variant.
- An invalid specification.
- A theme property that cannot be mapped directly.
- A missing icon mapping.
- A failed fallback.
- An adapter initialization or registration error.

Use the core diagnostics contracts: `LiveUiDiagnostic` (carrying `code`, `language`, optional `control`, and resolved `kind`) delivered to a `LiveUiDiagnosticSink`, with codes from `live_uikit`'s diagnostic code set. Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- The six shared-fallback controls produce `controlUnsupported` diagnostics with `kind: shared`. This is the declared, expected configuration; tests assert it rather than treat it as failure.
- Unsupported visual variants may use a documented fallback.
- Invalid control data follows core validation rules.
- Programming errors must not be swallowed.
- Diagnostics must avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Contract tests (`test/adapter/macos_ui_contract_test.dart`)

- Stable adapter id `macos`, `displayName` `macOS`, `language` `LiveDesignLanguage.macos`.
- `macosUiCapabilities` declares exactly button, textField, checkbox, slider — and the
  same comparison holds against the methods `MacosLanguageAdapter` overrides (§17).
- Through the real `LanguageRegistry` + `LiveUiResolver`: a registered macOS resolves
  `adapterNative`; a declared control resolves native with no diagnostic; an undeclared
  control falls back to `shared` and is reported.

### Theme tests (`test/theme/macos_theme_test.dart`)

- Brightness, `primaryColor` and `canvasColor` follow the resolved token (§8.1), and a
  dark token yields a different canvas than the light one (§8.3).
- Toggling brightness re-skins through `wrap`, with no restart.
- Typography and density are deliberately *not* mapped — `accentColor` is macOS's own
  fixed swatch and its typography is a `MacosTypography` object (§8.1 "map only
  supported") — so there is nothing here to assert, and §8.1 says so.

### Widget tests (`test/widgets/macos_native_controls_test.dart`)

Driven through a real `LiveConfigProvider` with the adapter registered, so the dispatch path itself is under test:

- Button: callback when enabled, input rejected while loading, and `expand`, `tooltip`
  with the accessible label reaching the control.
- Text field: controller and `onChanged` pass-through; prefix, suffix and the error
  message; an inline `Style` overriding the token body text; and the caller's `FocusNode`
  being the node that actually takes focus (§9/§16).
- Checkbox: reporting the next value, and a null callback reaching the fork as null
  rather than a swallowing closure.
- Slider: rendering natively, and a disabled slider taking the documented shared fallback
  (§9) instead of the fork's own disabled rendering.
- An unoverridden control still renders through the shared fallback.

Not covered: accessibility semantics and layout under narrow versus wide constraints —
the fork's focus ring, keyboard traversal and screen-reader behaviour are §12/§19 hardware
items, and this suite does not claim them.

### Integration tests (`test/integration/macos_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: four `adapterNative`, six `shared` with `controlUnsupported`.
- macOS → core `material` → macOS swaps `macos.MacosTextField`/`MacosCheckbox`/`MacosSlider` for the token renderer and back, with the caller's controller text preserved.
- `adapterMissing` is reported for the core base only; while macOS is active the sink sees exactly the six undeclared controls' `controlUnsupported` entries (§15.5).
- Select — shared in this language — still returns its typed value after the switch (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum, include macOS desktop, a mobile target, and Android TV in the planned validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_macos` depends on `live_uikit` and `macos_ui` only for its core integration.
- `live_uikit_macos` does not depend on other style adapters (`live_uikit_fluent`, `live_uikit_cupertino_ui`, `live_uikit_material_ui`, `live_uikit_glass`, `live_uikit_neumorphic`, `live_uikit_wind`).
- The core package does not depend on `macos_ui`.
- Business packages do not import `package:macos_ui/macos_ui.dart`.
- The public barrel exports only `src/adapter/macos_ui_registration.dart`.
- The adapter exports no localization delegates.
- `macosUiCapabilities` matches the set of methods `MacosLanguageAdapter` overrides, and matches the builders under `widgets/`.
- Every `package:macos_ui/` import inside this package uses the `as macos` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `macosUiCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_macos
flutter analyze packages/live_uikit_macos
flutter test packages/live_uikit_macos
```

Run these from the workspace root with the repository's normal Flutter SDK and workspace resolution.

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Align the adapter with the finalized core contract. Done: `MacosLanguageAdapter extends SharedLanguageAdapter`, id `macos`, capabilities constant, registration exports.
- Register macOS from the application composition root.
- Keep the contract test green as the guard on id, language, and capabilities.

### Phase 2 — Theme integration ✅

- Complete theme mapping in `macos_theme_builder.dart` / `macos_theme_mapper.dart`.
- Verify `MacosThemeScope` installation through `wrap`.
- Test brightness, `primaryColor` and `canvasColor`; typography and density stay at the
  fork's defaults, since `accentColor` is a fixed `AccentColor` swatch and its typography
  is a `MacosTypography` object the token cannot name (§8.1).
- Verify runtime theme updates and invalidation.

### Phase 3 — Native control coverage ◐

- Extend testing for the four native controls: button, text field, checkbox, slider.
- Then, only where product value justifies it, promote shared controls: card, switch, segmented, progress, select, tab bar. Each promotion adds a builder, an override, and a capability entry in one change.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: caller state, callbacks and the spec fields `macos_ui` can carry are asserted in `test/widgets/`; the fields it cannot take (`focusNode`/`autofocus` on `PushButton`, `focusNode` on `MacosSlider`) are documented in §9 rather than faked.
- Open, needs hardware: focus traversal, hover behavior, Android TV D-pad.
- Factor keyboard, focus, and hover behavior into an `interaction/` module when it needs a home.
- Test Android TV D-pad behavior under the macOS style.
- Validate semantics and accessibility.
- Add documented fallbacks for unsupported variants.

### Phase 5 — Production readiness ◐

- The architectural CI checks in §17 are enforced by `tool/check_architecture.ps1` (library boundary, `macos` import prefix, registration-only barrel, capability/override match).
- Open: integration tests for style switching.
- Verify all claimed platforms.
- Optionally add `icons/`, `diagnostics/`, and `example/`.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `macos_ui` only for its core integration.
- [x] It implements the actual core `LanguageAdapter` contract via `SharedLanguageAdapter`.
- [x] It uses the stable adapter id `macos` and display name `macOS`.
- [x] `macosUiCapabilities` reports exactly button, textField, checkbox, slider as native.
- [x] Card, switch, segmented, progress, select, and tab bar fall back to the shared renderer and are reported via `controlUnsupported`.
- [x] It maps the resolved `DesignToken` into `macos_ui` theme values through `MacosThemeMapper` and `MacosThemeScope`.
- [x] It uses native `macos_ui` controls where supported.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell.
- [x] It adds no localization delegates, reusing the core Material/Cupertino localization.
- [x] The public barrel exports only `src/adapter/macos_ui_registration.dart`.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, pointer, accessibility, and TV focus behavior are tested — a caller's `FocusNode` reaching the field's focus tree is (§16), but pointer hover, the fork's focus ring and D-pad traversal need a Mac and a TV runtime.
- [x] Unsupported features follow the core fallback policy with observable diagnostics.
- [x] Diagnostics use the shared core contracts and a host sink, not a logging package.
- [x] Tests and static analysis pass for `packages/live_uikit_macos`.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_macos` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, `DesignToken` model, runtime selection via `LiveUiResolver` and `LanguageRegistry`, and the fallback and diagnostic policy.
- `SharedLanguageAdapter` provides the token-driven base renderer that this adapter extends.
- `live_uikit_macos` maps those contracts to macOS presentation: four native `macos_ui` controls, everything else through the shared renderer.
- `macos_ui` supplies the underlying macOS widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences; this package adds no localization delegates of its own.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive offer a desktop-first macOS aesthetic — with native keyboard and pointer interaction and native macOS application integration on its primary platform, and graceful visual fallback everywhere else — without forcing business packages to know which UI library is currently rendering their controls.
