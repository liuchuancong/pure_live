# `live_uikit_material_ui` Architecture and Integration Specification

- **Package:** `live_uikit_material_ui`
- **Parent package:** `live_uikit`
- **Implementation library:** `material_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_material_ui` is the Material UI adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into real controls from the `material_ui` package — a fork of Flutter's Material widgets — and applies that fork's own styling on top of the core design tokens. It must not implement business pages or duplicate the core theme system.

This adapter occupies a specific and easily confused position in the seven-style matrix, and the distinction must stay explicit:

- The core `LiveDesignLanguage.material` base is the **token-driven shared renderer**. It draws controls from `LiveBox` plus the recipes using Flutter's Material primitives as its fallback vocabulary. It is the language every other adapter inherits from, not a package.
- `live_uikit_material_ui` renders the **same visual family through a third-party widget fork**. `LiveDesignLanguage.materialUi` names that fork, and `MaterialUiLanguageAdapter` is its adapter.

So Material UI is not "the core Material base, exported again". It re-skins Material-shaped controls with `material_ui`'s own theme types (`mu.ThemeData`, `mu.ColorScheme`) and its own widget classes, which lets PureLive ship Material look-and-feel with the fork's typography, spacing, and colour-generation rules rather than the SDK's. Because that vocabulary is the closest analogue to the core's own, this adapter has the widest native coverage of any style package.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_material_ui
       |
       v
   material_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `material_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **The fork owns fork visuals.** Use native `material_ui` controls wherever practical. Do not draw Material-shaped controls from scratch when the fork provides them, and do not silently substitute the Flutter SDK's Material widgets — that would make this adapter indistinguishable from the core token base.
3. **Extend, do not reimplement.** `MaterialUiLanguageAdapter` extends `SharedLanguageAdapter` and overrides only the controls it renders natively plus `wrap`. Every unoverridden control keeps working through the token renderer.
4. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
5. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
6. **Runtime switching is supported.** Switching between Material UI, the core Material base, Fluent, Cupertino, or any other style must not require business pages to import or construct different control classes.
7. **Closest-relative, not clone.** Material UI's value is a distinct rendering path with the fork's defaults. Where the fork offers no equivalent for a control, fall back rather than approximating it with hand-painted widgets.
8. **Graceful fallback.** Unsupported controls must follow the fallback policy defined by `live_uikit`, and the downgrade must be observable through diagnostics, not silently different in behavior.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Material UI theme mapping (`DesignToken` → `mu.ThemeData`).
- The Material UI theme scope installed via `wrap`.
- Material UI widget construction for the eight natively supported controls.
- Material UI-specific control defaults, including variant-to-button-class selection and progress tinting.
- Mapping shared control specifications to `material_ui` controls.
- Reporting implemented capabilities to the core registry through `materialUiCapabilities`.
- Exporting `materialUiLocalizationsDelegates` for the fork's `GlobalMaterialLocalizations` requirement.
- Adapter-level contract tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The seven-style selector UI.
- Shared design-token definitions.
- Global configuration storage.
- Riverpod, GetX, or other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Direct dependencies on other style adapters.
- A competing `LanguageAdapter`, capability, or diagnostic model.

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts, tokens, and the base adapter |
| `material_ui` | Yes | Native fork controls and theme types |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_cupertino_ui` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

Import hygiene: `material_ui` types are imported with the `mu` prefix throughout this package (`import 'package:material_ui/material_ui.dart' as mu;`). The fork deliberately shadows well-known Flutter Material names (`ThemeData`, `ColorScheme`, `FilledButton`, `LinearProgressIndicator`, `GlobalMaterialLocalizations`), so the prefix is mandatory — unqualified names would silently resolve to the SDK's Material widgets and defeat the purpose of this adapter. The alias must not leak through the public barrel.

## 4. Package directory

The tree below reflects the package as it exists today. Material UI is the most complete adapter: eight builders and three theme files are already implemented.

```text
packages/
└── live_uikit_material_ui/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── live-uikit-material-ui.md
    ├── lib/
    │   ├── live_uikit_material_ui.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── material_ui_adapter.dart
    │       │   ├── material_ui_capabilities.dart
    │       │   └── material_ui_registration.dart
    │       ├── theme/
    │       │   ├── material_ui_theme_mapper.dart
    │       │   ├── material_ui_theme_builder.dart
    │       │   └── material_ui_theme_scope.dart
    │       └── widgets/
    │           ├── material_ui_button_builder.dart
    │           ├── material_ui_card_builder.dart
    │           ├── material_ui_text_field_builder.dart
    │           ├── material_ui_switch_builder.dart
    │           ├── material_ui_checkbox_builder.dart
    │           ├── material_ui_slider_builder.dart
    │           ├── material_ui_segmented_builder.dart
    │           └── material_ui_progress_builder.dart
    └── test/
        └── adapter/
            └── material_ui_contract_test.dart
```

Optional, not-yet-created modules. Add these only when the corresponding behavior is implemented; do not create empty files just to match a template tree:

| Module | Add when |
|---|---|
| `lib/src/interaction/` | Material UI-specific focus traversal, D-pad, or keyboard mapping is required beyond the core interaction policy |
| `lib/src/icons/` | Semantic icons must be remapped to fork-specific icon assets |
| `lib/src/diagnostics/` | The adapter needs mapping-level diagnostics beyond what the core resolver already reports |
| `example/` | A runnable demo without business dependencies is worth maintaining |
| `test/{theme,widgets,integration}/` | The first test for that concern exists |

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration exports |
| `theme/` | Translate the resolved `DesignToken` into `mu.ThemeData` and install the scope |
| `widgets/` | Build native `material_ui` controls from core widget specifications |
| `test/adapter/` | Verify id, display name, language, capability declaration, and resolver behavior |
| `interaction/` *(optional)* | Map keyboard, focus, and TV-specific behavior |
| `icons/` *(optional)* | Map supported semantic icons to fork icons |
| `diagnostics/` *(optional)* | Report unsupported mappings and adapter errors |
| `example/` *(optional)* | Demonstrate integration without business dependencies |

## 5. Package dependencies

The package's `pubspec.yaml`:

```yaml
name: live_uikit_material_ui
description: Material UI design-language adapter for live_uikit, rendering controls with the material_ui package.
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
  material_ui: ^1.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

`live_uikit` is resolved from the Pub workspace rather than an explicit path, which is the repository's convention for workspace members; the `path: ../live_uikit` form appears only where a package must pin outside the workspace. Keep `material_ui` on a caret range and re-verify the resolved version before merging, because the fork's theme and widget API is the surface this package is built against.

The adapter should not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation. It also must not add `flutter_localizations` directly — the app's composition root already supplies localizers, and this package contributes only a delegate list.

## 6. Public API

The public entry point exposes only the adapter's registration API:

```dart
// lib/live_uikit_material_ui.dart

/// Material UI design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6).
library;

export 'package:live_uikit_material_ui/src/adapter/material_ui_registration.dart';
```

`material_ui_registration.dart` provides exactly four public symbols:

| Symbol | Kind | Purpose |
|---|---|---|
| `createMaterialUiAdapter()` | Function | Constructs the adapter for the composition root to register |
| `materialUiAdapter` | `const LanguageAdapter` | The const adapter instance, usable directly where a const is required |
| `materialUiAdapterId` | `const String` | The stable runtime id, `'materialUi'` |
| `materialUiLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | The fork's `GlobalMaterialLocalizations.delegate` for the app to append (§14) |

Do not export `MaterialUiLanguageAdapter`, the builders, the theme mapper/scope, or `materialUiCapabilities` from the barrel. The builders and `mu`-prefixed types are implementation detail; exposing them would let business packages construct Material UI widgets directly and bypass style switching. The capability set is consumed by the core resolver through the adapter's `capabilities` getter, not by importers.

The core contract is finalized, so these names are the API — not a proposal. Sections 7 through 10 below reference the actual classes and methods in `live_uikit`.

## 7. Adapter contract

`live_uikit` defines the contract as `abstract interface class LanguageAdapter`. `MaterialUiLanguageAdapter` implements it by extending `SharedLanguageAdapter`, which already provides token-driven fallbacks for every control:

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

The concrete declaration in this package:

```dart
class MaterialUiLanguageAdapter extends SharedLanguageAdapter {
  const MaterialUiLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.materialUi;
  @override String get id => 'materialUi';
  @override String get displayName => 'Material UI';
  @override LiveUiCapabilities get capabilities => materialUiCapabilities;
  @override Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);
  // plus overrides for button, card, textField, switchWidget, checkbox,
  // slider, segmented and progress
}
```

Because the class extends `SharedLanguageAdapter` rather than implementing `LanguageAdapter`, `select<T>` and `tabBar` need no code at all: they are inherited, and the shared token renderer serves them. That is the intended mechanism, not a stub.

### Adapter identifier

The stable identifier is:

```text
materialUi
```

It is machine-readable and used by the registry, persistence, and diagnostics. `id` is deliberately camelCase to match `LiveDesignLanguage.materialUi.name`; do not shorten it to `material`, `material_ui`, or `Material UI`. `material` is the core token base and a different language; `Material UI` is the localized-neutral `displayName` shown in the style selector.

`materialUiAdapterId` exists so the composition root and tests reference the id without duplicating the literal.

### Capability declaration

`materialUiCapabilities` declares exactly the eight controls the adapter overrides:

```dart
const LiveUiCapabilities materialUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
});
```

A capability is a **declaration of fact** — which methods the adapter actually overrides — and `LiveUiResolver` reports a `controlUnsupported` diagnostic for anything outside the set. The full control surface is the ten `LiveUiControl` values; `LiveUiControl` has no `text` or `icon` member, so those must not appear in a capability set.

| Control (`LiveUiControl`) | Adapter method | Implementation | Status |
|---|---|---|---|
| `button` | `button` | Native `mu.FilledButton` / `mu.ElevatedButton` / `mu.TextButton` | Implemented (Native) |
| `card` | `card` | Native Material UI card container | Implemented (Native) |
| `textField` | `textField` | Native Material UI text input | Implemented (Native) |
| `switchWidget` | `switchWidget` | Native Material UI switch | Implemented (Native) |
| `checkbox` | `checkbox` | Native Material UI checkbox | Implemented (Native) |
| `slider` | `slider` | Native Material UI slider | Implemented (Native) |
| `segmented` | `segmented` | Native Material UI segmented button | Implemented (Native) |
| `progress` | `progress` | Native `mu.LinearProgressIndicator` | Implemented (Native) |
| `select` | inherited from `SharedLanguageAdapter` | Shared token renderer | Shared fallback |
| `tabBar` | inherited from `SharedLanguageAdapter` | Shared token renderer | Shared fallback |

The capability model distinguishes three kinds via `LiveImplementationKind`:

- **`adapterNative`** — a registered adapter renders the control with its own library's widget.
- **`shared`** — the core `SharedLanguageAdapter` token renderer serves the control.
- **`custom`** — the application registered a per-control override at the composition root.

`select` and `tabBar` resolve as `shared`, not `adapterNative`. The reason is specific to this library: `LanguageSelectSpec<T>` is generic over the value type and carries typed selection, an item-label function, placeholder, and disabled semantics, while `LanguageTabsSpec` carries `LiveTab` values with index-change callbacks and token-level `spacing` control. The `material_ui` fork does not expose a Material 3 dropdown or tab-strip widget whose API can absorb that generic contract without the adapter inventing an intermediate model, and Material's own tab strip assumes a `TabController` lifecycle the adapter is forbidden to own (§2.5). Rendering them natively would require this package to take ownership of state the core assigns to the caller. Falling back keeps both controls fully functional and on-theme, at the cost of a fork-agnostic presentation, and the resolver makes that trade visible instead of silent.

Do not add `LiveUiControl.select` or `LiveUiControl.tabBar` to the capability set unless the corresponding override is written. §16 and §17 both assert that the declaration matches the overrides.

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized `DesignToken`. This adapter translates that token into `mu.ThemeData` and installs it as a scope. `LiveConfig` is the input the application mutates; the adapter never reads it directly — it consumes the already-resolved token handed to `wrap`.

The data flow is:

```text
LiveConfig
     |
     v
DesignToken (resolved by the core)
     |
     v
MaterialUiLanguageAdapter.wrap
     |
     v
MaterialUiThemeMapper
     |
     v
MaterialUiThemeScope
     |
     v
MaterialUiThemeBuilder.build  ->  mu.ThemeData
     |
     v
mu.Theme(child)  ->  native material_ui controls
```

The three theme files have distinct roles and must not be collapsed:

| File | Type | Role |
|---|---|---|
| `material_ui_theme_mapper.dart` | `MaterialUiThemeMapper` | The adapter's `wrap` entry point; delegates to the scope |
| `material_ui_theme_scope.dart` | `MaterialUiThemeScope` (widget) | Installs `mu.Theme` around `child` |
| `material_ui_theme_builder.dart` | `MaterialUiThemeBuilder` | Pure mapping: `DesignToken` → `mu.ThemeData` |

### 8.1 Theme properties to map

The current implementation maps two properties, deliberately, and both follow the token:

| Core theme property | Material UI mapping | Notes |
|---|---|---|
| Brightness | `mu.ThemeData.brightness` from `token.isDark` | Light or dark; drives control defaults |
| Accent / primary color | `mu.ColorScheme.fromSeed(seedColor: token.color.primary, brightness:)` | Seed-based generation, matching Material 3 semantics |
| Text styles | Material UI typography, with `LiveTheme.of(context).text` supplying per-control styles | Roles are applied by the builders, not the theme |
| Density / sizing | `ControlSize` on `LanguageButtonSpec`, plus `LanguageCardSpec.dense` | Per-control; do not assume a global density knob |
| Focus appearance | Fork default, plus `focusNode` / `autofocus` from the specs | Verify against the resolved fork version |
| Surface / background | `mu.ColorScheme` surfaces, with `theme.colors` overrides where the token is authoritative | Map only surfaces the fork actually exposes |
| Transparency / blur | Not applicable to Material UI | No effect to degrade; do not fabricate one |
| Motion | Fork transitions | Do not imply global animation configuration |

Seed-based colour generation is the correct choice here, because the fork derives an entire tonal palette from a single seed. That means the token's `primary` colour is an input to an algorithm rather than a literal fill colour, so secondary tones shift as the seed changes. Where a builder needs the token's exact colour rather than a derived tone — the danger button's error fill, the progress bar's tint — it supplies the colour explicitly through `styleFrom` or `color:` instead of trusting the generated scheme.

Because Material UI and the core `material` token base are visually adjacent, mapping must not collapse into "read the token back through `LiveTheme` for everything". If every visual property came from the token renderer, this adapter would produce no distinguishable style. The division to preserve: **theme-level properties go through `mu.ThemeData`; control-level intent comes from the spec and `LiveTheme`.**

Avoid forcing all seven style libraries to use identical widget dimensions. The core tokens define shared design intent; this adapter translates that intent into the closest `material_ui` presentation.

### 8.2 Theme scope

`MaterialUiThemeScope` installs the mapped theme with `mu.Theme(data: ..., child: child)` — a theme scope, not a nested application widget.

Do not nest a Material UI application shell inside an existing app solely to apply the style. A nested application widget introduces competing navigation, localization, and application-level configuration, and in this package it would additionally fight the host `MaterialApp` for the same Material-shaped inherited state.

Note the asymmetry with the Fluent adapter: `material_ui` is a Material fork, so a Material UI subtree sits *inside* an app that is very likely already a `MaterialApp`. The `mu`-prefixed theme must therefore be the nearest ancestor theme for fork widgets, and fork widgets must never be handed an SDK `Theme` or read an SDK `Material` widget. Conversely, no `material_ui` widget type may appear in the tree where a core token-rendered control is expected — mixed trees are the most likely defect class in this package, and §16 targets it.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `wrap` is invoked with the new token.
4. `MaterialUiThemeBuilder.build` derives a new `mu.ThemeData` and the scope rebuilds.
5. Existing business state remains owned by the business widgets and controllers.

`MaterialUiThemeBuilder.build` is a static pure function, so the theme must not be memoized against anything but the token. Do not cache a `mu.ThemeData` object permanently if its source token can change — the mapper holds `MaterialUiThemeMapper` as a `static const` field precisely because it is stateless.

## 9. Control implementation rules

Each control builder is an `abstract final class` with a static `build` that converts a core specification into a `material_ui` widget.

Two builders — `MaterialUiButtonBuilder` and `MaterialUiCheckboxBuilder` — take a third parameter, the `SharedLanguageAdapter` seam. The seam exists so the adapter passes itself in and the builder reuses `interactive(spec)` and `buttonLabel(spec, theme)` from the base renderer. That is the sanctioned sharing mechanism: loading spinners, icon-plus-label layout, and enabled/disable resolution are written once in core and reused, so a Material UI button cannot disagree with a token-rendered button about when it is pressable or what "loading" looks like. Builders must not re-implement that logic locally.

### Button (`MaterialUiButtonBuilder`)

- Map `ButtonVariant` to the closest Material button class: `primary` → `mu.FilledButton`, `secondary` → `mu.ElevatedButton`, `ghost` → `mu.TextButton`, `danger` → `mu.FilledButton` with `styleFrom(backgroundColor: theme.colors.error, foregroundColor: theme.colors.onPrimary)`.
- Compute `onPressed` through `seam.interactive(spec)` so disabled, loading, and no-callback states agree with the token renderer; pass `null` when not interactive.
- Build content via `seam.buttonLabel(spec, theme)`, which substitutes a spinner while `loading`.
- Preserve `focusNode` and `autofocus`; honour `spec.expand`; carry `tooltip` through without hardcoding text.
- Do not place business actions inside the adapter.

### Card (`MaterialUiCardBuilder`)

- Prefer native Material UI card visuals for the intended role.
- Preserve `child`, `padding`, `selected`, `bordered`, `dense`, and the `style` override.
- Wire `onTap` and `onLongPress` only when supplied; do not assume every card is interactive.
- Preserve `focusNode` and `autofocus` for interactive cards, and `semantics`.

### Text field (`MaterialUiTextFieldBuilder`)

- Use the native Material UI text input.
- Pass the supplied `controller` and `focusNode` through untouched. When `controller` is null, follow the core convention that the field owns one — the adapter must not create a second controller or silently own a lifecycle the caller did not delegate.
- Preserve `placeholder`, `errorText`, `enabled`, `readOnly`, `obscure`, `maxLines`, `textInputAction`, `keyboardType`, `prefix`, `suffix`, `style`, `onChanged`, and `onSubmitted`.
- Respect text direction and accessibility labels.

### Switch (`MaterialUiSwitchBuilder`)

- Use the native Material UI switch.
- Preserve `value`, `onChanged`, `enabled`, `focusNode`, and `autofocus`.
- Do not introduce local persistent state; a null `onChanged` means disabled, not ignored.

### Checkbox (`MaterialUiCheckboxBuilder`)

- Use the native Material UI checkbox, with the label rendered through the shared seam.
- Preserve `value`, `label`, `enabled`, `focusNode`, and `autofocus`.
- The core contract is a non-null `bool value`, so the adapter must not advertise an indeterminate state; if the fork supports one, it stays unreachable until `LanguageCheckboxSpec` models it.

### Slider (`MaterialUiSliderBuilder`)

- Use the native Material UI slider.
- Preserve `value`, `min`, `max`, `enabled`, and `onChanged`; a null `onChanged` or `enabled: false` disables.
- Handle invalid ranges according to the core validation contract rather than clamping silently.
- The spec has no `divisions` field; do not invent stepped behaviour this contract does not request.

### Segmented (`MaterialUiSegmentedBuilder`)

- Use the native Material UI segmented button.
- Map `labels` in order, honour `index`, and route selection through `onChanged`; a null `onChanged` or `enabled: false` disables.
- Honour `expand` so segments either share the full width or size to content.

### Progress (`MaterialUiProgressBuilder`)

- Use `mu.LinearProgressIndicator`.
- Pass `value` through unchanged: `null` means indeterminate, and the fork must render its own animation rather than the adapter substituting a determinate bar.
- Map `height` to the indicator's thickness, and tint the fill with `spec.barColor ?? theme.colors.primary` over `theme.colors.fillSecondary`.
- `showLabel` is a token-renderer affordance; if the fork's indicator cannot render a trailing percentage, document the omission rather than overlaying a hand-built label widget.

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder can receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup, using the real `LanguageRegistry` API:

```dart
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.materialUi: materialUiAdapter},
  fallback: SharedLanguageAdapter(),
);

const resolver = LiveUiResolver(registry: registry);
```

`LanguageRegistry` is keyed by `LiveDesignLanguage`, not by the string id — the id is for persistence, diagnostics, and the selector, while resolution is enum-typed. `createMaterialUiAdapter()` and `materialUiAdapter` are interchangeable; prefer the const instance where a compile-time constant is required.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference from `UiConfig.language`.
- Selecting the active language.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_material_ui` must not register itself through global static initialization or require the business layer to import it.

### Registration failure

The core resolver reports structured diagnostics rather than silently degrading. Relevant codes:

| Code | Meaning for this adapter |
|---|---|
| `LiveUiDiagnosticCode.adapterMissing` | `LiveDesignLanguage.materialUi` is not registered, so every control resolves to the shared token renderer; fired once per language change |
| `LiveUiDiagnosticCode.defaultAdapterMissing` | The registry cannot supply its shared fallback for the default language; a startup fault, never recovered silently |
| `LiveUiDiagnosticCode.controlUnsupported` | Material UI is active but the control is outside `materialUiCapabilities` — expected for `select` and `tabBar` |
| `LiveUiDiagnosticCode.unsupportedEffect` | The environment cannot afford an effect, so a verified degraded visual stands in |

Diagnostics are delivered to a host-supplied `LiveUiDiagnosticSink`, so the sink must be wired at the composition root. A `controlUnsupported` entry for `select` or `tabBar` is expected behavior for this language and should not be escalated as an error; a sink that treats it as one will produce permanent noise. Any other `controlUnsupported` for Material UI indicates capability/override drift.

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
if (style == 'materialUi') {
  // Build a Material UI button.
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
      +---- Material UI adapter  (live_uikit_material_ui -> material_ui)
      +---- Fluent adapter
      +---- Cupertino UI adapter
      +---- macOS adapter
      +---- Glass adapter
      +---- Neumorphic adapter
      +---- Wind adapter
      +---- Shared token renderer (core material base, and every fallback)
```

Switching changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services.

Material UI needs particular care here, for two reasons:

1. **Material UI ↔ core `material` is the most error-prone pair to switch.** Both are Material-shaped, so a stale `mu`-prefixed widget, an inherited `mu.Theme`, or a mis-imported Material type can survive a switch unnoticed. Switching between them must fully replace the theme scope, and §16 asserts both directions.
2. **`select` and `tabBar` are visually stable across the switch by design.** Because both are served by the token renderer in Material UI, they remain on-theme when the user moves to a style that renders them natively, and their generic `T` typing must survive the transition. This is the strongest available demonstration that the fallback policy is a first-class path rather than a degraded one.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms, so Material UI styling must be tested for more than mouse input.

The adapter should account for:

- Keyboard navigation and focus traversal, via `focusNode` and `autofocus` on the button, card, text field, switch, and checkbox specs.
- Visible focus indication appropriate to the fork's Material 3 focus treatment.
- Enter and Space activation semantics, and correct disabled-control skipping.
- Focus restoration after dialogs or menus.
- Remote-control navigation on Android TV.
- Predictable focus behavior after runtime style switching.
- Accessibility semantics for interactive controls.

Because Material UI inherits Material's focus-ring and state-layer conventions, focus indication is largely inherited from `mu.ThemeData` rather than drawn by the builders. That inheritance must be verified against the resolved `material_ui` version rather than assumed: `mu` types are not covered by Flutter SDK focus tests, so a focus treatment that exists in the SDK may or may not exist in the fork.

Do not assume that desktop keyboard behavior automatically guarantees Android TV D-pad compatibility. Test the actual controls with the supported TV input devices and use the core interaction policy to fill gaps. This package has no `interaction/` module today; if D-pad gaps require Material UI-specific handling, add `lib/src/interaction/` when the fix is implemented rather than pre-creating it.

## 13. Platform behavior

`material_ui` targets all supported platforms, so Material UI is one of the adapters with no platform exclusion. The concerns that remain are input and rendering, not availability.

| Platform | Expected behavior |
|---|---|
| Android | Material UI styling with touch-friendly sizing; the fork's Material defaults suit this target most directly |
| Android TV | Material UI styling plus explicit D-pad and focus testing; verify focus rings and target sizing at 10-foot distance |
| iOS | Material UI styling while retaining iOS lifecycle, text-input, and accessibility behavior |
| macOS | Material UI styling with keyboard and mouse; do not imply native macOS widget behavior |
| Windows | Material UI styling with full keyboard navigation; Material defaults are acceptable here but are not Windows-native |
| Linux | Material UI styling; verify platform-specific text rendering and font fallback |

Two platform notes specific to this package:

- **Material UI on macOS competes with `live_uikit_macos`.** Both are selectable on the same desktop; the app decides which is active, and neither adapter may assume it is the default.
- **Material UI on Android is visually close to the core `material` base.** If a user cannot tell them apart, that is a mapping defect, not a coincidence — §8.1 requires the fork's own theme path, and §16 requires a rendering-difference test.

No Material UI effect may depend on a native window API, and none should depend on platform view plugins.

## 14. Localization and accessibility

Unlike the Fluent adapter, `material_ui` genuinely requires its own localization delegate: the fork ships its own `GlobalMaterialLocalizations`, exposed through this package as:

```dart
const List<LocalizationsDelegate<dynamic>> materialUiLocalizationsDelegates = [
  mu.GlobalMaterialLocalizations.delegate,
];
```

The app must append it to the core's delegates in its `MaterialApp`:

```dart
MaterialApp(
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...materialUiLocalizationsDelegates,
  ],
  supportedLocales: /* the app's locale policy */,
)
```

Rules:

- Coordinate through the application composition root. This package must not install delegates itself, must not wrap the app in a localization widget, and must not override the global locale.
- Do not add `flutter_localizations` as a dependency of this package; the app supplies the localizer, and the fork's delegate is what this package contributes.
- Order matters. Append Material UI's delegate after the core's so the core's app-level strings keep priority and Material UI only supplies fork-internal strings. If Material UI's delegate is placed first, it can shadow core translations, so a test must assert core strings still resolve with Material UI active.
- The delegate is required because the fork's own widgets look up their own `GlobalMaterialLocalizations` type. The core's `MaterialApp` localizer resolves the SDK type, not the fork's, so the fork's delegate is not redundant even though both are "Material".

The adapter must also:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings, including in builder defaults.
- Preserve semantic labels and hints, and propagate `tooltip` rather than substituting generated text.
- Test long translated labels and right-to-left layouts, especially segmented controls and the label-bearing checkbox.
- Verify focus visibility, text contrast, and touch target sizing. Contrast deserves extra attention here because `mu.ColorScheme.fromSeed` generates tonal surfaces: verify `theme.colors.onPrimary` on a filled button at both extremes of the generated palette rather than trusting the fork's defaults.

## 15. Error handling and diagnostics

Report structured diagnostics through the core contracts for meaningful failures:

- A control outside `materialUiCapabilities` requested while Material UI is active.
- An invalid specification — a slider with `max <= min`, a segmented control whose `index` is out of range for `labels`, a tab index beyond `tabs.length`.
- A theme property that cannot be mapped directly into `mu.ThemeData`.
- A spec field the fork cannot express, such as `LanguageProgressSpec.showLabel`.
- An SDK-material leakage: a fork widget resolving an inherited SDK Material theme, or a core token widget receiving a `mu`-prefixed widget.
- An adapter construction or registration error.

Use the diagnostics contracts from `live_uikit` — `LiveUiDiagnostic`, `LiveUiDiagnosticCode`, `LiveUiControl`, `LiveImplementationKind`, and `LiveUiDiagnosticSink`. Do not introduce a direct dependency on Talker or another application logging implementation, and do not define adapter-local diagnostic types.

Expected behavior:

- Unsupported visual variants may use a documented fallback, and the fallback must be the shared token renderer rather than an adapter-private approximation.
- Invalid control data should follow core validation rules.
- Programming errors should not be swallowed.
- Diagnostics should avoid logging user-entered text, credentials, or other sensitive content — material for `LanguageTextFieldSpec`, where the spec carries the controller, `placeholder`, and `errorText`.
- A `mu`-import mistake fails loudly at compile time thanks to the prefix convention; a runtime type mismatch surfaces as a defunct widget rather than a diagnostic. Where a builder detects a mismatch it can act on, prefer falling back to the shared renderer and emitting a diagnostic over rendering a half-themed control.

## 16. Testing strategy

### Unit tests

`test/adapter/material_ui_contract_test.dart` already covers the highest-risk surface. It asserts:

- `adapter.id == materialUiAdapterId == 'materialUi'`.
- `adapter.displayName == 'Material UI'` and `adapter.language == LiveDesignLanguage.materialUi`.
- All eight declared controls report `capabilities.supports(...) == true`.
- `select` and `tabBar` report `capabilities.supports(...) == false`.
- A registered `LiveDesignLanguage.materialUi` resolves to `LiveImplementationKind.adapterNative`.
- A declared control resolves native with **no** diagnostic.
- An undeclared control resolves `shared` with `LiveUiDiagnosticCode.controlUnsupported`, and the diagnostic names the right control.

The registry and resolver under test are constructed as `LanguageRegistry(adapters: {LiveDesignLanguage.materialUi: adapter}, fallback: SharedLanguageAdapter())` with `LiveUiResolver(registry: registry)` — the same types production uses, so these are contract tests rather than mock tests.

Extend unit coverage with:

- Brightness mapping: `token.isDark` → `mu.ThemeData.brightness` at both values.
- Seed mapping: a changed `token.color.primary` produces a different generated `mu.ColorScheme`.
- Variant mapping: each `ButtonVariant` selects the expected `mu` button class, with `danger` carrying the error-tinted `styleFrom`.
- Interactive-state parity with the seam: disabled, loading, and null-`onPressed` specs all yield `onPressed == null`.
- Progress `value == null` staying indeterminate, and `barColor` overriding the primary tint.
- Theme invalidation when the resolved token changes.
- Unsupported-variant behavior: `showLabel` degrading as documented.

### Widget tests

Test:

- Button callback, disabled state, and loading spinner.
- Text field controller and focus-node preservation, including caller-owned controller identity across rebuilds.
- Switch and checkbox value updates, and `enabled: false` producing no callback.
- Slider range and callbacks.
- Segmented selection and `expand`.
- Card tap, long-press, `selected`, and non-interactive default.
- Correct `mu.Theme` scope, and the scope not leaking an SDK `Theme`.
- Accessibility semantics.
- Layout under narrow and wide constraints, and right-to-left.
- The two mixed-tree defects unique to this package: a fork widget never reading an SDK `Theme`, and a core token widget never receiving a `mu`-prefixed widget.

### Integration tests

1. Register Material UI alongside at least one other adapter, including the core shared fallback.
2. Select Material UI at runtime.
3. Render all ten controls; confirm eight resolve native and two through the shared renderer.
4. Change brightness and accent color without restarting the app.
5. Switch Material UI → core `material` → Material UI and back again, asserting the theme scope is replaced each time.
6. Confirm form values and business controllers remain intact across the switch.
7. Confirm `select` and `tabBar` stay functional and on-theme across a switch to a style that renders them natively.
8. Confirm the `controlUnsupported` diagnostics for `select` and `tabBar` are the only expected noise.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum include Android, an iOS or macOS target, Windows desktop, and Android TV in the planned validation matrix — Material UI has no platform exclusions, so all six claimed platforms need evidence rather than inference.

## 17. CI and architectural enforcement

Add checks to ensure that:

- `live_uikit_material_ui` depends on `live_uikit` and `material_ui`.
- `live_uikit_material_ui` does not depend on any other style adapter.
- The core package does not depend on `material_ui`.
- Business packages do not import `package:material_ui/material_ui.dart`.
- Every `material_ui` import inside this package uses the `mu` alias, and no unqualified Material widget name in `lib/src/` resolves to the SDK.
- The public barrel exports only `src/adapter/material_ui_registration.dart`.
- `materialUiCapabilities` matches the set of control methods `MaterialUiLanguageAdapter` actually overrides — a CI assertion, not only a test. This check is what catches the drift where a builder is added but its control is never declared, or a control is declared without an override.
- Formatting, static analysis, and tests pass.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_material_ui
flutter analyze packages/live_uikit_material_ui
flutter test packages/live_uikit_material_ui
```

Run these from the workspace root with the repository's normal Flutter SDK and workspace resolution.

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Implement `MaterialUiLanguageAdapter extends SharedLanguageAdapter`.
- Define the stable id `materialUi`, `displayName` `Material UI`, and `language` `LiveDesignLanguage.materialUi`.
- Declare `materialUiCapabilities` and export the registration API.
- Add `material_ui_contract_test.dart` covering id, capability truthfulness, and resolver behavior.

Done.

### Phase 2 — Theme integration ✅

- `MaterialUiThemeMapper` wired to `wrap`.
- `MaterialUiThemeScope` installing `mu.Theme`, `MaterialUiThemeBuilder` mapping brightness and seed colour.
- Remaining: typography, density, and per-surface mapping as those properties become meaningful in the fork; plus the theme-scope and leakage widget tests in §16.

### Phase 3 — Core controls ✅

Implemented across the eight `lib/src/widgets/` builders: button, card, text field, switch, checkbox, slider, segmented, progress. Remaining: per-builder widget tests and documentation of degraded spec fields.

### Phase 4 — Interaction and accessibility

- Verify keyboard navigation, focus traversal, and visible focus under `mu.ThemeData`.
- Test Android TV D-pad behavior; add `lib/src/interaction/` only if Material UI-specific gaps are found.
- Validate semantics, contrast across generated tonal surfaces, and RTL layout.
- Document fallbacks for unsupported variants such as `LanguageProgressSpec.showLabel`.

### Phase 5 — Production readiness

- Integration tests for style switching, including Material UI ↔ core `material` both directions.
- Architectural CI checks from §17, including the capability/override drift assertion and the `mu`-alias check.
- Verify all six claimed platforms with evidence.
- Document known limitations (select and tabs as shared fallbacks) and upgrade compatibility for `material_ui`.

A later phase may add native `select` and `tabBar` rendering if the fork exposes widgets that can absorb `LanguageSelectSpec<T>` and `LanguageTabsSpec` without the adapter owning caller state. Any such control must be added to `materialUiCapabilities` and the contract test in the same change.

## 19. Acceptance checklist

- [ ] The package depends on `live_uikit` and `material_ui` only for its core integration.
- [ ] It extends `SharedLanguageAdapter` and implements the real core `LanguageAdapter` contract without a competing interface.
- [ ] It uses the stable adapter id `materialUi`, with `displayName` `Material UI` and `language` `LiveDesignLanguage.materialUi`.
- [ ] `materialUiAdapterId`, `materialUiAdapter`, `createMaterialUiAdapter()` and `materialUiLocalizationsDelegates` are exported, and the barrel exports nothing else.
- [ ] It reports accurate control capabilities: the eight overrides native, `select` and `tabBar` as shared fallbacks.
- [ ] The declared capability set matches the overridden methods, asserted in CI.
- [ ] It maps the resolved `DesignToken` into `mu.ThemeData` rather than bypassing the fork's theme.
- [ ] It uses native `material_ui` controls where supported and never the SDK Material widgets in their place.
- [ ] Every `material_ui` import is `mu`-aliased and the alias does not leak into the public API.
- [ ] It installs a `mu.Theme` scope rather than a nested application shell.
- [ ] It does not duplicate the core theme configuration or own business state or persistence.
- [ ] Builders reuse `interactive()` and `buttonLabel()` through the shared seam instead of reimplementing them.
- [ ] Runtime switching preserves business state, including Material UI ↔ core `material` both directions.
- [ ] `select` and `tabBar` remain functional and on-theme through the shared renderer, with typed selection preserved.
- [ ] `materialUiLocalizationsDelegates` is documented as appended to the core delegates, and core strings still resolve with Material UI active.
- [ ] Keyboard, accessibility, and TV focus behavior are tested.
- [ ] Unsupported features follow the core fallback policy and report `controlUnsupported`.
- [ ] Diagnostics use the shared core contract and no logging dependency.
- [ ] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_material_ui` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection, and fallback policy.
- `live_uikit_material_ui` maps those contracts to Material UI: `MaterialUiLanguageAdapter` overriding eight controls plus `wrap`, with `materialUiCapabilities` declaring exactly that set.
- `material_ui` supplies the underlying forked Material widgets and theme facilities.
- The PureLive application composition root registers the adapter, appends `materialUiLocalizationsDelegates`, and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This package is the widest-coverage adapter, and its risk is the mirror image of that completeness. Its value is a genuinely distinct Material rendering path; its failure mode is collapsing into the core `material` token base and becoming indistinguishable from it. The seed-based `mu.ThemeData` path, the mandatory `mu` import alias, the capability/override drift assertion, and the mixed-tree tests all exist to keep that line sharp.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls.
