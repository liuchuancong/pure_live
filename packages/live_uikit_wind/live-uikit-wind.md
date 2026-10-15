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

**Scope today.** Wind renders **button, card, text field, switch, checkbox, and select** natively — six of the ten contract controls. Every other control still resolves correctly, but through the core shared token renderer rather than a `fluttersdk_wind` widget. See §7 and §18.

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
6. **Honest capabilities.** `windUiCapabilities` declares exactly the six controls `WindLanguageAdapter` overrides. The remaining four are *reported* as shared fallbacks by the resolver, not silently degraded.
7. **Platform-aware behavior.** Wind appearance can be selected on any supported platform, but native Windows system integrations must not be assumed on every platform.
8. **Graceful fallback.** Unsupported controls follow the fallback policy defined by `live_uikit` and surface a `controlUnsupported` diagnostic; they never change behavior in silence.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Wind theme mapping (`DesignToken` → `WindThemeData`, installed through a Wind theme scope).
- Wind widget construction for the six controls it maps natively: button, card, text field, switch, checkbox, select.
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
    │           ├── wind_card_builder.dart
    │           ├── wind_text_field_builder.dart
    │           ├── wind_switch_builder.dart
    │           ├── wind_checkbox_builder.dart
    │           └── wind_select_builder.dart
    ├── test/
    │   ├── adapter/
    │   │   └── wind_ui_contract_test.dart
    │   ├── theme/
    │   │   └── wind_theme_test.dart
    │   ├── widgets/
    │   │   └── wind_native_controls_test.dart
    │   └── integration/
    │       └── wind_style_switching_test.dart
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
  Widget card(BuildContext context, LanguageCardSpec spec) => WindCardBuilder.build(context, spec);
  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => WindTextFieldBuilder.build(context, spec);
  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => WindSwitchBuilder.build(context, spec);
  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => WindCheckboxBuilder.build(context, spec, this);
  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => WindSelectBuilder.build<T>(context, spec);
}
```

`slider`, `segmented`, `progress`, and `tabBar` are **not** overridden — they inherit the shared token renderer.

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
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
});
```

The full capability surface, mapped to the ten `LiveUiControl` values the resolver dispatches:

| Control (`LiveUiControl`) | Implementation | Kind (`LiveImplementationKind`) |
|---|---|---|
| `button` | Native `fluttersdk_wind` button | `adapterNative` |
| `card` | Native `wind.WCard` structure with the token surface | `adapterNative` |
| `textField` | Native `fluttersdk_wind` input | `adapterNative` |
| `switchWidget` | Native `fluttersdk_wind` switch | `adapterNative` |
| `checkbox` | Native `fluttersdk_wind` checkbox | `adapterNative` |
| `slider` | Core shared token renderer | `shared` |
| `segmented` | Core shared token renderer | `shared` |
| `progress` | Core shared token renderer | `shared` |
| `select` | Native `wind.WSelect<T>` | `adapterNative` |
| `tabBar` | Core shared token renderer | `shared` |

Six Native, four Shared fallback. A declared control resolves to `adapterNative` with **no** diagnostic; an undeclared control resolves to `shared` and the resolver emits a `controlUnsupported` diagnostic (§15). The `wind_ui_contract_test.dart` asserts that the capability set lists exactly the overrides and that the fallback controls report `controlUnsupported`, so drift between declaration and implementation is caught before it ships (§17).

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

`WindThemeBuilder.build` maps three token properties into `WindThemeData`; the rest of Wind's Tailwind-shaped colour, space and typography maps stay at library defaults rather than being half-filled from tokens the library cannot name:

| Core theme source (`DesignToken`) | Wind mapping | Status |
|---|---|---|
| `isDark` | `WindThemeData.brightness`, with `syncWithSystem: false` so Wind never second-guesses the core's brightness decision (§8.3) | Mapped now |
| `color.primary` (accent) | `colors: {'primary': MaterialColor(accent, …)}` — the single token accent expanded into a flat swatch, because Wind's scale is typed `MaterialColor` | Mapped now |
| `type.fontFamily` | `fontFamilies: {'sans': family}` when a global family is configured; null leaves Wind's default | Mapped now |
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
- Reuses the shared seam for the label and loading spinner via `buttonLabel(spec, theme)`, so loading, icon, and ellipsis behavior match every other adapter. The fork's own `isLoading` spinner is deliberately not enabled: the seam already substitutes one, and two spinners in one button is a defect.
- `disabled` is set from that same `interactive(spec)` verdict, so the state the fork paints can never disagree with the callback it has.
- Padding is token-driven (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`).
- `expand` becomes the fork's own `w-full` class; `tooltip` wraps the button in a `Tooltip` and is also passed as `semanticLabel`, so an icon-only button keeps an accessible name.
- `focusNode` and `autofocus` are **not expressible on this control**: `WAnchor` creates and tracks its own focus node, and wrapping the button in a second `Focus` would take the focus that actually handles activation. They are recorded here as unmappable spec fields (§15) rather than faked. If Wind ever exposes a focus hook, wire both and delete this note.
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

### Card (`WindCardBuilder.build`)

- `wind.WCard` is the fork's card *structure* — a `w-full flex flex-col` body with header/footer slots rendered through `WDiv` — and it paints no surface of its own. The surface (fill, radius, border) therefore comes from the resolved token, which is what every other path in this package paints from (§8.1).
- Preserve `child`, `padding`, `selected`, `bordered` and `dense`; `dense` tightens the token padding by the same factor the token renderer uses, so the density step means the same thing in both paths.
- Read the `style` override only for what a Wind surface can express (`background`, `borderRadius`); a `className` is not passed, because in this fork `className` *replaces* the card's base classes rather than adding to them.
- Wire `onTap`/`onLongPress` through a gesture layer only when supplied, and stretch the body to the card's width: the fork sizes a flex body to its content, so without the stretch an interactive card is tappable only behind its own text while the surface paints full width.

### Text field (`WindTextFieldBuilder.build`)

- Build a `wind.WInput`, passing `controller`, `focusNode`, `placeholder`, `enabled`, `readOnly`, `maxLines`, `textInputAction`, `prefix`, `suffix`, `onChanged` and `onSubmitted` through untouched. When `controller` is null the field owns one; the adapter must not create a second.
- The fork expresses keyboard type and obscuring through a single `InputType`, so the spec's `obscure` and `keyboardType` collapse into one intent here — `obscure` wins, then email/number keyboards, then the line count (`multiline` above one line). `keyboardType` values the fork cannot name degrade to the fork's default rather than being faked with a formatter.
- `errorText` has no slot in the fork: mark the input with the fork's `error` state and draw the message below it in the same caption style the token renderer uses, so an error looks the same in both paths (§2.3).
- The inline `Style` is **not mapped by this builder**: `WInput` exposes no `TextStyle` slot — its visuals are driven by theme `className` presets — and hand-painting a style over the fork's field is the overlay the §8.1 rules out. Recorded here as the documented remainder, as with `selected`/`style` on the button (§9 Button).

### Switch (`WindSwitchBuilder.build`)

- Builds a `wind.WSwitch(value:, onChanged:, disabled:)` — fully controlled.
- `onChanged` is passed only when `spec.enabled`, and the `disabled` flag follows the resolved callback, so a null `onChanged` disables the switch exactly as `enabled: false` does instead of leaving a live-looking control that does nothing.
- No local persistent state; the value lives with the caller.

### Checkbox (`WindCheckboxBuilder.build`)

- Builds a `wind.WCheckbox(value:, onChanged:, disabled:)` and wraps it through `SharedLanguageAdapter.labelled(context, spec.label, control)` so the optional trailing label renders consistently.
- Preserves the checked/unchecked value, the disabled flag, and the callback semantics: the label is rendered beside the box but is not itself a hit target.

### Select (`WindSelectBuilder.build`)

- Builds a `wind.WSelect<T>` from the typed spec: each `spec.items` entry becomes one `wind.SelectOption<T>` whose label is `spec.itemLabel(item)`, and `WSelect` hands the chosen value back unchanged, so the caller's own item type survives the swap — the same property `live-uikit-fluent.md` §7 records for Fluent's `ComboBox<T>`. Wind is the second adapter in the family to render `select` natively.
- A null `onChanged` or `enabled: false` sets the fork's `disabled` flag and passes no `onChange`, so the trigger greys out and the menu never opens, rather than staying openable but reporting nothing.
- `placeholder` maps to the fork's own trigger text; the spec has no search, pagination, tagging, or multi-select fields, so none of those is enabled.
- The trigger and menu keep the fork's `className` styling: `WSelect` has no slot for the resolved `Style` or a token border on the overlay it mounts, and painting one over the fork's surface is the overlay §8.1 rules out (recorded as a documented remainder, like `selected`/`style` on the button above).

### Slider, segmented, progress, tab bar

These are **not** native. They resolve through the inherited `SharedLanguageAdapter` methods (`TokenSlider`, `TokenSegmented`, `TokenProgress`, `TokenTabs`) and report `controlUnsupported` (§15). They stay on-theme because they read the same `DesignToken` the Wind scope installs — the Wind look is carried by the token, even before a `fluttersdk_wind` widget stands behind each control. The library offers no slider, no progress bar, and no bare tab strip (`WTabs` couples the tab row to a content panel `LanguageTabsSpec` does not carry), so their promotion stays gated on the fork actually offering a control for the job (§18).

## 10. Runtime registration

The application composition root registers the adapter during startup. Wind exposes a const instance and a factory so the root can pick either:

```dart
// Using the exported API.
// `LanguageRegistry` is immutable: the adapters are supplied as a map at construction.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.wind: windUiAdapter},   // or createWindUiAdapter()
  fallback: SharedLanguageAdapter(),
);
```

The core `LanguageRegistry` maps `LiveDesignLanguage → LanguageAdapter` with a shared fallback, so an unregistered language still renders coherently:

```dart
const LanguageRegistry(adapters: {LiveDesignLanguage.wind: windUiAdapter}, fallback: SharedLanguageAdapter());
```

The composition root, not the adapter, is responsible for: registering the adapters included in the build, loading the user's style preference, selecting the active language, providing configuration persistence, and coordinating runtime theme changes. `live_uikit_wind` must not register itself through global static initializers or require the business layer to import it.

### Resolution behavior

The core `LiveUiResolver` is the single decision point. For Wind:

- A registered language resolves to `adapterNative` (`WindLanguageAdapter`).
- A declared control (button, card, text field, switch, checkbox) resolves native with no diagnostic.
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

Switching from Wind to another style changes rendering and interaction presentation only. It must not replace business controllers, reset form values, or recreate unrelated services. Because Wind overrides six of the ten controls, switching *into* Wind keeps slider, segmented, progress and tabs rendering via the shared token renderer — the visible style shift is concentrated in buttons, cards, text fields, switches, checkboxes, and the select trigger. The caller-owned `TextEditingController` and the caller-owned select value are the state that must survive the shift untouched (§9).

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile, so the Wind adapter must be tested for more than mouse input.

Wind is Windows-flavoured, which makes keyboard-driven desktop the natural first-class context: Tab/shift-Tab traversal, visible focus indication, and Enter/Space activation should be verified against the native `WButton`/`WSwitch`/`WCheckbox`. Because `WindLanguageAdapter` inherits the shared token renderer for slider, segmented, progress and tabs, those inherit the core's focus behavior — the `Language*Spec` objects carry `focusNode` and `autofocus` (button, card, switch, checkbox, slider, text field all do), and the adapter forwards them on every control it maps natively where the fork accepts them. `WSelect` creates and tracks its own focus node internally and the select spec carries no `focusNode` field, so keyboard activation stays entirely the fork's (§9).

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
| `controlUnsupported` | A request for any of slider, segmented, progress, tabBar — expected, not silent degrade |
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
- The capability set lists exactly the six controls the adapter overrides — `{button,
  card, textField, switchWidget, checkbox, select}` — and the other four are `false`; the same
  comparison is enforced by `tool/check_architecture.ps1` (§17), so the declaration and
  the overrides cannot drift apart silently.
- Through `LiveUiResolver` over a `LanguageRegistry`: a registered Wind resolves `adapterNative`; a declared control resolves native with no diagnostic; an undeclared control resolves `shared` and reports `controlUnsupported`.
- Theme mapping (`test/theme/wind_theme_test.dart`): `isDark` → `WindThemeData.brightness`
  with `syncWithSystem` forced off, the token accent landing in Wind's `primary` swatch,
  and a configured global family reaching `fontFamilies['sans']`.

### Widget tests (`test/widgets/wind_native_controls_test.dart`)

- Button: `onPressed` fires when enabled, input is rejected while loading, the seam's
  `interactive()` verdict is also the visual state, `expand` and `tooltip` are preserved,
  and `focusNode`/`autofocus` are asserted *not* to reach `WAnchor` (it owns its node) —
  the §9 gap is pinned rather than left to memory.
- Card: `onTap`/`onLongPress` only on an interactive card, `dense` tightening the padding,
  a plain surface getting no gesture layer, `selected` tinting, explicit `padding` winning.
- Text field: the caller's controller passing through and reporting changes, `obscure` and
  the line count collapsing into the fork's single `InputType`, `errorText` marking the
  fork error state, `enabled: false` reaching the fork.
- Switch and checkbox: rendering through the adapter and reporting the next value.
- Select: the typed items, `value` and `placeholder` reaching `WSelect<T>` as `SelectOption`s,
  and a null callback or `enabled: false` setting the fork's `disabled` flag with no `onChange`,
  so a dead select cannot open.
- A control the adapter does not override still renders through the shared fallback.

Not yet covered: keyboard and remote activation, accessibility semantics, and layout under
narrow versus wide constraints — the §19 line that still asks for hardware.

### Integration tests (`test/integration/wind_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: six `adapterNative` (button, card, text field, switch, checkbox, select), four `shared` with `controlUnsupported`.
- A mixed subtree renders `wind.WInput`/`WCard`/`WSwitch`/`WSelect` natively beside the token slider and progress; Wind → core `material` → Wind replaces the path with the caller's `TextEditingController` text and select value intact.
- `adapterMissing` is reported only for the core base; while Wind is active the sink sees exactly the four undeclared controls' `controlUnsupported` entries (§15.5).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring a platform supported, test on the corresponding runtime. At minimum, include Windows desktop, a mobile target, and Android TV in the validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_wind` depends on `live_uikit` and `fluttersdk_wind` only for its core integration.
- `live_uikit_wind` does not depend on any other style adapter, including `live_uikit_fluent`.
- The core package does not depend on `fluttersdk_wind`.
- Business packages do not import `package:fluttersdk_wind/fluttersdk_wind.dart`.
- Only the registration API is exported from the barrel; builders, mappers, and `fluttersdk_wind` types stay internal.
- The declared `windUiCapabilities` set matches the methods `WindLanguageAdapter` actually overrides (the contract test enforces this).
- Every `package:fluttersdk_wind/` import inside this package uses the `as wind` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `windUiCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands (run from the workspace root with the repository's normal Flutter SDK and workspace resolution):

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_wind
flutter analyze packages/live_uikit_wind
flutter test packages/live_uikit_wind
```

## 18. Implementation phases

Wind ships with six native controls and a token-driven theme bridge. The phases below first hardened that foundation, then widened the native surface so the shared-fallback count drops control by control.

### Phase 1 — Contracts and registration ✅

- `WindLanguageAdapter` implements the finalized core contract by extending `SharedLanguageAdapter`.
- Stable id `wind`, display name `Wind`, `LiveDesignLanguage.wind` language.
- `windUiAdapter`, `createWindUiAdapter()`, `windUiAdapterId` registration API; barrel exports only the registration.
- `wind_ui_contract_test.dart` covers id/capabilities/resolver behavior.

### Phase 2 — Theme integration foundation ✅

- Brightness, the accent as Wind's `primary` swatch, and a configured global font are mapped in `WindThemeBuilder`; `syncWithSystem` is forced off because the core owns the brightness decision (§8.3).
- `test/theme/wind_theme_test.dart` asserts the mapping and drives a runtime re-skin through `LiveConfigProvider` → resolver → `wrap`.
- Wind's Tailwind colour/space/typography maps stay at their defaults — keys the token cannot name are left alone rather than half-mapped (§8.1).

### Phase 3 — Harden the current native controls ✅

- Button: padding from the token, `expand` through `w-full`, `tooltip` through a `Tooltip` wrapper and `semanticLabel`, `disabled` from the seam's `interactive()` verdict. `focusNode`/`autofocus` are recorded in §9 as fields `WAnchor` cannot accept — that is the one item this phase could not close.
- Switch and checkbox are fully controlled, and a null callback now drives the fork's `disabled` flag as well as the callback.
- `test/widgets/wind_native_controls_test.dart` covers all three plus the shared fallback.

### Phase 4 — First high-value native surfaces ✅

- `WindCardBuilder` and `WindTextFieldBuilder` added, overriding `card` and `textField`.
- Both are declared in `windUiCapabilities`, and `wind_ui_contract_test.dart` moved them from the `fallback` set to the `native` set in the same change (§17 drift gate).
- The card takes its surface from the token because `WCard` paints none; the field collapses `obscure`/`keyboardType`/`maxLines` into the fork's single `InputType` and draws `errorText` the way the token renderer does (§9).

### Phase 5 — Remaining controls ◐

- `WindSelectBuilder` added, overriding `select` with `wind.WSelect<T>` (§9): the typed items map to `SelectOption`s, a null/disabled spec disables the fork, and the contract test's `native`/`fallback` sets moved `select` in the same change (§17 drift gate). Wind is now six-of-ten native.
- Slider, segmented, progress and tab bar stay shared: `fluttersdk_wind` offers no `WSlider`, `WProgress`, or bare tab strip (`WTabs` couples the row to a content panel `LanguageTabsSpec` does not carry), so a native builder is gated on the library first providing a control for the job rather than hand-wrapping an ill-fitting one (§9).
- Each future promotion updates `windUiCapabilities` and the contract test's `native`/`fallback` sets in lockstep.

### Phase 6 — Interaction, icons, and accessibility

- Introduce `interaction/` for keyboard/focus/TV mapping on the now-larger native surface. This is where the §9 focus gap has to be answered: either by the library exposing a focus hook or by a documented, tested traversal policy.
- Introduce `icons/` for semantic icon mapping where Wind supports it.
- Validate focus traversal, D-pad behavior, and accessibility semantics on all native controls.

### Phase 7 — Production readiness ◐

- Integration tests for runtime style switching (Wind in and out) landed in `test/integration/wind_style_switching_test.dart`. The switching contract is asserted per package against the core shared fallback (§16); an app-level test that swaps Wind with another adapter belongs to the application, since §3.3 forbids adapter-to-adapter dependencies.
- Architectural CI checks (§17) — done: `tool/check_architecture.ps1` enforces the library boundary, the `wind` import prefix, the registration-only barrel, and the capability/override match.
- Verify all claimed platforms with real tests.
- Document known limitations and `fluttersdk_wind` upgrade compatibility: today they are the button's unfocusable spec fields (§9) and the fork `InputType` collapse (§9).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `fluttersdk_wind` only for its core integration.
- [x] It extends `SharedLanguageAdapter` and implements the actual `LanguageAdapter` contract.
- [x] It uses the stable adapter id `wind` (with `windUiAdapterId`, `windUiAdapter`, `createWindUiAdapter()`).
- [x] `windUiCapabilities` declares exactly the six controls the adapter overrides (`button`, `card`, `textField`, `switchWidget`, `checkbox`, `select`) as native.
- [x] The other four controls resolve through the shared token renderer and report `controlUnsupported`.
- [x] The barrel exports only the registration API; no builders, mappers, or `fluttersdk_wind` types leak (§17 guards this in CI).
- [x] It maps the resolved `DesignToken` into `WindThemeData` and installs a Wind theme scope — brightness with `syncWithSystem` off, the accent as Wind's `primary` swatch, and a configured global family in `fontFamilies['sans']` (§8.1).
- [x] It adds no localization delegates and relies on core localization.
- [x] It does not depend on `live_uikit_fluent` or any other style adapter.
- [x] It does not own business state, persistence, or a nested app shell.
- [x] Native controls preserve value/callback/controller semantics and pass fully controlled state through — `focusNode`/`autofocus` excepted on the button and card, where `WAnchor` owns the node; §9 records that as unexpressible and a test asserts it rather than leaving it to memory.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested for the native controls — nothing in the suite drives a key event or a semantics node yet (§16), and D-pad behavior needs hardware.
- [x] Diagnostics use the shared core contract (`LiveUiDiagnostic`, `LiveUiDiagnosticSink`): the package defines no channel of its own, and its downgrades arrive as the resolver's `controlUnsupported`.
- [x] The contract test keeps `windUiCapabilities` in sync with the overrides (§17).
- [x] Tests and static analysis pass (`flutter test`, `flutter analyze`: no issues).
- [ ] Platform support claims are backed by real tests — Windows desktop, a mobile target and Android TV still need their runtimes (§16 Platform verification).

## 20. Final architecture decision

`live_uikit_wind` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, the `DesignToken` theme model, runtime selection (`LiveUiResolver` + `LanguageRegistry`), the capability model, and the fallback/diagnostic policy.
- `live_uikit_wind` maps those contracts to `fluttersdk_wind`, today for six native controls.
- `fluttersdk_wind` supplies the underlying Wind widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

Wind's deliberately small native surface is a foundation, not a ceiling: everything renders correctly and stays on theme through the shared token renderer, and each control graduates to native through the phases above while `windUiCapabilities` tracks the truth. This separation lets PureLive add or replace UI styles — including growing Wind — without forcing business packages to know which library is currently rendering their controls.
