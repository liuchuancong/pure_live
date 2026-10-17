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

**Scope today.** Wind renders **button, card, text field, switch, checkbox, select, slider, segmented, progress, tab bar, scaffold, app bar, list row, nav bar, toast, dialog and tab view** — all seventeen contract controls — and both structural surfaces, `appHost` and `shell`. Six of them are drawn by a `fluttersdk_wind` widget; the other eleven are built in this package from that library's own parts, because it ships no widget for the job. See §7 and §9.

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

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, the `LanguageAdapter` interface, the capability model, the resolver/registry, and the diagnostic contract all belong to `live_uikit`.
2. **Wind owns Wind visuals.** Use native `fluttersdk_wind` controls wherever a clean mapping exists, rather than drawing Wind-style controls from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application. The Wind switch and checkbox builders are fully controlled — value, callback, and disabled flag pass straight through the spec.
5. **Runtime switching is supported.** Switching between Wind and any other style must not require business pages to import or construct different control classes.
6. **Honest capabilities.** `windCapabilities` declares exactly the controls `WindLanguageAdapter` implements — today that is all seventeen of them — and `windSurfaces` declares both structural surfaces. A capability claimed without an implementation is a defect: `requireControl` throws rather than drawing something the caller did not ask for.
7. **Platform-aware behavior.** Wind appearance can be selected on any supported platform, but native Windows system integrations must not be assumed on every platform.
8. **Everything is built here.** There is no third way for a control to render: the contract has no default implementation, so `windCapabilities` claims exactly what `WindLanguageAdapter` implements, and a capability claimed without an implementation fails loudly with `LiveUiCapabilityException`. Effects the device cannot afford are the one thing that still degrades, and they surface `unsupportedEffect`.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Wind theme mapping (`DesignToken` → `WindThemeData`, installed through a Wind theme scope).
- Wind construction for all seventeen contract controls: button, card, text field, switch, checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list row, nav bar, toast, dialog and tab view. Six are a library widget; eleven are composed from its parts.
- Both structural surfaces: the app host, which is Flutter's `WidgetsApp` under the library's theme scope, and the shell, composed from the library's styled parts because it ships no navigation widget.
- Wind-specific control defaults for those controls.
- Reporting the complete capability and surface set to the core registry.
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
| `live_uikit_material` | No | Adapters must remain independent |
| `live_uikit_cupertino` | No | Adapters must remain independent |
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
    │       │   ├── wind_adapter.dart
    │       │   ├── wind_capabilities.dart
    │       │   ├── wind_surfaces.dart
    │       │   └── wind_registration.dart
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
    │           ├── wind_select_builder.dart
    │           ├── wind_slider_builder.dart
    │           ├── wind_segmented_builder.dart
    │           ├── wind_progress_builder.dart
    │           ├── wind_tab_bar_builder.dart
    │           ├── wind_scaffold_builder.dart
    │           ├── wind_app_bar_builder.dart
    │           ├── wind_list_row_builder.dart
    │           ├── wind_nav_bar_builder.dart
    │           ├── wind_toast_builder.dart
    │           ├── wind_dialog_builder.dart
    │           ├── wind_tab_view_builder.dart
    │           ├── wind_host_builder.dart
    │           └── wind_shell_builder.dart
    ├── test/
    │   ├── adapter/
    │   │   └── wind_contract_test.dart
    │   ├── theme/
    │   │   └── wind_theme_test.dart
    │   ├── widgets/
    │   │   ├── wind_native_controls_test.dart
    │   │   └── stub_router.dart
    │   └── integration/
    │       └── wind_style_switching_test.dart
    ├── interaction/        # (optional, not created) focus / keyboard / TV mapping
    ├── icons/              # (optional, not created) semantic-icon mapping
    ├── diagnostics/        # (optional, not created) adapter-local mapping diagnostics
    └── example/            # (optional, not created) integration demo
```

Do not create empty files just to match the optional directories. Add each module only when its functionality is implemented — and keep the capability declaration (§7) in sync with the overrides the moment a control is added to the contract.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | `WindLanguageAdapter`, the `windCapabilities` set, and the registration API |
| `theme/` | Translate the resolved `DesignToken` into `WindThemeData` and install it via a Wind scope |
| `widgets/` | Build every control of the contract from core `Language*Spec` objects, mapped or composed |
| `test/` | Verify the contract, stable id/display name, and that capabilities match the overrides |
| `interaction/` *(optional)* | Map keyboard, focus, and TV-specific behavior once native surfaces justify it |
| `icons/` *(optional)* | Map supported semantic icons to Wind icons |
| `diagnostics/` *(optional)* | Report Wind-specific unmapped variants; the core diagnostics already cover an effect a device cannot afford |
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

export 'package:live_uikit_wind/src/adapter/wind_registration.dart';
```

`wind_registration.dart` provides exactly three symbols:

```dart
const String windAdapterId = 'wind';
const LanguageAdapter windAdapter = WindLanguageAdapter();
LanguageAdapter createWindAdapter() => const WindLanguageAdapter();
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
  LiveUiSurfaceCapabilities get surfaces;

  Widget wrap(BuildContext context, DesignToken token, Widget child);

  // the seventeen control builders
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

  // the two structural surfaces
  Widget appHost(BuildContext context, LanguageHostSpec spec);
  Widget shell(BuildContext context, LanguageShellSpec spec);
}
```

`LiveUiControl` has exactly the seventeen members listed above, and `LiveUiSurface` has the two.
`LanguageRegistry` takes `adapters:` alone: a language with no adapter in it fails resolution with
`LiveUiResolutionException`, because there is no default adapter and nothing else that could render it.
`LiveUiResolver.resolve` returns the adapter or throws, and `requireControl`/`requireSurface` throw
`LiveUiCapabilityException` when a capability or surface is declared without a matching override.

There is nothing to extend underneath: `LanguageAdapter` is an
`abstract interface class`, every adapter implements it directly, and each of the seventeen control
builders plus `appHost` and `shell` must be written. Wind implements all of them.

```dart
class WindLanguageAdapter implements LanguageAdapter {
  const WindLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.wind;
  @override String get id => 'wind';
  @override String get displayName => 'Wind';
  @override LiveUiCapabilities get capabilities => windCapabilities;
  @override LiveUiSurfaceCapabilities get surfaces => windSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => WindHostBuilder.build(context, spec);
  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => WindShellBuilder.build(context, spec);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => WindButtonBuilder.build(context, spec);
  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => WindCardBuilder.build(context, spec);
  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => WindTextFieldBuilder.build(context, spec);
  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => WindSwitchBuilder.build(context, spec);
  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => WindCheckboxBuilder.build(context, spec);
  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => WindSliderBuilder.build(context, spec);
  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => WindSegmentedBuilder.build(context, spec);
  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => WindProgressBuilder.build(context, spec);
  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => WindSelectBuilder.build<T>(context, spec);
  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => WindTabBarBuilder.build(context, spec);
  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => WindScaffoldBuilder.build(context, spec);
  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => WindAppBarBuilder.build(context, spec);
  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => WindListRowBuilder.build(context, spec);
  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => WindNavBarBuilder.build(context, spec);
  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => WindToastBuilder.build(context, spec);
  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => WindDialogBuilder.build(context, spec);
  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) => WindTabViewBuilder.build(context, spec);
}
```

### Realized mapping

The table reports what each builder is — a mapping onto one library widget, or a composition of that
library's parts — and where the library does not express a spec field, that is what the third column
says.

| Control | Wind implementation | Notable unmapped spec fields |
|---|---|---|
| `appHost` | Composed: Flutter's `WidgetsApp.router` with the library's own `WindTheme` scope installed above the routed tree | nothing: the router config, the title and its generator, the delegates, the locales, the forced locale, the `builder` and the banner flag all pass through to `WidgetsApp`, and the single colour it insists on is the token's accent; the theme decision itself belongs to `wrap` (§8) |
| `shell` | Composed: a `Row` of this package's anchors over the library's surface in the rail form; in the bottom form the strip is this adapter's own `navBar` | `trailing` is dropped in the bottom form, because the strip it delegates to has no footer slot; the glyph step is the library's own `text-lg` class token |
| `button` | `wind.WButton` | `focusNode`/`autofocus` (`WButton` owns its focus handling inside `WAnchor`), `selected` (no selected affordance is applied to it), `style` (its surface is the library's own); `iconOnly` is carried — the composed label returns the bare glyph with the tooltip as its semantic name |
| `card` | Mapped: `wind.WCard` supplies the structure, a token-painted `DecoratedBox` the surface | `focusNode`/`autofocus` (the tap layer is a plain gesture detector), and `style` beyond `background` and `borderRadius` |
| `textField` | `wind.WInput`, with the error caption drawn beneath it in this package's own caption style | `style` (`WInput` has no `TextStyle` slot); keyboard type and `obscure` collapse onto one `InputType`; `controller`, `focusNode`, `placeholder`, `enabled`, `readOnly`, `maxLines`, `textInputAction`, `prefix` and `suffix` all pass through |
| `switchWidget` | `wind.WSwitch` | `focusNode`/`autofocus` have no slot; value, callback and disabled flag come straight from the spec |
| `checkbox` | `wind.WCheckbox`, its optional trailing label laid out by this package's own label row | `focusNode`/`autofocus` have no slot; the fork's checkbox paints no label, so the label here is this library's own `Text` beside the box |
| `slider` | Composed: the library's own rail and thumb drawn as two `WDiv` surfaces, measured with a `LayoutBuilder` and dragged through a gesture detector; the fork has no slider | `focusNode` — the fork keeps focus inside `WAnchor`, exactly as on the button |
| `segmented` | Composed: the library's own button, one per segment; the fork has no segmented picker | — |
| `progress` | Composed: the library's own rail and run, two `WDiv` surfaces, the filled share taken by a `FractionallySizedBox`; the fork has no progress bar | an indeterminate run breathes rather than travelling (the library has no transform parser), and with it `showLabel` is dropped, because there is no percentage of an unknown quantity to print |
| `select` | `wind.WSelect<T>` | the menu surface, item states and scroll physics belong to the library; `style` and a token border have no slot on the overlay it mounts |
| `tabBar` | Composed: this package's strip of `WAnchor` tabs over a rule-drawn `WDiv` — the library's `WTabs` welds a strip to a content panel, which is not what `LanguageTabsSpec` asks for | `spacing` — the strip keeps the library's own tab padding; the underline style is fixed |
| `scaffold` | Composed: the library's full-size flex column, with the dispatched bar as its first child, the body as its `Expanded` share, the bottom bar last, and the action placed over it | nothing: `background` arrives through the container's inline colour hook, `avoidKeyboard` through the view insets, `extendBodyBehindAppBar` as a stack, and the bars are the already-dispatched controls |
| `appBar` | Composed: the library's panel with its header hairline — title `WText` at `text-lg font-semibold`, the leading widget and actions in the row, an optional dispatched strip beneath it | nothing: `height` goes to a `SizedBox`, `background` to the inline colour hook, `centerTitle` to `text-center` on a title that takes the leftover width |
| `listRow` | Composed: a `WAnchor` over the library's container, with its hover fill and the secondary line at the library's grey step; selection is a fill one step above the hover plus a reserved accent bar recoloured only on the chosen row | `focusNode`/`autofocus` — the fork creates and tracks the node inside `WAnchor`, as on the button |
| `navBar` | Composed: the library's bottom strip — a bordered `WDiv` of equal-share `WAnchor` cells, each `WIcon` over `WText`, the chosen one taking the accent | nothing; the bar's height comes from the layout environment and the glyph step stays the library's `text-lg` class token |
| `toast` | Composed: a `WCard` pill — the library's `rounded-2xl shadow-lg border` elevated surface — carrying a leading `WIcon` and the message in `WText` | `duration` is not read here: the overlay, the animation and the timer are the core's `LiveToast.show`, which also decides placement |
| `dialog` | Composed: a `WCard` panel — the library's elevated pair with `rounded-xl shadow-xl border` — inside core's `showLiveDialog` barrier; the dispatched actions are right-aligned and nothing else is said about them | `dismissible`, which is the barrier's knob and belongs to core; only the surface lives here |
| `tabView` | Composed: Flutter's `PageView` inside the library's own full-size column, reporting the page a swipe landed on so the strip can follow it | `duration` is clamped rather than thrown at, because strip and view are driven separately |

### Adapter identifier

Use one stable machine-readable identifier everywhere:

```text
wind
```

It is the value used by the registry, persistence, and diagnostics — never a localized label. Do not use `fluttersdk_wind`, `Wind UI`, or a platform-dependent value as the runtime style id. `windAdapterId`, `WindLanguageAdapter.id`, and `LiveDesignLanguage.wind.name` all resolve to `wind`.

### Capability declaration

`windCapabilities` is a *declaration of fact* — it lists precisely the controls `WindLanguageAdapter`
implements, whether the library has a widget for the job or the builder composes one out of its parts:

```dart
const LiveUiCapabilities windCapabilities = LiveUiCapabilities(<LiveUiControl>{
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

const LiveUiSurfaceCapabilities windSurfaces =
    LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
```

That is the whole contract: all seventeen `LiveUiControl` values, and both `LiveUiSurface` values.
A declared control whose builder is missing is a broken adapter — `requireControl` throws
`LiveUiCapabilityException` rather than drawing something the caller did not ask for — so the
declaration, the seventeen overrides, and the two surface overrides have to agree.
`wind_contract_test.dart` asserts that the capability set lists exactly the controls the adapter
overrides, and that the surfaces list names both of them, so drift between declaration and
implementation is caught before it ships (§17). The only downgrade left anywhere in the system is an
effect the device cannot afford: when the configuration asks for transparency and the hardware cannot
do the blur, `LiveConfigProvider` reports `unsupportedEffect` once and a verified flat visual stands
in. That is the single member of `LiveUiDiagnosticCode` (§15), and Wind declares no effect set of its
own.

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

Through `wrap`, the adapter installs only a Wind theme scope around the widgets it builds, via `WindThemeScope`; the theme-scope mechanism (`wind.WindTheme`) is the whole of it. `wrap` adds no application widget — nesting a second app inside a subtree would hand the page competing navigation and configuration. The single `WidgetsApp` a Wind tree has is the one its `appHost` surface builds (§7), and that host puts the theme scope above its own routed tree so a route's overlay content still resolves the library's maps.

### 8.3 Runtime updates

When the user changes brightness, accent, font, density, or style:

1. The application updates `UiConfig`.
2. `LiveConfigProvider` re-derives the `DesignToken`.
3. `WindThemeBuilder.build(token)` produces fresh `WindThemeData` on rebuild.
4. The Wind scope rebuilds; business state remains owned by the business widgets.

Do not cache a `WindThemeData` object permanently while its source token can change.

## 9. Control implementation rules

Each builder turns a core `Language*Spec` into `fluttersdk_wind`'s own widget where the library has one for the job, and into a composition of that library's parts where it does not. Builders must map semantic intent, not inspect business page types — a button builder may read `spec.variant`, but must not special-case login, playback, or plugin screens.

### Button (`WindButtonBuilder.build`)

- Builds a `wind.WButton`; the press is wired only when the spec is interactive (enabled, not loading, has `onPressed`).
- Builds the button's content from this library's own parts — the label, an optional leading glyph, the loading state, and the bare glyph of an icon-only button whose empty label is never painted. The fork's own `isLoading` spinner stays off: the language composes one, and two spinners in one button is a defect.
- `disabled` is set from that same verdict — enabled, not loading, a callback present — so the state the fork paints can never disagree with the callback it has.
- Padding is token-driven (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`).
- `expand` becomes the fork's own `w-full` class; `tooltip` wraps the button in a `Tooltip` and is also passed as `semanticLabel`, so an icon-only button keeps an accessible name.
- `focusNode` and `autofocus` are **not expressible on this control**: `WAnchor` creates and tracks its own focus node, and wrapping the button in a second `Focus` would take the focus that actually handles activation. They are recorded here as unmappable spec fields (§15) rather than faked. If Wind ever exposes a focus hook, wire both and delete this note.
- `iconOnly` needs no special case: the builder's own label routine returns the glyph alone, with the
  tooltip as its `semanticLabel`, so a textless button built by `LiveIconButton` arrives here already
  correct.
- `selected` is **not mapped by this builder today**. Its button is the library's own widget and paints
  its own surface, so reproducing a toggled look needs this library's selected affordance rather than a
  hand-painted overlay on top of it. Recorded as the documented remainder of `docs/decisions/0004` (§15).
- `style` is **not mapped by this builder either**, for the same reason: applying a caller's `Style` to
  the library's button would mean hand-painting an overlay over a widget that already paints itself. The
  trade §9 refuses for `selected` is the trade refused here.

### Card (`WindCardBuilder.build`)

- `wind.WCard` is the fork's card *structure* — a `w-full flex flex-col` body with header/footer slots rendered through `WDiv` — and it paints no surface of its own. The surface (fill, radius, border) therefore comes from the resolved token, which is what every other path in this package paints from (§8.1).
- Preserve `child`, `padding`, `selected`, `bordered` and `dense`; `dense` tightens the token padding by the same factor the rest of this package uses, so the density step means the same thing in both paths.
- Read the `style` override only for what a Wind surface can express (`background`, `borderRadius`); a `className` is not passed, because in this fork `className` *replaces* the card's base classes rather than adding to them.
- Wire `onTap`/`onLongPress` through a gesture layer only when supplied, and stretch the body to the card's width: the fork sizes a flex body to its content, so without the stretch an interactive card is tappable only behind its own text while the surface paints full width.

### Text field (`WindTextFieldBuilder.build`)

- Build a `wind.WInput`, passing `controller`, `focusNode`, `placeholder`, `enabled`, `readOnly`, `maxLines`, `textInputAction`, `prefix`, `suffix`, `onChanged` and `onSubmitted` through untouched. When `controller` is null the field owns one; the adapter must not create a second.
- The fork expresses keyboard type and obscuring through a single `InputType`, so the spec's `obscure` and `keyboardType` collapse into one intent here — `obscure` wins, then email/number keyboards, then the line count (`multiline` above one line). `keyboardType` values the fork cannot name degrade to the fork's default rather than being faked with a formatter.
- `errorText` has no slot in the fork: mark the input with the fork's `error` state and draw the message below it in the caption style this package composes elsewhere, so an error looks the same in both paths (§2.3).
- The inline `Style` is **not mapped by this builder**: `WInput` exposes no `TextStyle` slot — its visuals are driven by theme `className` presets — and hand-painting a style over the fork's field is the overlay the §8.1 rules out. Recorded here as the documented remainder, as with `selected`/`style` on the button (§9 Button).

### Switch (`WindSwitchBuilder.build`)

- Builds a `wind.WSwitch(value:, onChanged:, disabled:)` — fully controlled.
- `onChanged` is passed only when `spec.enabled`, and the `disabled` flag follows the resolved callback, so a null `onChanged` disables the switch exactly as `enabled: false` does instead of leaving a live-looking control that does nothing.
- No local persistent state; the value lives with the caller.

### Checkbox (`WindCheckboxBuilder.build`)

- Builds a `wind.WCheckbox(value:, onChanged:, disabled:)` and lays the optional trailing label beside it with this library's own text role, because the fork's checkbox draws no label of its own.
- Preserves the checked/unchecked value, the disabled flag, and the callback semantics: the label is rendered beside the box but is not itself a hit target.

### Select (`WindSelectBuilder.build`)

- Builds a `wind.WSelect<T>` from the typed spec: each `spec.items` entry becomes one `wind.SelectOption<T>` whose label is `spec.itemLabel(item)`, and `WSelect` hands the chosen value back unchanged, so the caller's own item type survives the swap — the same property `live-uikit-fluent.md` §7 records for Fluent's `ComboBox<T>`. Wind is the second adapter in the family to render `select` natively.
- A null `onChanged` or `enabled: false` sets the fork's `disabled` flag and passes no `onChange`, so the trigger greys out and the menu never opens, rather than staying openable but reporting nothing.
- `placeholder` maps to the fork's own trigger text; the spec has no search, pagination, tagging, or multi-select fields, so none of those is enabled.
- The trigger and menu keep the fork's `className` styling: `WSelect` has no slot for the resolved `Style` or a token border on the overlay it mounts, and painting one over the fork's surface is the overlay §8.1 rules out (recorded as a documented remainder, like `selected`/`style` on the button above).

### Slider (`WindSliderBuilder.build`)

Composed, not mapped: `fluttersdk_wind` ships no slider. The rail, the filled run and the thumb are
three `WDiv` surfaces of the library — `bg-primary-500` for the run, the `bg-gray-200 dark:bg-gray-700`
pair for the rest, `rounded-full`, `border` and `shadow` out of `WindThemeData`'s maps — in the
rail-plus-thumb shape `WSwitch` documents for its own thumb. Two jobs fall outside the fork and are
answered at the widgets layer: the fraction, because `w-*` and `basis-*` are compile-time class tokens
and the library warns against interpolating a runtime value into a className, so the fill width and the
thumb offset come from a measured rail and are applied with `Positioned`; and the drag, because
`WAnchor` is the library's only interaction widget and offers tap, long-press and double-tap, so the
drag sits on a `GestureDetector` over the parts and a tap positions the value the same way.
`LanguageSliderSpec.focusNode` has no slot here, for the reason this section records for the button.

### Segmented (`WindSegmentedBuilder.build`)

Composed, not mapped: the fork has no segmented track, and its own answer to "one choice out of a row"
is a row of `WButton`s plus the `selected:` state prefix — the mechanism `WTabs` uses to mark its active
tab. So the track is one of the library's buttons per segment, the chosen one carrying
`selected:bg-primary-500 selected:text-white` through the library's state pipeline. The fill rather than
an underline is what separates a segment from a tab here, and it settles the tint question too:
`WindThemeBuilder` seeds Wind's `primary` scale as one flat accent (§8.1), so Wind's neutral pair carries
the hover and the accent carries the choice. `expand` gives every segment an equal share by wrapping each
button in `Expanded` with `w-full` on it, because `WButton` reads only its own width classes. An empty
group is the fork's inert state — `disabled: true` with no `onTap` — so `disabled:opacity-50` activates.

### Progress (`WindProgressBuilder.build`)

Composed, not mapped: the fork ships no progress bar. Both halves are the library's own container — a
`WDiv` rail in its neutral pair and a `WDiv` run in its accent, closed by `rounded-full` and
`overflow-hidden` so the run is clipped to the rail's radius — with `height` taken by a `SizedBox` and
the fraction by a `FractionallySizedBox`, which is how `WDiv` renders its own `w-1/2` token.
`barColor` is a runtime value, so it arrives through the fork's `WDiv.backgroundColor` hook rather than a
className. An unknown completion cannot slide: `WSwitch` records that Wind has no transform parser, so
`value: null` paints the full-width rail breathing with `animate-pulse`, the library's documented
skeleton affordance, and `showLabel` is dropped with it because there is no percentage of an unknown
quantity to print.

### Tab bar (`WindTabBarBuilder.build`)

Composed, not mapped. The fork does have `WTabs`, but it is a *tab view*: `panelBuilder` is required and
the widget renders the panel under the strip, it paints a `WText` per tab and nothing else, so a caller
who already has the body gets an empty panel and `LiveTab.icon` has nowhere to go. The strip here is made
of the parts `WTabs` itself is made of: a `WAnchor` per tab over a `WDiv`, the active one carrying the
library's own `selected:` tokens, on a rule-drawn list, with the underline reserved on every tab
(`border-b-2 border-transparent`) so choosing one moves nothing. `spacing` is a knob of the core's own
laying-out and the strip uses the library's tab padding instead.

### Scaffold, app bar, list row, nav bar (`WindScaffoldBuilder` / `WindAppBarBuilder` / `WindListRowBuilder` / `WindNavBarBuilder`)

All four are composed, because the fork is a styling library and ships no frame, no bar, no row and no
navigation widget. The page frame is a `WDiv` of `flex flex-col w-full h-full` on the library's canvas
pair, with the dispatched app bar and bottom bar as its first and last children and the body taking the
remaining height through `Expanded`, the flex share the fork's own column composer gives a `flex-1`
child; `background` arrives through the container's inline `backgroundColor` hook, `avoidKeyboard` is
answered with the view insets, and the floating action button is placed by the core's page padding. The
top bar is a panel in the library's `bg-white dark:bg-gray-900` pair closed by the
`border-b border-gray-200 dark:border-gray-700` hairline, title at the library's `text-lg font-semibold`
step, actions appended as the widgets the caller dispatched, and a dispatched `bottom` strip stacking
under the row in the same panel. The list row is the interactive `WAnchor` the library's own `WTabs`,
`WSwitch` and `WCheckbox` are built on, flexed and toned in the fork's vocabulary, with selection taking
the two marks Wind gives a chosen row: a fill one step above the hover fill and an accent bar reserved on
every row. The destination strip is the same container doing a bar's job, one `WAnchor` column of `WIcon`
over `WText` per destination, the chosen one on the fork's `selected:` accent.

### Toast, dialog, tab view (`WindToastBuilder` / `WindDialogBuilder` / `WindTabViewBuilder`)

The toast is a surface only: the fork has no transient message widget, and the overlay it is placed in,
the animation and the dismissal timer belong to `LiveToast.show`, which is why `duration` is not read
here. The pill is `WCard` — the library's surface container — with `rounded-2xl shadow-lg border` and its
elevated pair, the message in `WText` at the library's `text-sm` step, and the status glyph coloured from
the token through the fork's runtime-colour channel. The dialog is the same problem one size up: 1.8.4
ships no dialog, no modal and no overlay host, and the one floating panel it has, `WPopover`, is anchored
rather than centred, so the surface is a `WCard` carrying `rounded-xl shadow-xl border` over the
library's elevated pair while the route, the barrier, the fade-and-scale and the dismissal stay with
core's `showLiveDialog`; the actions are dispatched controls already, so right-aligning them is the only
thing the language says about them. The tab view is Flutter's own `PageView` from
`package:flutter/widgets.dart` — the library has no page frame, no `Pivot`, no swipe gesture to take —
inside the library's full-size column container, with a swipe wired so `onIndexChanged` can move the
strip; with no callback, or with a single page, the pages stay inert.

## 10. Runtime registration

The application composition root registers the adapter during startup. Wind exposes a const instance and a factory so the root can pick either:

```dart
// Using the exported API.
// `LanguageRegistry` is immutable: the adapters are supplied as a map at construction.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.wind: windAdapter},   // or createWindAdapter()
);
```

The core `LanguageRegistry` maps `LiveDesignLanguage → LanguageAdapter` and takes nothing else: a
language with no adapter in it is a build that does not support that language.

```dart
const LanguageRegistry(adapters: {LiveDesignLanguage.wind: windAdapter});
```

The composition root, not the adapter, is responsible for: registering the adapters included in the build, loading the user's style preference, selecting the active language, providing configuration persistence, and coordinating runtime theme changes. `live_uikit_wind` must not register itself through global static initializers or require the business layer to import it.

### Resolution behavior

The core `LiveUiResolver` is the single decision point. For Wind:

- A registered language resolves to its own adapter (`WindLanguageAdapter`), and `LiveUiResolver.resolve`
  returns it.
- Every control of the contract is declared, so a declared control resolves to the adapter's own
  implementation with no diagnostic; `requireControl` throws `LiveUiCapabilityException` if a declared
  control ever lacks the override its declaration claims.
- The two surfaces are declared the same way, and `requireSurface` throws the same exception for a
  surface named without an implementation behind it.
- If Wind were not registered at all, resolution fails with `LiveUiResolutionException`. A Wind control
  has nowhere else to go: the app registers the languages it means to ship.

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
```

Switching from Wind to another style changes rendering and interaction presentation only. It must not replace business controllers, reset form values, or recreate unrelated services. Wind implements all seventeen controls and both surfaces, so switching *into* Wind moves the whole page at once — the frame, the bars, the strip, the surfaces of the dialogs and toasts change together with the buttons, cards, text fields, switches, checkboxes and the select trigger. The caller-owned `TextEditingController` and the caller-owned select value are the state that must survive the shift untouched (§9).

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile, so the Wind adapter must be tested for more than mouse input.

Wind is Windows-flavoured, which makes keyboard-driven desktop the natural first-class context: Tab/shift-Tab traversal, visible focus indication, and Enter/Space activation should be verified against the fork's own `WButton`/`WSwitch`/`WCheckbox` and against the anchored parts this package composes, because every control of the contract is built here rather than handed to another language. The `Language*Spec` objects carry `focusNode` and `autofocus` (button, card, switch, checkbox, slider, text field and list row all do). The text field is the one control whose node the fork accepts, and `WindTextFieldBuilder` passes it straight through; everywhere else the fork creates and tracks the node inside `WAnchor`, so the spec's node has no slot to land on and §9 records it as unexpressible instead of wrapping the control in a second `Focus` that would steal activation. `WSelect` likewise owns its node internally and the select spec carries no `focusNode` field, so keyboard activation on the select stays entirely the fork's (§9).

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

An effect the Wind library cannot express on a given platform is reported as `unsupportedEffect` and the control still draws — it is the effect that is dropped, never the control. Native window APIs must not become a required dependency of the basic adapter. Cross-platform parity concerns and Fluent's platform matrix are covered in `live-uikit-fluent.md`.

## 14. Localization and accessibility

Wind adds **no localization delegates** of its own. Localization is provided entirely by the core `live_uikit` setup and the application composition root, and `live_uikit_wind` intentionally exports none.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings (labels come through the `Language*Spec` objects).
- Preserve semantic labels and hints on the controls it builds.
- Not introduce a second, conflicting locale source or override the global locale.
- Test long translated labels and right-to-left layouts on the controls this package builds, mapped and composed alike.
- Verify focus visibility, text contrast, and touch target sizing.

## 15. Error handling and diagnostics

Diagnostics use the core contracts only — `LiveUiDiagnostic`, the `LiveUiDiagnosticCode` enum, and the host-supplied `LiveUiDiagnosticSink`. Wind does not depend on Talker or any concrete logging package.

The one code Wind can hit:

| Code | When Wind hits it |
|---|---|
| `unsupportedEffect` | The environment cannot afford a Wind visual effect; a verified degraded visual stands in |

Two failures are exceptions rather than codes, because neither has anything sensible to draw:
`LiveUiResolutionException` when Wind is selected but no adapter was registered for it, and
`LiveUiCapabilityException` when a capability or surface is declared without the override that
declaration claims. Wind declares all seventeen controls and both surfaces and implements all of them,
so a control of a Wind page is never a downgrade reported through a diagnostic: either the library's own
widget or composition draws it, or the app is misconfigured and says so.

Expected behavior:

- A dropped effect is reported and the control still draws; nothing blanks.
- Programming errors are not swallowed.
- Diagnostics avoid logging user-entered text, credentials, or sensitive content.

## 16. Testing strategy

### Unit / contract tests (`test/adapter/wind_contract_test.dart`)

- Stable id (`wind`), display name (`Wind`), and language (`LiveDesignLanguage.wind`).
- The capability set lists exactly the controls the adapter implements — all seventeen
  `LiveUiControl` values — and the test derives the complement from `LiveUiControl.values` rather than
  listing it, so a control added to the contract cannot join an undeclared side silently; the same
  comparison is enforced by `tool/check_architecture.ps1` (§17), so the declaration and the overrides
  cannot drift apart silently.
- Both structural surfaces are declared: `{appHost, appShell}`, and nothing else is claimed.
- Through `LiveUiResolver` over a `LanguageRegistry`: a registered Wind resolves to this adapter, every
  control of the contract passes `requireControl`, and a language this build did not register raises
  `LiveUiResolutionException` instead of degrading.
- Theme mapping (`test/theme/wind_theme_test.dart`): `isDark` → `WindThemeData.brightness`
  with `syncWithSystem` forced off, the token accent landing in Wind's `primary` swatch,
  and a configured global family reaching `fontFamilies['sans']`.

### Widget tests (`test/widgets/wind_native_controls_test.dart`)

- Button: `onPressed` fires when enabled, input is rejected while loading, that same interactivity
  verdict is also the visual state the fork paints, `expand` and `tooltip` are preserved,
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
- The controls this package composes rather than maps: a rail is the fork's own parts and reports the
  position it is tapped at, an inert rail has neither a gesture nor a live-looking thumb; a segmented
  track is a group of Wind buttons with one carrying the selected state; a determinate bar is the fork's
  rail and run with the percentage as its label, an unknown completion breathes and prints no percent; a
  tab strip is the fork's anchors over its rule, carries its icons and reports its index; a page frame is
  a Wind column of bar, body, bottom bar and a placed action; a top bar is a Wind panel with its title,
  actions and strip; a list row anchors its parts, fires its tap and can rule itself off; a destination
  strip shares its width, reports its index and stops when disabled; a toast surface is a Wind panel.
- The dialog surface and the page switcher: a dialog is a Wind panel while the route stays the core's, and
  the switcher is a `PageView` in a Wind frame that reports its swipes.
- The whole chrome set: no foreign widget appears inside a Wind frame, the app shell's rail form is the
  composed column (with a disabled destination inert, a bottom request handed back through `navBar`, and
  an adaptive request bending at the same width as every other language), and the tree is hosted by
  `WidgetsApp` under the Wind theme.

Not yet covered: keyboard and remote activation — no test drives a key event or a D-pad through the
fork's own focus handling — and accessibility semantics, which no test asserts on a semantics node yet.
These are the §19 lines that still ask for hardware.

### Integration tests (`test/integration/wind_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: all seventeen of them belong to this adapter, the set is
  compared against the declaration control by control, and `requireControl` accepts each without a
  diagnostic.
- A mixed subtree renders `wind.WInput`/`WCard`/`WSwitch`/`WSelect` natively and no Material text field
  at all; the slider rail and the progress run are the fork's own `WDiv` parts rather than another
  language's widgets. Re-rendering the same page in Wind replaces the rendering path with the caller's
  `TextEditingController` text and select value intact.
- While Wind is active the sink sees no control or surface entry at all: every control is implemented and
  both surfaces are owned, so there is nothing left to report (§15).

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
- The declared `windCapabilities` set matches the methods `WindLanguageAdapter` actually overrides (the contract test enforces this).
- Every `package:fluttersdk_wind/` import inside this package uses the `as wind` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `windCapabilities`: a control named in
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

Wind ships all seventeen contract controls and both structural surfaces, over a theme bridge that
carries the resolved token into the library's own maps. The phases below first hardened the mapped
controls, then took the ones the library has no widget for in hand, composing them from its parts.

### Phase 1 — Contracts and registration ✅

- `WindLanguageAdapter` implements the finalized core contract directly: `LanguageAdapter` is an
  `abstract interface class`, there is nothing to extend, and the id, the capabilities, the surfaces,
  `wrap` and every builder are written here.
- Stable id `wind`, display name `Wind`, `LiveDesignLanguage.wind` language.
- `windAdapter`, `createWindAdapter()`, `windAdapterId` registration API; barrel exports only the registration.
- `wind_contract_test.dart` covers id/capabilities/resolver behavior.

### Phase 2 — Theme integration foundation ✅

- Brightness, the accent as Wind's `primary` swatch, and a configured global font are mapped in `WindThemeBuilder`; `syncWithSystem` is forced off because the core owns the brightness decision (§8.3).
- `test/theme/wind_theme_test.dart` asserts the mapping and drives a runtime re-skin through `LiveConfigProvider` → resolver → `wrap`.
- Wind's Tailwind colour/space/typography maps stay at their defaults — keys the token cannot name are left alone rather than half-mapped (§8.1).

### Phase 3 — Harden the current native controls ✅

- Button: padding from the token, `expand` through `w-full`, `tooltip` through a `Tooltip` wrapper and `semanticLabel`, `disabled` from the same interactivity verdict that nulls the callback. `focusNode`/`autofocus` are recorded in §9 as fields `WAnchor` cannot accept — that is the one item this phase could not close.
- Switch and checkbox are fully controlled, and a null callback now drives the fork's `disabled` flag as well as the callback.
- `test/widgets/wind_native_controls_test.dart` covers all three.

### Phase 4 — First high-value native surfaces ✅

- `WindCardBuilder` and `WindTextFieldBuilder` added, overriding `card` and `textField`.
- Both are declared in `windCapabilities`, and `wind_contract_test.dart` moved them into the native set in the same change (§17 drift gate).
- The card takes its surface from the token because `WCard` paints none; the field collapses `obscure`/`keyboardType`/`maxLines` into the fork's single `InputType` and draws `errorText` in the caption style this package uses for its own secondary text (§9).

### Phase 5 — Remaining controls ✅

- `WindSelectBuilder` added, overriding `select` with `wind.WSelect<T>` (§9): the typed items map to `SelectOption`s, a null or disabled spec disables the fork, and the contract test's native set moved `select` in the same change (§17 drift gate).
- Slider, segmented, progress and tab bar were then composed rather than left unimplemented: `fluttersdk_wind` offers no `WSlider`, `WProgress`, or bare tab strip (`WTabs` couples the row to a content panel `LanguageTabsSpec` does not carry), so each is assembled from the library's own `WDiv`, `WAnchor`, `WButton` and `WText` parts, coloured from its Tailwind maps and driven through its state prefixes (§9).
- Scaffold, app bar, list row, nav bar, toast, dialog and tab view completed the same way, and `appHost` and `shell` took the two structural surfaces — Flutter's `WidgetsApp` under the library's theme scope, and a navigation column of the same parts, handing its bottom form back through `navBar`.
- Every change to what this adapter implements updates `windCapabilities` and the contract test's
  declared set in lockstep, so the declaration keeps naming all seventeen controls.

### Phase 6 — Interaction, icons, and accessibility

- Introduce `interaction/` for keyboard/focus/TV mapping over the now complete control surface. This is where the §9 focus gap has to be answered: either by the library exposing a focus hook or by a documented, tested traversal policy.
- Introduce `icons/` for semantic icon mapping where Wind supports it.
- Validate focus traversal, D-pad behavior, and accessibility semantics on all native controls.

### Phase 7 — Production readiness ◐

- Integration tests for runtime style switching (Wind in and out) landed in `test/integration/wind_style_switching_test.dart`. The switching contract is asserted per package: every control of the contract resolves to this adapter, a Wind subtree contains no foreign widget, the caller's controller text survives the re-render, and the diagnostic sink stays empty (§16). An app-level test that swaps Wind with another adapter belongs to the application, since §3.3 forbids adapter-to-adapter dependencies.
- Architectural CI checks (§17) — done: `tool/check_architecture.ps1` enforces the library boundary, the `wind` import prefix, the registration-only barrel, and the capability/override match.
- Verify all claimed platforms with real tests.
- Document known limitations and `fluttersdk_wind` upgrade compatibility: today they are the fields the fork's anchors take no node for — `focusNode`/`autofocus` on the button, card, list row and slider (§9) — the `keyboardType`/`obscure` collapse onto the fork's single `InputType` (§9), and the fields core keeps to itself: `duration` on the toast, `dismissible` on the dialog, and `trailing` in the shell's bottom form.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `fluttersdk_wind` only for its core integration.
- [x] It implements `LanguageAdapter` directly — an `abstract interface class` with nothing to extend — including all seventeen control builders and both structural surfaces.
- [x] It uses the stable adapter id `wind` (with `windAdapterId`, `windAdapter`, `createWindAdapter()`).
- [x] `windCapabilities` declares every control of the contract (`button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`, `select`, `tabBar`, `scaffold`, `appBar`, `listRow`, `navBar`, `toast`, `dialog`, `tabView`) and `windSurfaces` declares both surfaces, and the adapter implements each of them.
- [x] The eleven controls `fluttersdk_wind` has no widget for are composed here from its own parts, so a Wind page contains no widget from another implementation path (§7/§9).
- [x] The barrel exports only the registration API; no builders, mappers, or `fluttersdk_wind` types leak (§17 guards this in CI).
- [x] It maps the resolved `DesignToken` into `WindThemeData` and installs a Wind theme scope — brightness with `syncWithSystem` off, the accent as Wind's `primary` swatch, and a configured global family in `fontFamilies['sans']` (§8.1).
- [x] It adds no localization delegates and relies on core localization.
- [x] It does not depend on `live_uikit_fluent` or any other style adapter.
- [x] It does not own business state, persistence, or a nested app shell.
- [x] Native controls preserve value/callback/controller semantics and pass fully controlled state through — `focusNode`/`autofocus` excepted on the button, card, list row and slider, where `WAnchor` owns the node, and on the switch and checkbox, whose builders take only the value, the callback and the disabled flag; the text field is the one control whose node the fork accepts. §9 records those as unexpressible and a test asserts it rather than leaving it to memory.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested for the native controls — nothing in the suite drives a key event or a semantics node yet (§16), and D-pad behavior needs hardware.
- [x] Diagnostics use the core contract (`LiveUiDiagnostic`, `LiveUiDiagnosticSink`): the package defines no channel of its own, and the one downgrade it can report arrives as `unsupportedEffect`.
- [x] The contract test keeps `windCapabilities` and `windSurfaces` in sync with the overrides (§17).
- [x] Tests and static analysis pass (`flutter test`, `flutter analyze`: no issues).
- [ ] Platform support claims are backed by real tests — Windows desktop, a mobile target and Android TV still need their runtimes (§16 Platform verification).

## 20. Final architecture decision

`live_uikit_wind` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, the `DesignToken` theme model, runtime selection (`LiveUiResolver` + `LanguageRegistry`), the capability model, and the diagnostic policy.
- `live_uikit_wind` maps those contracts to `fluttersdk_wind`, for every control of the contract and both structural surfaces.
- `fluttersdk_wind` supplies the underlying Wind widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

Wind answers the whole contract from its own library, and that is the point rather than a milestone: a control is either the library's widget or a composition of the library's parts, never a stand-in drawn by another implementation, so a Wind page has no foreign bar, rail, dialog or field in it. `windCapabilities` and `windSurfaces` keep tracking that fact, and the resolver raises when a declaration and an implementation disagree. This separation lets PureLive add or replace UI styles — including growing Wind — without forcing business packages to know which library is currently rendering their controls.
