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

The tree below reflects the package as it exists today. Material UI is the most complete adapter: eight builders and three theme files are implemented, and every §16 concern that does not need a device — contract, theme mapping, native controls, and runtime switching — has its own test directory.

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
        ├── adapter/
        │   └── material_ui_contract_test.dart
        ├── theme/
        │   └── material_ui_theme_test.dart
        ├── widgets/
        │   └── material_ui_native_controls_test.dart
        └── integration/
            └── material_ui_style_switching_test.dart
```

Optional, not-yet-created modules. Add these only when the corresponding behavior is implemented; do not create empty files just to match a template tree:

| Module | Add when |
|---|---|
| `lib/src/interaction/` | Material UI-specific focus traversal, D-pad, or keyboard mapping is required beyond the core interaction policy |
| `lib/src/icons/` | Semantic icons must be remapped to fork-specific icon assets |
| `lib/src/diagnostics/` | The adapter needs mapping-level diagnostics beyond what the core resolver already reports |
| `example/` | A runnable demo without business dependencies is worth maintaining |

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
| Text styles | `mu.ThemeData.fontFamily` from `token.type.fontFamily`; role sizes stay at the fork's typography | Mapped for the family only — the roles come from `LiveTheme.of(context).text` in the builders, which is where `Language*Spec` intent is applied (§8.1) |
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

Under the theme it installs one more thing: a transparent `mu.Material`. Fork ink widgets resolve their paint surface by *type*, and a host `MaterialApp`/`Scaffold` only supplies the SDK's `Material`, so a fork `TextField`, `Switch` or `Card` throws "No Material widget found" without it. Making the scope provide the surface is what keeps §1's rule intact — a page must not have to know which library is rendering it. A transparent `Material` is a paint surface, not a shell: it owns no navigation, no localization and no application configuration, so it does not fight the host `MaterialApp` for inherited state.

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
- Preserve `focusNode` and `autofocus` — the fork's buttons take both directly.
- `expand` wraps the built button in `SizedBox(width: double.infinity)` and `tooltip` wraps it in `mu.Tooltip`, the same two post-wraps the token renderer applies, because neither is a constructor argument of a Material button. The tooltip text is the caller's, never generated.
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

### Card (`MaterialUiCardBuilder`)

- Prefer native Material UI card visuals for the intended role.
- Preserve `child`, `padding`, `selected`, `bordered` and `dense`; `dense` tightens the token padding by the same factor the token renderer uses, so the density step means the same thing in both paths.
- Read the `style` override only for what a Material card can express — `background`, `borderColor`, `borderWidth`, `borderRadius` — and leave the rest as library defaults rather than hand-painting it (§8.1 "map only supported").
- Wire `onTap` and `onLongPress` only when supplied; do not assume every card is interactive. `focusNode` and `autofocus` reach the ink well only for an interactive card, so a plain surface never takes focus.

### Text field (`MaterialUiTextFieldBuilder`)

- Use the native Material UI text input.
- Pass the supplied `controller` and `focusNode` through untouched. When `controller` is null, follow the core convention that the field owns one — the adapter must not create a second controller or silently own a lifecycle the caller did not delegate.
- Preserve `placeholder`, `errorText`, `enabled`, `readOnly`, `obscure`, `maxLines`, `textInputAction`, `keyboardType`, `prefix`, `suffix`, `style`, `onChanged`, and `onSubmitted`. The inline `style` layers onto the token body text through `TextStyle.copyWith`, so an unset property keeps the token value.

### Switch (`MaterialUiSwitchBuilder`)

- Use the native Material UI switch.
- Preserve `value`, `onChanged`, `enabled`, `focusNode`, and `autofocus`.
- Do not introduce local persistent state; a null `onChanged` means disabled, not ignored.

### Checkbox (`MaterialUiCheckboxBuilder`)

- Use the native Material UI checkbox, with the label rendered through the shared seam.
- Preserve `value`, `label`, `enabled`, `focusNode`, and `autofocus`.
- The label-to-callback bridge exists only when the caller can be called back: `enabled: false` **or** a null `onChanged` passes `null` to the fork, so a dead checkbox never lights up as though it responded.
- The core contract is a non-null `bool value`, so the adapter must not advertise an indeterminate state; if the fork supports one, it stays unreachable until `LanguageCheckboxSpec` models it.

### Slider (`MaterialUiSliderBuilder`)

- Use the native Material UI slider, clamped to the spec range, with the caller's `focusNode` preserved.
- Preserve `value`, `min`, `max`, `enabled`, and `onChanged`; a null `onChanged` or `enabled: false` disables.
- Handle invalid ranges according to the core validation contract rather than clamping silently.
- **A disabled slider is the documented exception to native rendering.** `material_ui` 1.6.0 reads its focus node as `widget.focusNode ?? _focusNode!` and only creates `_focusNode` for an enabled slider, so a disabled `mu.Slider` throws while building. The adapter routes that one case to `super.slider`, the shared token renderer — on-theme, functional, and reported by the resolver as `shared` (§15). The fork fix retires the branch.
- The spec has no `divisions` field; do not invent stepped behaviour this contract does not request.

### Segmented (`MaterialUiSegmentedBuilder`)

- Use the native Material UI segmented button.
- Map `labels` in order, honour `index`, and route selection through `onChanged`; a null `onChanged` or `enabled: false` disables — as with the checkbox, the closure is only built when a callback exists.
- Honour `expand` through the fork's own `expandedInsets: EdgeInsets.zero`, so segments share the full width instead of the adapter faking it with a width hack.

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

Four directories, one per concern: `test/adapter/` (contract), `test/theme/` (§8.1 mapping and §8.3 re-skin), `test/widgets/` (§9 control rules through the real adapter path), `test/integration/` (§11 switching). Everything in them runs headless; the items that need hardware are listed at the end and stay open.

### Unit tests

`test/adapter/material_ui_contract_test.dart` covers the highest-risk surface. It asserts:

- `adapter.id == materialUiAdapterId == 'materialUi'`.
- `adapter.displayName == 'Material UI'` and `adapter.language == LiveDesignLanguage.materialUi`.
- All eight declared controls report `capabilities.supports(...) == true`.
- `select` and `tabBar` report `capabilities.supports(...) == false`.
- A registered `LiveDesignLanguage.materialUi` resolves to `LiveImplementationKind.adapterNative`.
- A declared control resolves native with **no** diagnostic.
- An undeclared control resolves `shared` with `LiveUiDiagnosticCode.controlUnsupported`, and the diagnostic names the right control.

`test/theme/material_ui_theme_test.dart` adds the mapping half of §8.1: brightness, `scaffoldBackgroundColor`/`cardColor` following the token, a changed accent producing a different generated `mu.ColorScheme`, and a dark token yielding different surfaces than the light one.

The registry and resolver under test are constructed as `LanguageRegistry(adapters: {LiveDesignLanguage.materialUi: adapter}, fallback: SharedLanguageAdapter())` with `LiveUiResolver(registry: registry)` — the same types production uses, so these are contract tests rather than mock tests.

### Widget tests

`test/widgets/material_ui_native_controls_test.dart` drives every control through a `LiveConfigProvider` with this adapter registered, so it exercises the real dispatch rather than the builders in isolation. Covered:

- Callback, disabled and loading states, and interactive-state parity through the seam — a spec the seam calls non-interactive yields `onPressed == null` in the fork widget too.
- Variant mapping: each `ButtonVariant` selects the expected `mu` class, and `danger` carries the token error fill through `styleFrom` rather than the seed-derived scheme.
- `focusNode`, `autofocus`, `expand` and `tooltip` preserved on the button; `focusNode` preserved on the slider.
- Text field controller identity across rebuilds, `onChanged`, and an inline `Style` overriding the token body text.
- Switch, checkbox, segmented and progress value and callback semantics, including a null callback disabling the control as hard as `enabled: false`.
- Card tap, long-press, `selected` fill, `bordered` side, `dense` padding, an explicit `padding`, and focus reaching only an interactive card.
- Progress `value == null` staying indeterminate, `barColor` overriding the primary tint, `height` mapping to the indicator thickness, and `showLabel` degrading to no label — the omission §9 documents.
- The disabled slider taking the documented shared-renderer fallback instead of throwing (§9/§15).
- Correct `mu.Theme` scope, and the two mixed-tree defects unique to this package: with Material UI active no SDK `FilledButton`/`Card`/`TextField`/`Switch`/`Checkbox`/`Slider`/`SegmentedButton`/`LinearProgressIndicator`/`Tooltip` is in the tree, and the fallback controls still render.
- Right-to-left layout with translated labels at a narrow width.

### Integration tests

`test/integration/material_ui_style_switching_test.dart` runs Material UI against the core shared fallback:

1. All ten `LiveUiControl` values resolve through the production `LiveUiResolver`: eight `adapterNative` with no diagnostic, `select` and `tabBar` `shared` with `controlUnsupported` — the only noise (§16.3, §16.8).
2. Brightness and accent changes re-skin `mu.ThemeData` in place, without a restart (§16.4).
3. Material UI → core `material` → Material UI replaces the theme scope each way: the fork widgets and `mu.Theme` are present, absent, then present again (§11's hardest pair, §16.5).
4. A caller-owned `TextEditingController` keeps its text and its identity across both switches (§16.6).
5. `select` and `tabBar` stay callable and typed on both sides of the switch (§16.7).

Registering a *second* third-party adapter in the same test is deliberately not done: §3.3 forbids a dependency on another style package, so cross-adapter switching is an application-level integration concern, exercised from the app's own test suite.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum include Android, an iOS or macOS target, Windows desktop, and Android TV in the planned validation matrix — Material UI has no platform exclusions, so all six claimed platforms need evidence rather than inference. Focus traversal under `mu.ThemeData`, Android TV D-pad behaviour, and contrast on the generated tonal surfaces are the three items no headless test can settle (§12, §14).

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal gate in `.github/workflows/architecture.yml`. The script holds an adapter → widget-library map; adding an adapter adds one entry and every rule below then covers it automatically.

- `live_uikit_material_ui` depends on `live_uikit` and `material_ui`.
- `live_uikit_material_ui` does not depend on any other style adapter.
- The core package does not depend on `material_ui`.
- No package other than this adapter — business packages, feature packages, `apps/` — imports `package:material_ui/material_ui.dart` or declares it as a dependency. Enforced on the declared edge as well as the imported one, so a pubspec that names another adapter's library fails even before anything imports it.
- Every `material_ui` import inside this package uses the `mu` alias, in `lib/` and in `test/`. An unqualified import would resolve to the SDK's Material widgets and quietly defeat the adapter. The alias must not leak through the public barrel.
- The public barrel exports only `src/adapter/material_ui_registration.dart` — any other directive in it is a finding.
- `materialUiCapabilities` matches the set of control methods `MaterialUiLanguageAdapter` actually overrides. `wrap` and names starting with `_` are ignored; a control declared without an override, or overridden without being declared, fails the build. This is what catches the drift where a builder is added but its control is never declared.
- The README's list of native controls is checked against `materialUiCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

The gate is textual, so it cannot see an SDK Material type reached through a transitive re-export inside a builder body; that is what the SDK-widget-absent assertion in §16 covers at runtime instead.

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
- `MaterialUiThemeScope` installing `mu.Theme` plus the transparent `mu.Material` ink surface, `MaterialUiThemeBuilder` mapping brightness, accent seed, and the token's page/card surfaces.
- The global font family is mapped into `mu.ThemeData.fontFamily`; density and per-role typography stay builder-level (`ControlSize`, `LanguageCardSpec.dense`, `LiveTheme.text`), because the fork builds its own text scale. Remaining mapping work is limited to what the fork can express. Fixed-typed fork fields (visual density, typography roles) stay library defaults and are recorded as non-token-mappable in §8.1 rather than half-mapped.

### Phase 3 — Core controls ✅

Implemented across the eight `lib/src/widgets/` builders: button, card, text field, switch, checkbox, slider, segmented, progress. Each builder preserves the spec fields its library can express, reuses the shared seam for press/label logic, and is covered by the §16 widget tests. The one documented degradation is `LanguageProgressSpec.showLabel`, which the fork's indicator cannot render.

### Phase 4 — Interaction and accessibility ◐

- Headless coverage landed: keyboard-focusable controls keep their `focusNode`/`autofocus` through the fork widgets, disabled controls are wired dead rather than decorative, semantics annotations assert, and RTL with translated labels is tested at a narrow width.
- Open, needs hardware: focus traversal and the visible focus ring under a real `mu.ThemeData`, Android TV D-pad, and contrast measured on the generated tonal surfaces.
- Add `lib/src/interaction/` only if that testing finds a Material UI-specific gap; it does not exist today.

### Phase 5 — Production readiness ◐

- §17 architectural CI checks are implemented in `tool/check_architecture.ps1`, including the capability/override drift assertion and the `mu`-alias rule.
- §11 runtime switching is covered in both directions against the core shared fallback, with caller-owned state preserved.
- Open: platform-by-platform evidence for the six claimed targets (§13), and the known limitations below promoted into a `docs/decisions/` entry if any of them is ever lifted.

### Known limitations

- `select` and `tabBar` are shared-fallback controls (§7).
- A disabled `mu.Slider` cannot build in `material_ui` 1.6.0, so that one spec shape falls back to the token renderer (§9/§15). Re-check when the fork is upgraded; the assertion that would catch the fix is already in `test/widgets/`.
- `LanguageProgressSpec.showLabel` has no fork equivalent and is dropped rather than hand-drawn (§9).
- Cross-adapter switching (Material UI against Fluent, Cupertino UI, …) is not testable from this package because §3.3 forbids depending on another adapter; it belongs to the application's integration suite.

A later phase may add native `select` and `tabBar` rendering if the fork exposes widgets that can absorb `LanguageSelectSpec<T>` and `LanguageTabsSpec` without the adapter owning caller state. Any such control must be added to `materialUiCapabilities` and the contract test in the same change.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `material_ui` only for its core integration.
- [x] It extends `SharedLanguageAdapter` and implements the real core `LanguageAdapter` contract without a competing interface.
- [x] It uses the stable adapter id `materialUi`, with `displayName` `Material UI` and `language` `LiveDesignLanguage.materialUi`.
- [x] `materialUiAdapterId`, `materialUiAdapter`, `createMaterialUiAdapter()` and `materialUiLocalizationsDelegates` are exported, and the barrel exports nothing else.
- [x] It reports accurate control capabilities: the eight overrides native, `select` and `tabBar` as shared fallbacks.
- [x] The declared capability set matches the overridden methods, asserted in CI.
- [x] It maps the resolved `DesignToken` into `mu.ThemeData` rather than bypassing the fork's theme.
- [x] It uses native `material_ui` controls where supported and never the SDK Material widgets in their place.
- [x] Every `material_ui` import is `mu`-aliased and the alias does not leak into the public API.
- [x] It installs a `mu.Theme` scope rather than a nested application shell.
- [x] It does not duplicate the core theme configuration or own business state or persistence.
- [x] Builders reuse `interactive()` and `buttonLabel()` through the shared seam instead of reimplementing them.
- [x] Runtime switching preserves business state, including Material UI ↔ core `material` both directions.
- [x] `select` and `tabBar` remain functional and on-theme through the shared renderer, with typed selection preserved.
- [x] `materialUiLocalizationsDelegates` is documented as appended to the core delegates, and core strings still resolve with Material UI active.
- [x] Unsupported features follow the core fallback policy and report `controlUnsupported`.
- [x] Diagnostics use the shared core contract and no logging dependency.
- [x] Tests and static analysis pass.
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the headless half is; focus traversal, the visible focus ring, Android TV D-pad and contrast on generated tonal surfaces need hardware (§12/§14/§16).
- [ ] Platform support claims are backed by actual tests (§13/§16).

## 20. Final architecture decision

`live_uikit_material_ui` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection, and fallback policy.
- `live_uikit_material_ui` maps those contracts to Material UI: `MaterialUiLanguageAdapter` overriding eight controls plus `wrap`, with `materialUiCapabilities` declaring exactly that set.
- `material_ui` supplies the underlying forked Material widgets and theme facilities.
- The PureLive application composition root registers the adapter, appends `materialUiLocalizationsDelegates`, and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This package is the widest-coverage adapter, and its risk is the mirror image of that completeness. Its value is a genuinely distinct Material rendering path; its failure mode is collapsing into the core `material` token base and becoming indistinguishable from it. The seed-based `mu.ThemeData` path, the mandatory `mu` import alias, the capability/override drift assertion, and the mixed-tree tests all exist to keep that line sharp.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls.
