# `live_uikit_material` Architecture and Integration Specification

- **Package:** `live_uikit_material`
- **Parent package:** `live_uikit`
- **Implementation library:** `material_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_material` is the Material UI adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into real controls from the `material_ui` package — a fork of Flutter's Material widgets — and applies that fork's own styling on top of the core design tokens. It must not implement business pages or duplicate the core theme system.

This adapter occupies a specific and easily confused position in the eight-language matrix, and the distinction must stay explicit:

- `material_ui` is a **fork of Flutter's Material widgets**, not `package:flutter/material.dart`. It deliberately shadows the SDK's names (`ThemeData`, `ColorScheme`, `FilledButton`, `LinearProgressIndicator`, `GlobalMaterialLocalizations`), so this package reaches it through the `mu` prefix (§3.3) and an unqualified import would silently render the SDK's widgets instead.
- `live_uikit_material` is the **Material design language taken from that fork**: `LiveDesignLanguage.material` names the fork, `MaterialLanguageAdapter` is its adapter, and the theme, the host, the controls and the shell all come from `mu`, seeded from the core's resolved token.

So the value this package adds is not "Material, again". It re-skins Material-shaped controls with `material_ui`'s own theme types (`mu.ThemeData`, `mu.ColorScheme`) and its own widget classes, which lets PureLive ship Material look-and-feel with the fork's typography, spacing and colour-generation rules rather than the SDK's. Because that vocabulary is the closest any of the eight languages comes to the primitives Flutter itself ships, this adapter has the widest one-for-one coverage of the seventeen controls of any style package.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_material
       |
       v
   material_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `material_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **The fork owns fork visuals.** Use native `material_ui` controls wherever practical. Do not draw Material-shaped controls from scratch when the fork provides them, and do not silently substitute the Flutter SDK's Material widgets — that would make this adapter indistinguishable from a page that never left the SDK.
3. **Implement, do not inherit.** `MaterialLanguageAdapter` implements `LanguageAdapter`, an `abstract interface class` with nothing behind it. It overrides `wrap`, all seventeen control builders, and both structural surfaces; the press gating, the label layout and the inert forms a library cannot build are this package's own code, written once here (§9).
4. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
5. **No hidden state ownership.** Form values, validation, and business state remain controlled by the calling widget or application. The one controller this package does create is a `mu.TabController` for the fork's tab strip and page view, and it exists only to drive those two widgets: the spec's index stays the caller's, and the controller is disposed with the widget that owns it.
6. **Runtime switching is supported.** Switching between Material UI and any of the other seven styles must not require business pages to import or construct different control classes.
7. **Closest-relative, not clone.** Material UI's value is a distinct rendering path with the fork's defaults. Where the fork offers no equivalent for a control or a spec field, this package composes the answer from that same library's own parts and records the field it cannot express at the builder that drops it (§9) — it does not approximate the look of another language.
8. **Nothing is served elsewhere.** A control Material UI cannot build is drawn from `material_ui`'s own theme values, never from another library. What the contract asks for but this build does not provide is a fault, not a degrade: `LiveUiResolver.resolve` raises `LiveUiResolutionException` for an unregistered language, and `requireControl`/`requireSurface` raise `LiveUiCapabilityException` for a capability declared without a matching override. The one diagnostic left, `unsupportedEffect`, reports an effect the device cannot afford.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Material UI theme mapping (`DesignToken` → `mu.ThemeData`).
- The Material UI theme scope installed via `wrap`.
- Material UI widget construction for all seventeen controls of the contract, and for both structural surfaces.
- Material UI-specific control defaults, including variant-to-button-class selection, progress tinting, and the inert forms the fork cannot build for itself.
- Mapping shared control specifications to `material_ui` controls.
- Reporting implemented capabilities to the core registry through `materialCapabilities`, and the two surfaces through `materialSurfaces`.
- Exporting `materialLocalizationsDelegates` for the fork's `GlobalMaterialLocalizations` requirement.
- Adapter-level contract tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The eight-language selector UI.
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
| `live_uikit` | Yes | Shared contracts, tokens, and runtime dispatch |
| `material_ui` | Yes | Native fork controls and theme types |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_cupertino` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| `live_uikit_forui` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

Import hygiene: `material_ui` types are imported with the `mu` prefix throughout this package (`import 'package:material_ui/material_ui.dart' as mu;`). The fork deliberately shadows well-known Flutter Material names (`ThemeData`, `ColorScheme`, `FilledButton`, `LinearProgressIndicator`, `GlobalMaterialLocalizations`), so the prefix is mandatory — unqualified names would silently resolve to the SDK's Material widgets and defeat the purpose of this adapter. The alias must not leak through the public barrel.

## 4. Package directory

The tree below reflects the package as it exists today. Material UI is the most complete adapter: nineteen builders cover the seventeen controls, the app host and the shell, the four adapter files hold the contract, the capabilities, the surfaces and the registration, and three theme files hold the mapping. Every §16 concern that does not need a device — contract, theme mapping, native controls, and runtime switching — has its own test directory.

```text
packages/
└── live_uikit_material/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── live-uikit-material.md
    ├── lib/
    │   ├── live_uikit_material.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── material_adapter.dart
    │       │   ├── material_capabilities.dart
    │       │   ├── material_registration.dart
    │       │   └── material_surfaces.dart
    │       ├── theme/
    │       │   ├── material_theme_mapper.dart
    │       │   ├── material_theme_builder.dart
    │       │   └── material_theme_scope.dart
    │       └── widgets/
    │           ├── material_app_bar_builder.dart
    │           ├── material_button_builder.dart
    │           ├── material_card_builder.dart
    │           ├── material_checkbox_builder.dart
    │           ├── material_dialog_builder.dart
    │           ├── material_host_builder.dart
    │           ├── material_list_row_builder.dart
    │           ├── material_nav_bar_builder.dart
    │           ├── material_progress_builder.dart
    │           ├── material_scaffold_builder.dart
    │           ├── material_segmented_builder.dart
    │           ├── material_select_builder.dart
    │           ├── material_shell_builder.dart
    │           ├── material_slider_builder.dart
    │           ├── material_switch_builder.dart
    │           ├── material_tab_bar_builder.dart
    │           ├── material_tab_view_builder.dart
    │           ├── material_text_field_builder.dart
    │           └── material_toast_builder.dart
    └── test/
        ├── adapter/
        │   └── material_contract_test.dart
        ├── theme/
        │   └── material_theme_test.dart
        ├── widgets/
        │   ├── material_native_controls_test.dart
        │   └── stub_router.dart
        └── integration/
            └── material_style_switching_test.dart
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
| `adapter/` | Adapter contract implementation, capability and surface declaration, registration exports, and the two inert forms the fork cannot build for itself |
| `theme/` | Translate the resolved `DesignToken` into `mu.ThemeData` and install the scope |
| `widgets/` | Build the seventeen controls, the app host and the shell from core widget specifications, each with one of the fork's widgets or with its own parts |
| `test/adapter/` | Verify id, display name, language, capability and surface declaration, and resolver behavior |
| `test/widgets/` | Drive every control through `LiveConfigProvider`, plus `stub_router.dart` — a router that goes nowhere so the host can be pumped |
| `interaction/` *(optional)* | Map keyboard, focus, and TV-specific behavior |
| `icons/` *(optional)* | Map supported semantic icons to fork icons |
| `diagnostics/` *(optional)* | Report mapping-level effects the device cannot afford, beyond what the core resolver already raises |
| `example/` *(optional)* | Demonstrate integration without business dependencies |

## 5. Package dependencies

The package's `pubspec.yaml`:

```yaml
name: live_uikit_material
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
// lib/live_uikit_material.dart

/// Material UI design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6).
library;

export 'package:live_uikit_material/src/adapter/material_registration.dart';
```

`material_registration.dart` provides exactly four public symbols:

| Symbol | Kind | Purpose |
|---|---|---|
| `createMaterialAdapter()` | Function | Constructs the adapter for the composition root to register |
| `materialAdapter` | `const LanguageAdapter` | The const adapter instance, usable directly where a const is required |
| `materialAdapterId` | `const String` | The stable runtime id, `'material'` |
| `materialLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | The fork's `GlobalMaterialLocalizations.delegate` for the app to append (§14) |

Do not export `MaterialLanguageAdapter`, the builders, the theme mapper/scope, or `materialCapabilities` from the barrel. The builders and `mu`-prefixed types are implementation detail; exposing them would let business packages construct Material UI widgets directly and bypass style switching. The capability set is consumed by the core resolver through the adapter's `capabilities` getter, not by importers.

The core contract is finalized, so these names are the API — not a proposal. Sections 7 through 10 below reference the actual classes and methods in `live_uikit`.

## 7. Adapter contract

`live_uikit` defines the contract as `abstract interface class LanguageAdapter`. `MaterialLanguageAdapter` implements it directly — there is no base class in this family to extend — so every member below is written in this package, in terms of `material_ui`:

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

The concrete declaration in this package:

```dart
class MaterialLanguageAdapter implements LanguageAdapter {
  const MaterialLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.material;
  @override String get id => 'material';
  @override String get displayName => 'Material UI';
  @override LiveUiCapabilities get capabilities => materialCapabilities;
  @override LiveUiSurfaceCapabilities get surfaces => materialSurfaces;
  @override Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);
  // plus all seventeen control overrides, appHost and shell, each handing its
  // spec to a builder under lib/src/widgets/
}
```

Every control, the app host and the shell reach one of the nineteen builders under `lib/src/widgets/`, and `wrap` goes to the theme mapper. Three of those shapes are completed inside the adapter file itself, because they are the forms the fork refuses to build: `slider` and `navBar` call their builders only when the live widget can be built at all and otherwise draw the inert form here, and `select` first rewrites its spec into the only item list the fork's assert can carry — see §9 Slider, §9 NavBar and §9 Select.

### Adapter identifier

The stable identifier is:

```text
material
```

It is machine-readable and used by the registry, persistence, and diagnostics. `id` deliberately matches `LiveDesignLanguage.material.name`; do not use `material_ui` (the package) or `Material UI` (the human label) for it. `Material UI` stays the `displayName` shown in the style selector.

`materialAdapterId` exists so the composition root and tests reference the id without duplicating the literal.

### Capability and surface declaration

`materialCapabilities` declares every control the adapter overrides — all seventeen members of `LiveUiControl`:

```dart
const LiveUiCapabilities materialCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
  LiveUiControl.tabView,
  LiveUiControl.dialog,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
});

const LiveUiSurfaceCapabilities materialSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
```

A capability is a **declaration of fact** — which methods the adapter actually overrides — and the declaration is checked rather than trusted: `LiveUiResolver.requireControl` and `requireSurface` raise `LiveUiCapabilityException` for anything declared without a matching override, while `LiveUiResolver.resolve` raises `LiveUiResolutionException` for a language this build registered no adapter for. The control surface is the seventeen `LiveUiControl` values — `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`, `select`, `tabBar`, `scaffold`, `appBar`, `listRow`, `navBar`, `toast`, `dialog`, `tabView` — and `LiveUiControl` has no `text` or `icon` member, so those must not appear in a capability set. The structural surfaces are the two `LiveUiSurface` members, `appHost` and `appShell`, declared apart from the controls because owning one says nothing about the other.

### The realized mapping

| Control (`LiveUiControl`) | Adapter method | Rendering in this package | Mapped or composed |
|---|---|---|---|
| `button` | `button` | `mu.FilledButton` / `mu.ElevatedButton` / `mu.TextButton` by variant | Mapped; the label-and-icon row, the loading spinner and the `expand`/`tooltip` wraps are composed here |
| `card` | `card` | `mu.Card` over a `mu.InkWell` | Mapped |
| `textField` | `textField` | `mu.TextField` with a `mu.InputDecoration` | Mapped |
| `switchWidget` | `switchWidget` | `mu.Switch` | Mapped |
| `checkbox` | `checkbox` | `mu.Checkbox` | Mapped; the trailing label is composed, because the fork's box paints none |
| `slider` | `slider` | `mu.Slider` | Mapped — and composed into this package's inert rail when the spec must not move |
| `segmented` | `segmented` | `mu.SegmentedButton<int>` over `mu.ButtonSegment`s | Mapped |
| `progress` | `progress` | `mu.LinearProgressIndicator` | Mapped |
| `select` | `select` | `mu.DropdownButton<T>` | Mapped, on a spec the adapter has first made choosable |
| `tabBar` | `tabBar` | `mu.TabBar` behind a `mu.TabController` this package owns | Mapped |
| `scaffold` | `scaffold` | `mu.Scaffold` | Mapped |
| `appBar` | `appBar` | `mu.AppBar`, returned as a `PreferredSizeWidget` | Mapped |
| `listRow` | `listRow` | `mu.ListTile` | Mapped; `divided` adds the fork's own `mu.Divider` under the tile |
| `navBar` | `navBar` | `mu.NavigationBar` | Mapped — and composed into this package's inert strip when the fork's assert cannot hold |
| `toast` | `toast` | `mu.Material` card themed by the fork's `SnackBarThemeData` | Composed — the only control with no fork widget to take |
| `dialog` | `dialog` | `mu.AlertDialog` handed back as a plain widget | Mapped surface; the core keeps the route |
| `tabView` | `tabView` | `mu.TabBarView` behind a second owned `mu.TabController` | Mapped |
| `LiveUiSurface.appHost` | `appHost` | `mu.MaterialApp.router` | Mapped |
| `LiveUiSurface.appShell` | `shell` | `mu.NavigationRail` inside a `Row`; `mu.NavigationBar` under the page for a bottom request | Mapped, with the row composed here because the rail is only the strip |

`select` and `tabBar` are the two that need more than a widget name to explain, and what they need this package supplies itself. `mu.DropdownButton` asserts that its current value matches exactly one item, so the adapter filters the item list to the values it can actually carry and drops an off-list value to `null` — the library's own *nothing chosen* state, whose slot is `hint`, where `LanguageSelectSpec.placeholder` already rides. `mu.TabBar` and `mu.TabBarView` are driven by a `TabController` rather than by an index, so each widget is wrapped in a stateful holder that owns one controller, rebuilds it when the item count or the view's animation duration changes, and asserts the spec's index onto it on every update. The index itself stays the caller's: a tap or a swipe reports it, and the next rebuild either agrees or pulls the widget back, which is also how a refused swipe is undone. Neither control makes this package own a value the contract assigns to the caller.

Keep `materialCapabilities` and `materialSurfaces` in step with the methods the adapter overrides. §16 asserts both sets against the contract and §17 makes the comparison a build gate, so a control added to the declaration without its override — or overridden without being declared — fails there rather than at runtime.

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
MaterialLanguageAdapter.wrap
     |
     v
MaterialThemeMapper
     |
     v
MaterialThemeScope
     |
     v
MaterialThemeBuilder.build  ->  mu.ThemeData
     |
     v
mu.Theme(child)  ->  native material_ui controls
```

The three theme files have distinct roles and must not be collapsed:

| File | Type | Role |
|---|---|---|
| `material_theme_mapper.dart` | `MaterialThemeMapper` | The adapter's `wrap` entry point; delegates to the scope |
| `material_theme_scope.dart` | `MaterialThemeScope` (widget) | Installs `mu.Theme` around `child` |
| `material_theme_builder.dart` | `MaterialThemeBuilder` | Pure mapping: `DesignToken` → `mu.ThemeData` |

### 8.1 Theme properties to map

`MaterialThemeBuilder.build` sets five values and no more, each of them taken from the resolved token; everything else stays at the fork's own defaults:

| Core theme property | Material UI mapping | Notes |
|---|---|---|
| Brightness | `mu.ThemeData.brightness` from `token.isDark` | Light or dark; drives control defaults |
| Accent / primary color | `mu.ColorScheme.fromSeed(seedColor: token.color.primary, brightness:)` | Seed-based generation, matching Material 3 semantics |
| Text styles | `mu.ThemeData.fontFamily` from `token.type.fontFamily`; role sizes stay at the fork's typography | Mapped for the family only — the roles come from `LiveTheme.of(context).text` in the builders, which is where the `Language*Spec` intent is applied (§9) |
| Density / sizing | `ControlSize` on `LanguageButtonSpec`, plus `LanguageCardSpec.dense` | Per-control; do not assume a global density knob |
| Focus appearance | Fork default, plus `focusNode` / `autofocus` from the specs | Verify against the resolved fork version |
| Surface / background | `mu.ColorScheme` surfaces, with `theme.colors` overrides where the token is authoritative | Map only surfaces the fork actually exposes |
| Transparency / blur | Not applicable to Material UI | No effect to degrade; do not fabricate one |
| Motion | Fork transitions | Do not imply global animation configuration |

Seed-based colour generation is the correct choice here, because the fork derives an entire tonal palette from a single seed. That means the token's `primary` colour is an input to an algorithm rather than a literal fill colour, so secondary tones shift as the seed changes. Where a builder needs the token's exact colour rather than a derived tone — the danger button's error fill, the progress bar's tint — it supplies the colour explicitly through `styleFrom` or `color:` instead of trusting the generated scheme.

Because this language renders the same visual family the Flutter SDK ships, mapping must not collapse into "read the token back through `LiveTheme` for everything". If every visual property came from `LiveTheme`, the fork's theme would be installed but never consulted, and this adapter would produce no distinguishable style. The division to preserve: **theme-level properties go through `mu.ThemeData`; control-level intent comes from the spec and `LiveTheme`.**

Avoid forcing all eight style libraries to use identical widget dimensions. The core tokens define shared design intent; this adapter translates that intent into the closest `material_ui` presentation.

### 8.2 Theme scope

`MaterialThemeScope` installs the mapped theme with `mu.Theme(data: ..., child: child)` — a theme scope, not a nested application widget.

Under the theme it installs one more thing: a transparent `mu.Material`. Fork ink widgets resolve their paint surface by *type*, and a host `MaterialApp`/`Scaffold` only supplies the SDK's `Material`, so a fork `TextField`, `Switch` or `Card` throws "No Material widget found" without it. Making the scope provide the surface is what keeps §1's rule intact — a page must not have to know which library is rendering it. A transparent `Material` is a paint surface, not a shell: it owns no navigation, no localization and no application configuration, so it does not fight the host `MaterialApp` for inherited state.

Do not nest a Material UI application shell inside an existing app solely to apply the style. A nested application widget introduces competing navigation, localization, and application-level configuration, and in this package it would additionally fight the host `MaterialApp` for the same Material-shaped inherited state.

Note the asymmetry with the Fluent adapter: `material_ui` is a Material fork, so a Material UI subtree sits *inside* an app that is very likely already a `MaterialApp`. The `mu`-prefixed theme must therefore be the nearest ancestor theme for fork widgets, and fork widgets must never be handed an SDK `Theme` or read an SDK `Material` widget. The mirror-image defect is the one this package guards hardest: a control inside a Material page that was actually drawn by the SDK, because an import lost its `mu` alias. Every control and both surfaces answer from `material_ui`, so §16 asserts the SDK classes are simply absent from the tree — mixed trees are the most likely defect class in this package.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `wrap` is invoked with the new token.
4. `MaterialThemeBuilder.build` derives a new `mu.ThemeData` and the scope rebuilds.
5. Existing business state remains owned by the business widgets and controllers.

`MaterialThemeBuilder.build` is a static pure function, so the theme must not be memoized against anything but the token. Do not cache a `mu.ThemeData` object permanently if its source token can change — the mapper holds `MaterialThemeMapper` as a `static const` field precisely because it is stateless.

## 9. Control implementation rules

Each control builder is an `abstract final class` with a static `build` that converts a core specification into a `material_ui` widget. Every builder takes the same two arguments, the `BuildContext` and the spec: there is no third parameter and nothing to call upward into. Press gating and label composition are therefore this package's own code, written once here — the button computes `onPressed` from `enabled && !loading && onPressed != null` and builds its own content row, the checkbox and the segmented control build their wrapper closure only when the caller can be called back and otherwise pass `null` to the fork, and the switch turns `enabled: false` into a null `onChanged`. The text field forwards its callbacks untouched and hands `enabled` straight to the fork's own disabled state. That is what makes the rules below this library's own rendering rather than a translation of someone else's.

### Button (`MaterialButtonBuilder`)

- Map `ButtonVariant` to the closest Material button class: `primary` → `mu.FilledButton`, `secondary` → `mu.ElevatedButton`, `ghost` → `mu.TextButton`, `danger` → `mu.FilledButton` with `styleFrom(backgroundColor: theme.colors.error, foregroundColor: theme.colors.onPrimary)`.
- Compute `onPressed` from `enabled && !loading && onPressed != null` and pass `null` when the button is not pressable, so a dead button is wired dead rather than painted dead.
- Build the content here, from this library's own parts: the label in a `Text`, a leading `Icon` at the token's label size, a `mu.CircularProgressIndicator` in the label's square dimension while `loading`, and the bare glyph of an icon-only button.
- Preserve `focusNode` and `autofocus` — the fork's buttons take both directly.
- `expand` wraps the built button in `SizedBox(width: double.infinity)` and `tooltip` wraps it in `mu.Tooltip`, because neither is a constructor argument of a Material button. The tooltip text is the caller's, never generated.
- Do not place business actions inside the adapter.
- `iconOnly` is served by that same content builder: it returns the glyph alone, with
  the tooltip (or the non-empty label) as its `semanticLabel`, so the empty label a
  caller had to pass never enters the layout. The button keeps the fork's own padding
  rather than a square step.
- `selected` is **not mapped by this adapter**. A toggled button takes the primary
  colour, and reproducing that here would need a hand-painted overlay on the fork's
  own button rather than one of its states, so `selected` renders unselected.
  Recorded as the documented remainder of `docs/decisions/0004`, and listed with this
  package's other known limitations in §18.
- `style` is **not mapped by this adapter either**. Its button is the library's own
  widget and paints its own surface; applying a caller's `Style` to it would mean
  hand-painting an overlay over that widget, the trade this section already refuses
  for `selected` (`live-uikit.md` §11).

### Card (`MaterialCardBuilder`)

- Prefer native Material UI card visuals for the intended role: a `mu.Card` with `Clip.antiAlias`, its radius from `theme.card.borderRadius` and its content over a `mu.InkWell` so taps ripple.
- Preserve `child`, `padding`, `selected`, `bordered` and `dense`. `selected` fills the surface with `theme.colors.primaryBg`, `bordered` gives the shape a `theme.colors.border` side, and `dense` tightens the token's card padding to two thirds of itself (`theme.card.padding * 0.66`) — the step this language reads as density, and an explicit `padding` overrides both.
- Read the `style` override only for what a Material card can express — `background`, `borderColor`, `borderWidth`, `borderRadius` — and leave the rest as library defaults rather than hand-painting it (§8.1 "map only supported").
- Wire `onTap` and `onLongPress` only when supplied; do not assume every card is interactive. `focusNode` and `autofocus` reach the ink well only for an interactive card, so a plain surface never takes focus.

### Text field (`MaterialTextFieldBuilder`)

- Use the native Material UI text input.
- Pass the supplied `controller` and `focusNode` through untouched. When `controller` is null, follow the core convention that the field owns one — the adapter must not create a second controller or silently own a lifecycle the caller did not delegate.
- Preserve `placeholder`, `errorText`, `enabled`, `readOnly`, `obscure`, `maxLines`, `textInputAction`, `keyboardType`, `prefix`, `suffix`, `style`, `onChanged`, and `onSubmitted`. `placeholder`, `errorText`, `prefix` and `suffix` reach the field as the fork's `InputDecoration` hint, error, prefix-icon and suffix-icon slots; an obscure field is pinned to one line. The inline `style` layers onto the token body text through `TextStyle.copyWith`, so an unset property keeps the token value.

### Switch (`MaterialSwitchBuilder`)

- Use the native Material UI switch.
- Preserve `value`, `onChanged`, `enabled`, `focusNode`, and `autofocus`.
- Do not introduce local persistent state; a null `onChanged` means disabled, not ignored.

### Checkbox (`MaterialCheckboxBuilder`)

- Use the native Material UI checkbox. The fork's box paints no label of its own, so `label` is composed here: a `Row` of the box, a token `sm` gap, and the text in this language's own body role.
- Preserve `value`, `label`, `enabled`, `focusNode`, and `autofocus`.
- The label-to-callback bridge exists only when the caller can be called back: `enabled: false` **or** a null `onChanged` passes `null` to the fork, so a dead checkbox never lights up as though it responded.
- The core contract is a non-null `bool value`, so the adapter must not advertise an indeterminate state; if the fork supports one, it stays unreachable until `LanguageCheckboxSpec` models it.

### Slider (`MaterialSliderBuilder`, and the adapter's inert form)

- For a spec that can move — `enabled` and a non-null `onChanged` — use the native Material UI slider, clamped to the spec range, with the caller's `focusNode` preserved so keyboard and D-pad traversal reach it.
- Preserve `value`, `min`, `max`, `enabled`, and `onChanged`; a null `onChanged` or `enabled: false` disables.
- Clamp `value` into `min..max` before the fork sees it, and treat a non-positive span as zero: a spec whose value sits outside its range still paints inside the rail instead of tripping the widget's own assert.
- **A disabled slider is this package's own composition.** `material_ui` 1.6.0 reads its focus node as `widget.focusNode ?? _focusNode!` and only creates `_focusNode` for an enabled slider, so a disabled `mu.Slider` throws while building. The adapter draws that case itself, from the fork's own disabled slider theme: `mu.SliderTheme.of(context)` already ships the disabled inactive track, active track and thumb colours, and the inert M3 form is exactly what they describe — the rail at the theme's `trackHeight`, the filled portion up to the value's fraction, and a 20 px thumb dot sitting on it, with the value announced through `Semantics(slider: true)`. It is wrapped in `IgnorePointer` and tagged `material:inert-slider`, so the number stays on screen and no drag reaches the callback. An unbounded parent gets the library's own minimum slider width of 200 px rather than an infinite track. The fork fix retires the branch.
- The spec has no `divisions` field; do not invent stepped behaviour this contract does not request.

### Segmented (`MaterialSegmentedBuilder`)

- Use the native Material UI segmented button.
- Map `labels` in order, honour `index`, and route selection through `onChanged`; a null `onChanged` or `enabled: false` disables — as with the checkbox, the closure is only built when a callback exists.
- Honour `expand` through the fork's own `expandedInsets: EdgeInsets.zero`, so segments share the full width instead of the adapter faking it with a width hack. The fork's selected icon is switched off; the label is the segment's only content.

### Progress (`MaterialProgressBuilder`)

- Use `mu.LinearProgressIndicator`.
- Pass `value` through unchanged: `null` means indeterminate, and the fork must render its own animation rather than the adapter substituting a determinate bar at zero.
- Map `height` to the indicator's thickness, and tint the fill with `spec.barColor ?? theme.colors.primary` over `theme.colors.fillSecondary`.
- `showLabel` has no slot in the fork's indicator, which paints a bar only. The trailing percentage is therefore never drawn — the omission is documented at the builder rather than overlaid with a hand-built label widget (§15).

### Select (`MaterialSelectBuilder`)

- Use the native `mu.DropdownButton<T>`: it is generic over the caller's value type, so the chosen value comes back unchanged, and its `hint` slot is `LanguageSelectSpec.placeholder`. The control is `isExpanded` and each item is a `mu.DropdownMenuItem` labelled through `spec.itemLabel`.
- Before the builder runs, the adapter rewrites the spec into the only shape the fork can carry: `mu.DropdownButton` asserts that the current value matches exactly one item, so null and repeated item values are dropped from the list, and a value the list does not carry becomes `null` — the library's own *nothing chosen* state, whose slot paints the placeholder. The field therefore reads as unchosen rather than pretending an off-list value is selected, and the opened menu keeps only choosable items.
- A disabled select is the library's own inert state: a null `onChanged` greys the control and refuses the menu, so `enabled: false` needs no extra work.
- The fork's menu can hand back a null selection; the contract has no such case, so a null is dropped rather than reported to the caller.

### Tab bar (`MaterialTabBarBuilder`)

- Use the native `mu.TabBar` — the sliding indicator and the label weight are what make a Material tab read as one. It is driven by a `mu.TabController` rather than by an index, so the controller lives in this package, in a stateful holder that rebuilds it when the tab count changes and asserts `spec.index` onto it on every update.
- Tabs are built as `mu.Tab(text:, icon:)`, and a strip of more than five tabs is `isScrollable`.
- A tap reports the index through `onTap`, gated by `enabled`; the caller's next rebuild either agrees or asserts the old index back, which is what keeps the strip controlled rather than quietly self-selecting.
- `LanguageTabsSpec.spacing` has no Material counterpart, so the strip uses the library's own tab padding (§15).

### Tab view (`MaterialTabViewBuilder`)

- Use the native `mu.TabBarView` — the page-to-page slide and the kept-alive neighbours are what make a Material tab view read as one. It follows a `mu.TabController` of its **own**: the strip and the view are two controls of the contract, each driven by its spec's index, so a page and a strip that are not siblings in the caller's tree still agree without either owning the other.
- `duration` maps onto the controller's `animationDuration`, the only place the fork keeps that knob; a change to the page count or to the duration rebuilds the controller, because the fork reads both in its constructor.
- An index beyond a shrinking page list is clamped into range rather than allowed to crash the view (§15).
- A swipe moves the controller, which is reported through `spec.onIndexChanged`; the caller's next rebuild either agrees or pulls the page back.
- `pages` of one, or no callback, leave the view non-interactive by switching the page scroll off with `NeverScrollableScrollPhysics`, not by dropping the pages.

### Scaffold (`MaterialScaffoldBuilder`)

- Use the native `mu.Scaffold`, which takes the spec's parts as they are named: the frame's background, the floating action, `avoidKeyboard` as `resizeToAvoidBottomInset`, and `extendBodyBehindAppBar` as itself. Material then owns the body's extent, safe area and scroll-under behaviour, which is what this language exists to get.
- The dispatched bar and the dispatched bottom strip go into the app-bar and bottom slots. Both want a `PreferredSizeWidget`: a fork bar already is one and goes straight in, and any other widget is given the height its own frame would have used — the environment geometry's `appBarHeight` (56 by default) or `navBarHeight` (64) — inside a `mu.PreferredSize`.

### App bar (`MaterialAppBarBuilder`)

- Use the native `mu.AppBar`, whose slots are the spec's fields under their own names: `leading`, `title`, `actions`, `centerTitle`, `bottom`, `toolbarHeight` and `backgroundColor`, so nothing has to be approximated. The title is a single-line ellipsised `Text`; a null `background` keeps `theme.colors.bgElevated`.
- A null `centerTitle` keeps Material's own start alignment rather than second-guessing it; a centre-titled bar is a platform statement, so the caller overrides it deliberately.
- The bar is returned as a `PreferredSizeWidget`, which is what the frame's app-bar slot needs in order to sit above the content rather than be stacked over it. Its `bottom` slot is taken only where that strip is already a `PreferredSizeWidget`, because the fork's slot requires one.

### List row (`MaterialListRowBuilder`)

- Use the native `mu.ListTile`, which covers every field the contract carries — `leading`, `title`, `subtitle`, `trailing`, both press handlers, the `selected` state (tinted with `theme.colors.primary`) and focus — so the row is the library's own: its ink splash, its state layers and its text roles come from `mu.Theme`. Title and subtitle are single-line and ellipsised.
- A row with no tap and no long-press is passed as disabled rather than left looking tappable.
- `divided` is the one field the tile has no slot for — a Material list puts its separators between items — so the fork's own `mu.Divider`, at the token's line width and in `theme.listTile.dividerColor`, is drawn under the tile (§15).

### Nav bar (`MaterialNavBarBuilder`, and the adapter's inert form)

- Use the native `mu.NavigationBar`, the contract's counterpart one-for-one: destinations carry an icon and a label, the selected index is an `int`, and the callback is an index rather than a route, so the shell's branch switching survives the language change. `enabled: false` maps onto a null `onDestinationSelected` — the library's own inert state — rather than dropping the callback.
- The fork asserts at least two destinations and an in-range selection, and one destination is not a choice between anything. So a bar with a single cell, an empty bar, and a bar whose index fell out of a shrunken shell are drawn by the adapter instead, out of this library's own pieces: the elevated surface role the live bar sits on, one cell per destination with its glyph and label in `theme.tabs.itemColor` (the unselected role — nothing carries a selection), and no press target under either, so a tap reports nothing. The strip is tagged `material:inert-nav-bar` (§15).

### Toast (`MaterialToastBuilder`)

- Only the surface is built here: the overlay it floats in, the fade-and-slide and the removal timer stay in the core's `LiveToast.show`, which is what reads `spec.duration`. The builder paints the message and nothing else.
- That split is also why the surface is a `mu.Material` card rather than a `mu.SnackBar`: the fork's bar reads `widget.animation!` in `initState` and is only ever built by a `ScaffoldMessenger` that owns that animation, so a `SnackBar` handed to a caller-owned overlay throws. The card takes its colour, elevation, shape and content text role from the fork's own `SnackBarThemeData`, which is where Material keeps those decisions, so the surface is still the library's.
- The status colour is the token's — `spec.accent`, or the role matching `LiveToastType` — because the token decides that `warning` looks like this app's `warning` in every language; the glyph is `spec.icon`, or Material's own for that type.

### Dialog (`MaterialDialogBuilder`)

- Use the native `mu.AlertDialog`, handed back as a plain widget rather than shown: `showLiveDialog` owns the route, the barrier colour, the fade-and-scale, the outside tap that dismisses, and the centred `Center → Padding → ConstrainedBox` frame. `insetPadding: EdgeInsets.zero` stops the fork from insetting the surface a second time inside the core's padding, and `scrollable: true` is the surface's own guard so a body taller than the screen scrolls instead of overflowing.
- The mapping is direct: the fork's four slots are the spec's four fields. `icon` is wrapped in an `Icon` and its colour taken from `theme.colors.primary` (a null icon leaves the slot null and the fork drops its icon padding); `title` is drawn with the token's title role; `content` passes through untouched with the token's body handed as `contentTextStyle`; `actions` is a `List<Widget>` the fork lays out in an end-aligned `OverflowBar`, and an empty list becomes null so the fork omits the slot and its padding.
- The action buttons arrive as already-dispatched controls, so they match the language without this builder re-picking them.
- `dismissible` is the route's promise, not the surface's: the core already read it when it built the barrier, so it is not drawn twice here.

### App host (`MaterialHostBuilder`)

- Use the fork's own `mu.MaterialApp.router`, which is the point of the language: the host installs the fork's theme scope, its ink splash and its selection toolbar, so a page reads Material UI from the window frame down. Hosting this subtree on Flutter's `WidgetsApp` instead would keep the SDK's transitions, scrollbars and overlay underneath a set of otherwise-native controls.
- The spec passes straight through — `routerConfig`, `title` / `onGenerateTitle`, the delegates and locales the caller supplied, the `builder` that wraps the navigator, and the debug-banner flag. Both of the host's theme slots carry the one theme `MaterialThemeBuilder` derived from the resolved token, so the host cannot second-guess the brightness the appearance setting already chose.
- This is the `LiveUiSurface.appHost` capability, declared in `materialSurfaces`.

### Shell (`MaterialShellBuilder`)

- Use the fork's own `mu.NavigationRail`, which paints the selection with the Material 3 indicator pill and models a `disabled` destination — the one shell widget in this library that can, so `LiveShellDestination.enabled` maps onto it instead of the builder refusing the tap. `trailing` has a real slot and is pinned to the rail's bottom through `trailingAtBottom`; a selection the spec does not name is a null `selectedIndex`, the rail's own "nothing selected".
- The rail is only the strip: Material composes it beside the body, so this builder draws that `Row` itself and leaves the page frame to the language's `scaffold`.
- `placement` is honoured rather than folded: `rail` takes the column, `bottom` goes back through this adapter's own `navBar` — the fork's `NavigationBar`, with its guard for a bar too short to satisfy its assert — under the page in a `Column`, and `adaptive` reads the same window geometry the rest of the layout reads, so a narrow window switches form at the same width whichever language is active. The bottom strip has no footer slot, so that form drops `trailing`.
- `placement: none`, or fewer than two destinations, returns `spec.child` untouched: one destination is not a navigation choice, and the frame is the page's own.
- This is the `LiveUiSurface.appShell` capability, declared in `materialSurfaces`.

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder can receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup, using the real `LanguageRegistry` API:

```dart
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.material: materialAdapter},
);

const resolver = LiveUiResolver(registry: registry);
```

`LanguageRegistry` is keyed by `LiveDesignLanguage`, not by the string id — the id is for persistence, diagnostics, and the selector, while resolution is enum-typed. `createMaterialAdapter()` and `materialAdapter` are interchangeable; prefer the const instance where a compile-time constant is required.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference from `UiConfig.language`.
- Selecting the active language.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_material` must not register itself through global static initialization or require the business layer to import it.

### Registration failure

`LanguageRegistry` takes one argument, `adapters`, and `LiveUiResolver.resolve` returns the adapter for the language or raises. What a host can therefore hear about is a fault, a drift, or an environment that cannot pay for an effect:

| Failure | Meaning for this adapter |
|---|---|
| `LiveUiResolutionException` | `LiveDesignLanguage.material` has no adapter in this build. A composition fault, not a degrade: the alternative would be a window painted by a library the user did not choose |
| `LiveUiCapabilityException` | `materialCapabilities` or `materialSurfaces` names a control or surface the adapter does not override — capability/override drift, and always a bug in this package rather than a state a page can be written against |
| `LiveUiDiagnosticCode.unsupportedEffect` | The environment cannot afford an effect, so a verified degraded visual stands in |

Diagnostics are delivered to a host-supplied `LiveUiDiagnosticSink`, so the sink must be wired at the composition root. With this language active the sink should stay empty for controls and surfaces: `materialCapabilities` declares all seventeen and `materialSurfaces` both surfaces, so there is no expected entry to filter out and no noise a host should learn to ignore. Anything the sink does report about this package means the declaration and the methods disagree, which §17 also fails the build for.

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
if (style == 'material') {
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
      +---- Material UI adapter  (live_uikit_material -> material_ui)
      +---- Fluent adapter
      +---- Cupertino UI adapter
      +---- macOS adapter
      +---- Glass adapter
      +---- Neumorphic adapter
      +---- Wind adapter
      +---- ForUI adapter
```

Switching changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services. The resolver returns an adapter or raises `LiveUiResolutionException`, so a switch that names a language this build did not register is a fault the composition root hears about, not a subtree that quietly keeps the previous library's look.

Material UI needs particular care here, for two reasons:

1. **Material UI ↔ the SDK's own Material look is the most error-prone pair to switch.** This language draws from a fork whose class names shadow Flutter's, so a stale `mu`-prefixed widget, an inherited `mu.Theme`, or an import that lost its alias can survive a switch unnoticed. A switch must fully replace the theme scope, and §16 asserts both the fork scope present and the SDK classes absent.
2. **Every control moves with the switch, including the generic ones.** `select` is `mu.DropdownButton<T>` here, so the caller's `T` survives the transition, and the tab strip and the page view each follow the index their specs carry rather than a controller a neighbouring language happens to own. The two surfaces go too: the tree is hosted by `mu.MaterialApp` while this language is active, and its shell is the fork's rail or bar.

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

Because Material UI takes Material's focus-ring and state-layer conventions from the fork's own theme, focus indication comes out of `mu.ThemeData` rather than being drawn by the builders. That inheritance must be verified against the resolved `material_ui` version rather than assumed: `mu` types are not covered by Flutter SDK focus tests, so a focus treatment that exists in the SDK may or may not exist in the fork.

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
- **Material UI on Android is the rendering the other seven are judged against.** Android users see Material first, so if selecting this language next to another of the eight produces a window nobody can tell apart, that is a mapping defect, not a coincidence — §8.1 requires the fork's own theme path, and §16 requires the SDK Material classes to be absent from the tree.

No Material UI effect may depend on a native window API, and none should depend on platform view plugins.

## 14. Localization and accessibility

Like the Fluent, Cupertino and ForUI adapters, `material_ui` genuinely requires its own localization delegate: the fork ships its own `GlobalMaterialLocalizations`, exposed through this package as:

```dart
const List<LocalizationsDelegate<dynamic>> materialLocalizationsDelegates = [
  mu.GlobalMaterialLocalizations.delegate,
];
```

The app must append it to the core's delegates in its `MaterialApp`:

```dart
MaterialApp(
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...materialLocalizationsDelegates,
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

- An effect the environment cannot afford — the one diagnostic left, `LiveUiDiagnosticCode.unsupportedEffect`, for a blur or backdrop filter the device will not pay for.
- An invalid specification — a slider with `max <= min`, a segmented control whose `index` is out of range for `labels`, a tab index beyond `tabs.length`.
- A theme property that cannot be mapped directly into `mu.ThemeData`.
- A spec field the fork cannot express, such as `LanguageProgressSpec.showLabel` or `LanguageTabsSpec.spacing`.
- An SDK-material leakage: a fork widget resolving an inherited SDK Material theme, or an SDK Material class drawing a control this language was asked for.
- An adapter construction or registration error.

A control outside `materialCapabilities`, or a surface outside `materialSurfaces`, is not a downgrade to report — it is a fault: `requireControl` and `requireSurface` raise `LiveUiCapabilityException`, which says the declaration drifted from the methods the adapter actually overrides. Both sets name everything this adapter implements, so a Material page has no control left to ask about and such an exception is always a bug in this package rather than a state to design around. A language this build registered no adapter for is raised by `LiveUiResolver.resolve` as `LiveUiResolutionException`.

Use the diagnostics contracts from `live_uikit` — `LiveUiDiagnostic`, `LiveUiDiagnosticCode`, `LiveUiControl`, `LiveUiSurface`, and `LiveUiDiagnosticSink`. Do not introduce a direct dependency on Talker or another application logging implementation, and do not define adapter-local diagnostic types.

Expected behavior:

- A spec shape the fork refuses to build is drawn from that same library's own theme values — the inert slider rail and the inert destination strip — with the value still on screen and no input reaching the callback (§9). It is never drawn by another library.
- Invalid control data should follow core validation rules. Where this package guards a fork assert itself, it does so visibly: the page view clamps an index into a shrinking page list, the inert rail clamps its filled fraction into the range, and the select drops a value its item list does not carry so the field reads as nothing chosen.
- Programming errors should not be swallowed.
- Diagnostics should avoid logging user-entered text, credentials, or other sensitive content — material for `LanguageTextFieldSpec`, where the spec carries the controller, `placeholder`, and `errorText`.
- A `mu`-import mistake fails loudly at compile time thanks to the prefix convention; a runtime type mismatch surfaces as a defunct widget rather than a diagnostic. Where a builder detects a mismatch it can act on, it takes the composed form documented for that control and leaves its key (`material:inert-slider`, `material:inert-nav-bar`) in the tree for a caller or a test to assert on; it does not render a half-themed control.

## 16. Testing strategy

Four directories, one per concern: `test/adapter/` (contract), `test/theme/` (§8.1 mapping and §8.3 re-skin), `test/widgets/` (§9 control rules through the real adapter path, with `stub_router.dart` as the router harness), `test/integration/` (§11 resolution and switching). Everything in them runs headless; the items that need hardware are listed at the end and stay open.

### Unit tests

`test/adapter/material_contract_test.dart` covers the highest-risk surface. It asserts:

- `adapter.id == materialAdapterId == 'material'`.
- `adapter.displayName == 'Material UI'` and `adapter.language == LiveDesignLanguage.material`.
- Every one of the seventeen `LiveUiControl` values reports `capabilities.supports(...) == true`, and `capabilities.supported` is exactly the whole enum — the declaration leaves no control unasked.
- Both `LiveUiSurface` members are declared as owned, and `adapter.surfaces.supports(...)` is false for anything outside that pair.
- `LiveUiResolver.resolve(LiveDesignLanguage.material)` hands back this adapter, and `requireControl` passes for every member of `LiveUiControl` — a declared capability with no override would raise `LiveUiCapabilityException` there.
- A language this build did not register (`fluent`) throws `LiveUiResolutionException` rather than resolving to somebody else's renderer. `requireSurface` for both owned surfaces is exercised the same way in the integration suite (§16.3).

`test/theme/material_theme_test.dart` adds the mapping half of §8.1: brightness, `scaffoldBackgroundColor`/`cardColor` following the token, a changed accent producing a different generated `mu.ColorScheme`, and a dark token yielding different surfaces than the light one.

The registry and resolver under test are constructed as `LanguageRegistry(adapters: {LiveDesignLanguage.material: adapter})` with `LiveUiResolver(registry: registry)` — the same types production uses, so these are contract tests rather than mock tests.

### Widget tests

`test/widgets/material_native_controls_test.dart` drives every control through a `LiveConfigProvider` with this adapter registered, so it exercises the real dispatch rather than the builders in isolation. Covered:

- Callback, disabled and loading states: a spec with no callback or `loading: true` yields `onPressed == null` on the fork button, and a null callback disables switch, checkbox and segmented as hard as `enabled: false` does. Pointer taps run under a desktop `debugDefaultTargetPlatformOverride` so the fork picks `InkRipple` rather than the shader-backed `InkSparkle` the test binding cannot paint.
- Variant mapping: each `ButtonVariant` selects the expected `mu` class, and `danger` carries the token error fill through `styleFrom` rather than the seed-derived scheme.
- `focusNode`, `autofocus`, `expand` and `tooltip` preserved on the button; `focusNode` preserved on the live slider.
- Text field controller identity across rebuilds, `onChanged`, and an inline `Style` overriding the token body text.
- Switch, checkbox, segmented and progress value and callback semantics, including `expandedInsets: EdgeInsets.zero` for a widened segmented control.
- Card tap, long-press, `selected` fill, `bordered` side, `dense` padding, an explicit `padding`, and focus reaching only an interactive card.
- Progress `value == null` staying indeterminate, `barColor` overriding the primary tint, `height` mapping to the indicator thickness, and `showLabel` yielding no label — the omission §9 documents.
- The disabled slider drawn as this package's inert rail: no `mu.Slider` in the tree, `material:inert-slider` present, a drag changing nothing and no exception (§9/§15).
- The chrome set — `mu.Scaffold`, `mu.AppBar`, `mu.ListTile`, `mu.NavigationBar` — rendering through the fork, reporting a tap and a destination index; a disabled strip keeping its destinations and stopping reporting; and a strip the fork cannot assert for (one destination, an out-of-range index, or an empty list) arriving as `material:inert-nav-bar` with its cells still labelled (§9/§15).
- The app host: `mu.MaterialApp` in the tree with the SDK `MaterialApp` absent, and both of the host's theme slots carrying the token's resolved brightness rather than the platform's.
- The three controls the fork drives differently from the neutral spec: `select` as `mu.DropdownButton` carrying the value and the placeholder (an off-list value dropping to the library's unchosen state and painting the hint, never rendering as selected), `tabBar` as `mu.TabBar` reporting the tapped index, and `toast` as a themed `mu.Material` card with no `mu.SnackBar` in sight (§9).
- The dialog surface handed back to the core's route as `mu.AlertDialog` — title, body and dispatched action buttons all present, the icon spec reaching the fork's icon slot — and the page view as `mu.TabBarView` building the page its spec names, then reporting an index when a swipe moves it (§9).
- The shell: `mu.NavigationRail` with the trailing entry pinned in the rail form, a disabled destination that cannot be selected because the fork models it, and a bottom request drawing `mu.NavigationBar` under the page instead (§ surfaces).
- Correct `mu.Theme` scope, and the mixed-tree defect unique to this package: with Material UI active no SDK `FilledButton`/`ElevatedButton`/`TextButton`/`Card`/`TextField`/`Switch`/`Checkbox`/`Slider`/`SegmentedButton`/`LinearProgressIndicator`/`Tooltip` is in the tree.
- Right-to-left layout with translated labels at a narrow width, and both the core's and the fork's `MaterialLocalizations` resolving with the fork delegate appended (§14).

### Integration tests

`test/integration/material_style_switching_test.dart` runs this language through the production resolver and the real `LiveConfigProvider`:

1. Every `LiveUiControl` value and every `LiveUiSurface` member resolves through this adapter, and `requireControl`/`requireSurface` pass for all of them — a run that renders Material UI reports no control or surface diagnostic at all (§16.3, §16.8).
2. Brightness and accent changes re-skin `mu.ThemeData` in place, without a restart (§16.4).
3. A re-pumped page installs a fresh fork scope rather than keeping a stale one: `mu.TextField` and `mu.Theme` present, the SDK `TextField` absent, on both passes (§11's hardest pair, §16.5).
4. A caller-owned `TextEditingController` keeps its text and its identity across those pumps (§16.6).
5. `select` and the tab strip stay callable and typed on every pass (§16.7).

Registering a *second* third-party adapter in the same test is deliberately not done: §3.3 forbids a dependency on another style package, so cross-adapter switching is an application-level integration concern, exercised from the app's own test suite.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum include Android, an iOS or macOS target, Windows desktop, and Android TV in the planned validation matrix — Material UI has no platform exclusions, so all six claimed platforms need evidence rather than inference. Focus traversal under `mu.ThemeData`, Android TV D-pad behaviour, and contrast on the generated tonal surfaces are the three items no headless test can settle (§12, §14).

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal gate in `.github/workflows/architecture.yml`. The script holds an adapter → widget-library map; adding an adapter adds one entry and every rule below then covers it automatically.

- `live_uikit_material` depends on `live_uikit` and `material_ui`.
- `live_uikit_material` does not depend on any other style adapter.
- The core package does not depend on `material_ui`.
- No package other than this adapter — business packages, feature packages, `apps/` — imports `package:material_ui/material_ui.dart` or declares it as a dependency. Enforced on the declared edge as well as the imported one, so a pubspec that names another adapter's library fails even before anything imports it.
- Every `material_ui` import inside this package uses the `mu` alias, in `lib/` and in `test/`. An unqualified import would resolve to the SDK's Material widgets and quietly defeat the adapter. The alias must not leak through the public barrel.
- The public barrel exports only `src/adapter/material_registration.dart` — any other directive in it is a finding.
- `materialCapabilities` matches the set of control methods `MaterialLanguageAdapter` actually overrides. `wrap` and names starting with `_` are ignored; a control declared without an override, or overridden without being declared, fails the build. This is what catches the drift where a builder is added but its control is never declared.
- `materialSurfaces` is checked the same way against the two surface methods, `appHost` and `shell` — owning the app host says nothing about owning the shell, so each is compared to its own declaration. Exactly one `*_adapter.dart` and one `*_capabilities.dart` must sit under `lib/src/adapter/`, and an adapter that overrides a surface while declaring none is a finding.
- The README's list of native controls is checked against `materialCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate. The prose names are the
  `LiveUiControl` members in their spec spelling, so `text field`, `tab bar`, `app bar`, `list row`,
  `nav bar` and `tab view` have to be written exactly that way.
- `materialLocalizationsDelegates` must stay exported from the registration file, because this
  package's §14 tells the composition root to append it; a delegate appearing or disappearing
  without the spec is a finding.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

The gate is textual, so it cannot see an SDK Material type reached through a transitive re-export inside a builder body; that is what the SDK-widget-absent assertion in §16 covers at runtime instead.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_material
flutter analyze packages/live_uikit_material
flutter test packages/live_uikit_material
```

Run these from the workspace root with the repository's normal Flutter SDK and workspace resolution.

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Implement `MaterialLanguageAdapter`, which `implements LanguageAdapter` — an `abstract interface class`, so there is no base implementation to inherit and every member is written here.
- Define the stable id `material`, `displayName` `Material UI`, and `language` `LiveDesignLanguage.material`.
- Declare `materialCapabilities` and `materialSurfaces`, and export the registration API.
- Add `material_contract_test.dart` covering id, capability and surface truthfulness, and resolver behavior.

Done.

### Phase 2 — Theme integration ✅

- `MaterialThemeMapper` wired to `wrap`.
- `MaterialThemeScope` installing `mu.Theme` plus the transparent `mu.Material` ink surface, `MaterialThemeBuilder` mapping brightness, accent seed, and the token's page/card surfaces.
- The global font family is mapped into `mu.ThemeData.fontFamily`; density and per-role typography stay builder-level (`ControlSize`, `LanguageCardSpec.dense`, `LiveTheme.text`), because the fork builds its own text scale. Remaining mapping work is limited to what the fork can express. Fixed-typed fork fields (visual density, typography roles) stay library defaults and are recorded as non-token-mappable in §8.1 rather than half-mapped.

### Phase 3 — Core controls ✅

Implemented across the nineteen `lib/src/widgets/` builders: the eight input and container controls (button, card, text field, switch, checkbox, slider, segmented, progress), the chrome (scaffold, app bar, list row, nav bar), the two overlays (toast, dialog), `select`, and the tab strip and page view the fork drives through controllers of its own. Each builder preserves the spec fields its library can express, composes in this package the press gating and label layout the library does not hand it, and is covered by the §16 widget tests. The documented omissions are `LanguageProgressSpec.showLabel`, `LanguageTabsSpec.spacing`, and `LanguageButtonSpec.selected` and its inline `style`; the two inert forms (§9 Slider, §9 NavBar) are compositions of this library's own theme values, not gaps in coverage.

### Phase 4 — Interaction and accessibility ◐

- Headless coverage landed: keyboard-focusable controls keep their `focusNode`/`autofocus` through the fork widgets, disabled controls are wired dead rather than decorative, the inert slider and inert strip assert their semantics and their refusal to report input, and RTL with translated labels is tested at a narrow width.
- Open, needs hardware: focus traversal and the visible focus ring under a real `mu.ThemeData`, Android TV D-pad, and contrast measured on the generated tonal surfaces.
- Add `lib/src/interaction/` only if that testing finds a Material UI-specific gap; it does not exist today.

### Phase 5 — Production readiness ◐

- §17 architectural CI checks are implemented in `tool/check_architecture.ps1`, including the capability/override and surface/override drift assertions and the `mu`-alias rule.
- §11 is covered through the production registry and resolver: every control and both surfaces resolve to this adapter with nothing reported, the theme scope is re-installed rather than reused, and caller-owned state is preserved across the pumps.
- Open: platform-by-platform evidence for the six claimed targets (§13), and the known limitations below promoted into a `docs/decisions/` entry if any of them is ever lifted.

### Known limitations

- A disabled `mu.Slider` cannot build in `material_ui` 1.6.0 — it dereferences a focus node it only creates when enabled — and `mu.NavigationBar` asserts at least two destinations with an in-range selection. Those three spec shapes are drawn from this package's own inert forms, keyed so a caller can tell them apart (§9/§15). Re-check when the fork is upgraded; the assertion that would catch the fix is already in `test/widgets/`.
- `LanguageProgressSpec.showLabel` has no fork equivalent and is dropped rather than hand-drawn (§9).
- `LanguageTabsSpec.spacing` has no Material counterpart; the strip uses the library's own tab padding (§9).
- `LanguageButtonSpec.selected` and the inline `LanguageButtonSpec.style` are not mapped onto the fork's button, which paints its own surface (§9).
- `LanguageAppBarSpec.bottom` is taken only where the strip already is a `mu.PreferredSizeWidget`, because the fork's slot requires one (§9).
- Cross-adapter switching (Material UI against Fluent, Cupertino UI, …) is not testable from this package because §3.3 forbids depending on another adapter; it belongs to the application's integration suite.

The remaining work on this contract is fidelity rather than coverage: a fork affordance for `selected` and the inline `style` to sit on, and a re-check of the two inert forms whenever `material_ui` is upgraded so a fixed fork can retire this package's own drawing. Any such change moves the builder, `materialCapabilities` or `materialSurfaces`, the README's control list and the contract test in the same commit (§17).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `material_ui` only for its core integration.
- [x] It implements the core `LanguageAdapter` interface directly and defines no competing interface.
- [x] It uses the stable adapter id `material`, with `displayName` `Material UI` and `language` `LiveDesignLanguage.material`.
- [x] `materialAdapterId`, `materialAdapter`, `createMaterialAdapter()` and `materialLocalizationsDelegates` are exported, and the barrel exports nothing else.
- [x] It reports accurate capabilities: all seventeen controls in `materialCapabilities`, and both `appHost` and `appShell` in `materialSurfaces`.
- [x] The declared capability and surface sets match the overridden methods, asserted in CI.
- [x] It maps the resolved `DesignToken` into `mu.ThemeData` rather than bypassing the fork's theme.
- [x] It uses native `material_ui` controls where the library has one and that library's own parts where it does not, and never the SDK Material widgets in their place.
- [x] Every `material_ui` import is `mu`-aliased and the alias does not leak into the public API.
- [x] It installs a `mu.Theme` scope rather than a nested application shell.
- [x] It does not duplicate the core theme configuration or own business state or persistence.
- [x] Builders gate press and compose the button and checkbox content in this package, so no rule lives in two places.
- [x] Runtime switching preserves business state, and re-pumping installs a fresh fork scope rather than a stale one.
- [x] `select` stays generic over the caller's `T`, and the tab strip and page view stay callable and controlled through their own controllers.
- [x] `materialLocalizationsDelegates` is documented as appended to the core delegates, and core strings still resolve with Material UI active.
- [x] Fields the fork cannot express are documented at the builder that drops them, and the shapes it refuses to build are drawn from its own theme values (§9/§15).
- [x] Diagnostics use the shared core contract and no logging dependency.
- [x] Tests and static analysis pass.
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the headless half is; focus traversal, the visible focus ring, Android TV D-pad and contrast on generated tonal surfaces need hardware (§12/§14/§16).
- [ ] Platform support claims are backed by actual tests (§13/§16).

## 20. Final architecture decision

`live_uikit_material` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, the public controls, the theme model, the runtime selection and the resolution faults, and paints nothing itself.
- `live_uikit_material` maps those contracts to Material UI: `MaterialLanguageAdapter` implementing `wrap`, all seventeen control builders and both surface methods, with `materialCapabilities` and `materialSurfaces` declaring exactly that set.
- `material_ui` supplies the underlying forked Material widgets and theme facilities.
- The PureLive application composition root registers the adapter, appends `materialLocalizationsDelegates`, and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This package is the widest-coverage adapter, and its risk is the mirror image of that completeness. Its value is a genuinely distinct Material rendering path; its failure mode is collapsing into the Material widgets the Flutter SDK already ships — a control drawn by the fork in name and by an unaliased import in fact — and becoming indistinguishable from a page that never switched at all. The seed-based `mu.ThemeData` path, the mandatory `mu` import alias, the capability/override and surface/override drift assertions, and the SDK-widget-absent tests all exist to keep that line sharp.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls.
