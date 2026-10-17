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
7. **Full coverage of the contract.** All seventeen controls and both structural surfaces are answered by this package — with a `macos_ui` widget where the library has one, and with that library's own parts where it does not. `LanguageAdapter` is an interface with nothing underneath it, so a member this package does not implement is a `LiveUiCapabilityException` at the resolver rather than a control that quietly arrives from somewhere else.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- macOS theme mapping from the resolved `DesignToken` into a `macos_ui` theme and scope.
- macOS widget construction for all seventeen controls, each in its own builder under `widgets/`.
- The two structural surfaces: the application host, which is `MacosApp`, and the shell's sidebar navigation.
- macOS-specific control defaults.
- Focus and keyboard interaction behavior for the controls whose spec fields `macos_ui` can actually take.
- Mapping the neutral control specifications onto `macos_ui` controls, and composing the six shapes the library has no widget for out of that library's own parts.
- Reporting implemented capabilities to the core registry through `macosCapabilities`, and owned surfaces through `macosSurfaces`.
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
| `live_uikit_cupertino` | No | Adapters must remain independent |
| `live_uikit_material` | No | Adapters must remain independent |
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
    │       │   ├── macos_adapter.dart
    │       │   ├── macos_capabilities.dart
    │       │   ├── macos_registration.dart
    │       │   └── macos_surfaces.dart
    │       ├── theme/
    │       │   ├── macos_theme_builder.dart
    │       │   ├── macos_theme_mapper.dart
    │       │   └── macos_theme_scope.dart
    │       └── widgets/
    │           ├── macos_app_bar_builder.dart
    │           ├── macos_button_builder.dart
    │           ├── macos_card_builder.dart
    │           ├── macos_checkbox_builder.dart
    │           ├── macos_dialog_builder.dart
    │           ├── macos_host_builder.dart
    │           ├── macos_list_row_builder.dart
    │           ├── macos_nav_bar_builder.dart
    │           ├── macos_progress_builder.dart
    │           ├── macos_scaffold_builder.dart
    │           ├── macos_segmented_builder.dart
    │           ├── macos_select_builder.dart
    │           ├── macos_shell_builder.dart
    │           ├── macos_slider_builder.dart
    │           ├── macos_switch_builder.dart
    │           ├── macos_tab_bar_builder.dart
    │           ├── macos_tab_view_builder.dart
    │           ├── macos_text_field_builder.dart
    │           └── macos_toast_builder.dart
    ├── live-uikit-macos.md
    └── test/
        ├── adapter/
        │   └── macos_contract_test.dart
        ├── theme/
        │   └── macos_theme_test.dart
        ├── widgets/
        │   ├── macos_native_controls_test.dart
        │   └── stub_router.dart
        └── integration/
            └── macos_style_switching_test.dart
```

Note the naming conventions in this package: both the theme modules and the adapter modules are prefixed `macos_`, and every builder is named `macos_<control>_builder.dart`. The two structural surfaces sit in `widgets/` beside the controls (`macos_host_builder.dart`, `macos_shell_builder.dart`) because they are dispatched the same way — through the adapter — even though `LiveUiSurface` keeps them in their own declaration. There is exactly one builder per control of the contract, plus one each for the app host and the shell, and that is what keeps §7's table and §9's prose aligned with the tree: the guard in §17 compares `macosCapabilities` and `macosSurfaces` against the methods `MacosLanguageAdapter` actually overrides, so a builder that is never dispatched — or an override with no declaration behind it — fails the build rather than drifting quietly.

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
| `adapter/` | Adapter contract implementation, capability and surface declaration, registration |
| `theme/` | Translate the resolved `DesignToken` into `macos_ui` theme values and scope |
| `widgets/` | Build every control of the contract from the core specifications, and the app host and the shell: one `macos_ui` widget where the library has one, its own parts composed where it does not |
| `interaction/` | Map keyboard, focus, and TV-specific behavior (optional, not yet created) |
| `icons/` | Map supported semantic icons to `macos_ui` icons (optional, not yet created) |
| `diagnostics/` | Report effect degradations and adapter errors (optional, not yet created) |
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

export 'package:live_uikit_macos/src/adapter/macos_registration.dart';
```

The registration surface is:

| Symbol | Kind | Purpose |
|---|---|---|
| `createMacosAdapter()` | function | Returns the macOS adapter for the composition root to register |
| `macosAdapter` | `const LanguageAdapter` | The const adapter instance |
| `macosAdapterId` | `const String` | The stable runtime id `'macos'` |

Do not export internal widget builders, the theme mapper/scope/builder, the capabilities constant, or third-party `macos_ui` types. Consumers reach capabilities through the adapter instance, not through a package-level export.

## 7. Adapter contract

The adapter implements the finalized core contract; the names below are fact, not aspiration.

`live_uikit` declares one interface, and it is an `abstract interface class` with no
implementation of its own. There is no base class to extend and nothing that renders a
control this package does not: every adapter package implements the interface directly
and answers every member of it.

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

That is seventeen control builders, one `wrap`, and the two structural surfaces. Each
builder takes the neutral spec for its control and returns a widget drawn from this
package's own library; `select` is generic over the caller's value type so a typed
selection survives the dispatch.

This package's implementation:

```dart
class MacosLanguageAdapter implements LanguageAdapter {
  const MacosLanguageAdapter();

  @override LiveDesignLanguage get language => LiveDesignLanguage.macos;
  @override String get id => 'macos';
  @override String get displayName => 'macOS';
  @override LiveUiCapabilities get capabilities => macosCapabilities;
  @override LiveUiSurfaceCapabilities get surfaces => macosSurfaces;

  @override Widget wrap(BuildContext context, DesignToken token, Widget child);
  @override Widget button(BuildContext context, LanguageButtonSpec spec);
  @override Widget card(BuildContext context, LanguageCardSpec spec);
  @override Widget textField(BuildContext context, LanguageTextFieldSpec spec);
  @override Widget switchWidget(BuildContext context, LanguageSwitchSpec spec);
  @override Widget checkbox(BuildContext context, LanguageCheckboxSpec spec);
  @override Widget slider(BuildContext context, LanguageSliderSpec spec);
  @override Widget segmented(BuildContext context, LanguageSegmentedSpec spec);
  @override Widget progress(BuildContext context, LanguageProgressSpec spec);
  @override Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec);
  @override Widget tabBar(BuildContext context, LanguageTabsSpec spec);
  @override Widget scaffold(BuildContext context, LanguageScaffoldSpec spec);
  @override Widget appBar(BuildContext context, LanguageAppBarSpec spec);
  @override Widget listRow(BuildContext context, LanguageListRowSpec spec);
  @override Widget navBar(BuildContext context, LanguageNavBarSpec spec);
  @override Widget toast(BuildContext context, LanguageToastSpec spec);
  @override Widget dialog(BuildContext context, LanguageDialogSpec spec);
  @override Widget tabView(BuildContext context, LanguageTabViewSpec spec);
  @override Widget appHost(BuildContext context, LanguageHostSpec spec);
  @override Widget shell(BuildContext context, LanguageShellSpec spec);
}
```

`slider` and `select` are the two builders that branch inside the adapter itself rather
than delegating straight to a builder, because each has a spec shape `macos_ui` refuses
to build (§9 Slider, §9 Select).

### Adapter identifier

Use one stable identifier everywhere:

```text
macos
```

The identifier is a machine-readable value used by the registry, persistence, and diagnostics — not a localized label. Do not use `macos_ui`, `macOS UI`, or a platform-dependent identifier as the runtime style id. The human-facing name for the style selector is `macOS`, carried by `displayName`.

### Capability declaration

`macosCapabilities` declares all seventeen controls and `macosSurfaces` both structural
surfaces, because the adapter implements all nineteen methods:

```dart
const LiveUiCapabilities macosCapabilities = LiveUiCapabilities(<LiveUiControl>{
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

const LiveUiSurfaceCapabilities macosSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
```

`LiveUiCapabilities` wraps a `Set<LiveUiControl>` and exposes `supports(control)`;
`LiveUiSurfaceCapabilities` does the same over `LiveUiSurface`. `LiveUiControl` is the
resolver's stable control identity — `button, card, textField, switchWidget, checkbox,
slider, segmented, progress, select, tabBar, scaffold, appBar, listRow, navBar, toast,
dialog, tabView` — and `LiveUiSurface` has exactly two members, `appHost` and `appShell`.

What "native" means here is one of two things, and every builder's doc comment says which:
**mapped**, when `macos_ui` has a widget of that shape and the spec is handed to it, or
**composed**, when the library has none and the control is assembled out of that same
library's own parts. It never means a widget from another design language.

| Control | Realised as | Built from |
|---|---|---|
| Button | Mapped | `PushButton` — `controlSize`, `color` for the variant, `semanticLabel`; label, glyph and loading `ProgressCircle` go into its child slot |
| Card | Composed | `MacosSheet` with `insetPadding: EdgeInsets.zero` — the library ships no card and no box widget |
| Text field | Mapped | `MacosTextField`; it has no error slot, so `errorText` recolours the border and adds a caption line beneath |
| Switch | Mapped | `MacosSwitch`, fully controlled; `enabled: false` reaches the library as its own null `onChanged` |
| Checkbox | Mapped | `MacosCheckbox`, with the optional trailing label laid out by this builder |
| Slider | Mapped, plus an inert form | `MacosSlider` when the spec has a callback; otherwise `ProgressBar` as the rail with the library's published thumb under `IgnorePointer` |
| Segmented | Mapped | `MacosSegmentedControl` behind a `MacosTabController` this widget owns; an inert spec is wrapped in `IgnorePointer` |
| Progress | Mapped | `ProgressBar` for a value (the 0..1 fraction scaled to its percentage), `ProgressCircle` for none |
| Select | Mapped | `MacosPopupButton<T>` with `MacosPopupMenuItem` rows; the adapter pre-filters the items and the value to what its assert accepts |
| Tab bar | Composed | a `Row` of the library's `MacosTab` cells, each with a `MacosIcon` glyph in front and a click cursor |
| Scaffold | Mapped | `MacosScaffold` with one `ContentArea`; the dispatched bars are stacked around it |
| App bar | Mapped | `ToolBar` — `leading`, a `Text` title, `CustomToolbarItem`s for the actions; a `bottom` strip is stacked beneath it |
| List row | Mapped | `MacosListTile`, which takes both press callbacks; `trailing`, `selected` and `divided` are added around it |
| Nav bar | Composed | a `Row` of equal-width `MacosTab` cells with `MacosIcon`, because macOS has no bottom bar |
| Toast | Composed | a `MacosSheet` panel carrying a `MacosIcon` status glyph; the library ships no transient message widget |
| Dialog | Mapped or composed | `MacosAlertDialog` when the actions fit its two `large` `PushButton` slots; `MacosSheet` for every other action set |
| Tab view | Composed | the library's own pane treatment — 5pt radius, hairline, per-brightness fill, 12pt inset — around an `IndexedStack` |

The two structural surfaces are declared and checked the same way:

| Surface | Realised as | Built from |
|---|---|---|
| `appHost` | Mapped | `MacosApp.router`, themed from the resolved token |
| `appShell` | Composed | the library's `SidebarItems` list of `SidebarItem` rows inside a fixed-width column the shell draws itself, because neither descriptor is a widget outside `MacosWindow` |

A declaration is checked rather than trusted:

- `LiveUiResolver.resolve(language)` returns the registered `LanguageAdapter` or throws
  `LiveUiResolutionException` — a language this build did not register is a composition
  fault, not a degrade.
- `requireControl` and `requireSurface` consult the declarations and throw
  `LiveUiCapabilityException` when a capability is claimed without a matching override,
  which is what keeps `macosCapabilities` and `macosSurfaces` honest.
- §17's guard compares both sets against the methods `MacosLanguageAdapter` actually
  overrides, and compares the README's control list against `macosCapabilities`.

This set must stay in sync with the methods `MacosLanguageAdapter` actually
overrides; §17 makes that a CI assertion and §16 a test.

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
| Density | Control-specific sizing (`ControlSize` on the button spec) | Control-level only; the token carries no global density knob |
| Focus appearance | Keyboard focus ring | Fork default; verify against the resolved `macos_ui` version before claiming token control (§12) |
| Transparency | Vibrancy / material effects | Not mapped — the library's vibrancy is per-surface, and this adapter does not read the resolved `canBlur` affordance flag; an effect the device cannot afford is reported as `unsupportedEffect` (§15) |
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

Each builder converts one core specification into a widget of this package's own
library. Where `macos_ui` has a widget of that shape the builder **maps** onto it;
where the library has none the builder **composes** the control out of that same
library's parts. A builder's doc comment says which of the two it is, and §7's table
records the outcome for all seventeen controls.

### Button (`MacosButtonBuilder`) — mapped

- Map intent onto the one variant affordance `macos_ui` exposes on its push button, `PushButton.color`: `primary` takes the token primary (the macOS prominent button), `danger` the token error, and `secondary`/`ghost` keep the library's own standard surface with the ghost label tinted by the token primary. The core `ControlSize` maps onto `macos_ui`'s small/regular/large sizes.
- Press eligibility, the loading spinner and the label-plus-glyph layout are laid out by
  this builder inside the library widget's own child slot: a loading button draws the
  library's `ProgressCircle`, and a leading `Icon` sized to the label's own font step
  rides in front of it.
- `expand` wraps the button in `SizedBox(width: double.infinity)`; `tooltip` wraps it in the core's language-neutral `LiveTooltip` and is also passed as the library's `semanticLabel`, which is the accessible name an icon-only button needs.
- `focusNode` and `autofocus` are **not expressible**: `PushButton` creates and owns its focus handling, and wrapping the button in a second `Focus` would hold the focus that actually performs keyboard activation. Recorded as an unmappable spec field (§15); `test/widgets/` asserts nothing crashes when they are supplied.
- `iconOnly` needs no special case: this builder paints the glyph alone, with the
  tooltip as its `semanticLabel`, and never paints the empty `label` the caller passed
  to satisfy the contract, so a textless button arrives here already correct.
- `selected` is **not mapped by this adapter today**. `PushButton` has no selected or
  toggled affordance to take it, and reproducing a tinted selected state would mean
  hand-painting an overlay on top of the library's own widget. Recorded as the
  documented remainder of `docs/decisions/0004` (§15).
- `style` is **not mapped by this adapter either**. Its button is the library's own
  widget and paints its own surface; applying a caller's `Style` to it would mean
  hand-painting an overlay over that widget, the trade this section already refuses
  for `selected`.

### Card (`MacosCardBuilder`) — composed

- `macos_ui` 2.2.2 ships no card and no box widget, so the card is composed from the one
  panel the library has that can be mounted inline: `MacosSheet`, the widget
  `showMacosSheet` puts in its route — a 12pt rounded panel filled with the control
  background and edged with the library's own inner and outer hairlines, which is what a
  macOS group box looks like.
- `insetPadding` is set to zero, because the sheet's default (140 horizontal, 48
  vertical) is the clearance a modal route gives a dialog; an inline card is sized by its
  own content. The token's padding goes inside, and `selected` tints the fill with the
  token primary background.
- Of the inline `Style` only `background` is read: the panel's radius and its double
  hairline are the library's decision, the same way `MacosPopupButton` decides its own
  edge.
- `bordered` asks for an edge the sheet already draws and so needs no extra work.
  `onTap`/`onLongPress` get the pointer affordance macOS itself uses — a click cursor
  over an opaque hit area — because the library's tap handling lives inside its buttons
  and none of them is a card.
- `focusNode` and `autofocus` are **not expressible**: a sheet is a surface, not a
  control, and it takes no focus slot.

### Text field (`MacosTextFieldBuilder`) — mapped

- Use the native `macos_ui` text input.
- Preserve the supplied controller, focus node, callbacks, enabled/read-only/obscure state, `maxLines`, keyboard type and action, prefix/suffix, and `style` override.
- Do not create a second controller or silently own its lifecycle; when the spec's controller is null, the field owns the one it creates.
- The library has no error slot: `errorText` redraws the decoration border in the token error colour and adds the caption line beneath, so both signals the field has to send still reach the user (§15).

### Switch (`MacosSwitchBuilder`) — mapped

- The control is the library's own `MacosSwitch`, whose track follows the theme's primary
  and whose knob slides on a drag. It stays fully controlled: the value comes from the
  spec and the library never mutates it.
- `enabled: false` is folded into the callback rather than approximated. `MacosSwitch`
  derives its disabled look from a null `onChanged` — the same rule this adapter relies
  on for `MacosCheckbox` — so a dead spec gets the library's own inert state instead of a
  closure that swallows the value.
- `focusNode` and `autofocus` have **no slot** on `MacosSwitch`: the control builds its
  own tap and drag recognizers and takes no focus node, so keyboard activation of a
  switch is not expressible in this library at all. Recorded as the gap it is rather than
  wrapped in a second `Focus` that would hold the focus actually handling activation
  (§9/§15).

### Checkbox (`MacosCheckboxBuilder`) — mapped

- Use the native `macos_ui` checkbox.
- Preserve value and `onChanged`. `enabled: false` nulls the callback rather than wrapping it in a closure that swallows the value: `MacosCheckbox` derives its disabled look from a null `onChanged`, so the same signal that greys the box also makes it uncallable. The optional trailing `label` is laid out by this builder, because the library's checkbox paints no label of its own.
- `focusNode` and `autofocus` are **not expressible**: `MacosCheckbox`'s constructor has no focus slots at all, so there is nothing to forward. Recorded as an unmappable spec field (§15); `test/widgets/` asserts nothing crashes when they are supplied.
- A null `onChanged` or `enabled: false` must render disabled without swallowing state.

### Slider (`MacosSliderBuilder`) — mapped, with one assembled inert form

- Use the native `macos_ui` slider, passing `min`/`max` to the library (it asserts `min <= value <= max`) and clamping the value to the range.
- `MacosSlider.onChanged` is required and non-nullable, so a disabled slider — `enabled: false` or a null `onChanged` — is a spec the library cannot build at all, and a closure that swallowed the value would leave a control that still moves under the pointer. `MacosLanguageAdapter.slider` therefore draws that case itself, out of the library's own static parts: `macos.ProgressBar` (a track with a filled portion, inert by construction, whose value is a percentage) as the rail in the token primary, and the thumb in the library's published `MacosColors.sliderThumbColor`, parked at the value's fraction under an `IgnorePointer` and announced with slider semantics. `MacosSlider` keeps its track and thumb types private, which is why the inert form is assembled from other widgets of this same library rather than restyled.
- `focusNode` is not a parameter of `MacosSlider` and is recorded as unmappable rather than emulated.

### Segmented (`MacosSegmentedBuilder`) — mapped

- The track is the library's own `MacosSegmentedControl`: the tinted track, the white rounded chip on the checked segment and the hairline between neighbours are its drawing, not this builder's.
- The widget is driven by a `MacosTabController` and offers no index callback, so the controller belongs to this builder's stateful wrapper and is wired both ways — its change is reported through `onChanged`, and the spec's `index` is asserted back onto it on every rebuild. A caller that refuses a tap therefore gets the chip moved back on the next frame. Because the controller's `length` is final, a track that gains or loses a segment is given a fresh controller seeded at the spec's index.
- The control has no disabled state at all — it sets the controller index on tap whatever the caller asked — so an inert spec is wrapped in `IgnorePointer`, which keeps the segments where the spec puts them instead of drawing a selection the caller never agreed to.
- `expand` has no counterpart: the control lays its segments out through `IntrinsicWidth`/`IntrinsicHeight` and sizes to their labels, so it cannot be stretched. An empty track returns an empty box, because the control asserts at least one segment.

### Progress (`MacosProgressBuilder`) — mapped

- A non-null `value` is the library's `ProgressBar`, macOS's linear determinate bar, whose value is a percentage — so the contract's 0..1 fraction is scaled, `height` becomes the track thickness, and `barColor` the track colour over the token's secondary fill.
- A null `value` is `ProgressCircle`, which is what macOS itself uses for work of unknown length. `ProgressBar.value` is required and non-null, so a spinner cannot be faked as a bar at zero, and `ProgressCircle` takes only a radius — neither `height` nor `barColor` has a slot in that branch.
- `showLabel` has no slot on either widget, and this builder does not overlay a hand-built percentage on the bar, so the label simply is not drawn in this language (§15).

### Select (`MacosSelectBuilder`) — mapped

- The control is the library's own `MacosPopupButton<T>`, generic over the caller's value type, so a typed selection comes back unchanged; `placeholder` rides in as the button's `hint`, the slot the library shows while no value is chosen.
- `MacosPopupButton` asserts that its current value matches exactly one of its items. Measured on 2.2.2 that assert short-circuits while `value == null`, which is the library's own *nothing chosen* state, so the adapter hands this builder a spec that satisfies it: an off-list value is dropped to null — the field shows the placeholder and the value is never treated as legal — and the menu keeps only choosable values, dropping nulls and repeated item values for the same "exactly one" reason (§15).
- A disabled select is the library's own inert state (a null `onChanged` greys the caret and refuses the menu), so `enabled` needs no extra work. The menu can hand back a null selection — `onChanged` is `ValueChanged<T?>` — and the contract has no case for it, so a null is dropped rather than reported.

### Tab bar (`MacosTabBarBuilder`) — composed

- The strip is assembled from the library's own pieces. `MacosTab` is the cell `MacosSegmentedControl` renders and paints the checked chip and its radius itself, so the selected state stays the library's visual; `MacosIcon` carries the glyph in front of it, and the click cursor is the pointer affordance the library's own controls use.
- Two measured refusals make the mapping impossible. `MacosTabView` is a tab *view*: it asserts `controller.length == children.length` and paints a padded, bordered content area under the strip, while this contract's tab bar is the strip only — the caller's router owns the body. And `MacosSegmentedControl` is the strip, but its `MacosTab` cells carry a `label: String` and no icon slot, while a tab that was given a glyph must keep it.
- The strip is fully controlled: the checked cell is wherever `index` says and a tap only reports an index. `spacing` has no counterpart in this library — the cell carries its own padding — so the gap between segments is this widget's fixed 3/2 inset and nothing else.

### Scaffold (`MacosScaffoldBuilder`) — mapped

- `macos_ui` composes a window as `MacosScaffold` plus one `ContentArea`, with the bar above it, so `appBar` and `bottomBar` are stacked around the scaffold rather than handed to it: `MacosScaffold.toolBar` takes a `ToolBar` specifically, while the dispatched bar is whatever the active language renders and the frame may not assume it.
- `ContentArea` hands its builder a scroll controller that the spec's body does not take: the body owns its own scrolling.
- Two fields have no macOS slot at this level. The library has no floating action, so the core's overlay geometry places `floatingActionButton` in a `Stack` over the frame; and `extendBodyBehindAppBar` / `avoidKeyboard` have no counterpart, because a macOS window's content area already sits inside its own safe area and does not resize for a keyboard (§15).

### App bar (`MacosAppBarBuilder`) — mapped

- The in-scaffold bar is the library's `ToolBar`, whose parts line up with the spec: `leading` is `leading`, the title is a widget slot, and `actions` ride in as `CustomToolbarItem`s — the library's own escape hatch for widgets that are not one of its three toolbar item kinds.
- A macOS bar centres its title by default, so `centerTitle` is left null rather than forced to false, and `background` becomes the bar's own decoration when given.
- `height` is stated on the wrapper as well as on the widget: `ToolBar`'s internal layout asks to be as tall as it can, which is fine inside `MacosScaffold.toolBar`, which sizes it, and an assertion when a frame stacks the bar in a column.
- `bottom` — a strip under the title — has no slot in a `ToolBar`, so the bar is stacked with it, and that pairing is documented here rather than dropped: the strip still renders, drawn by whichever adapter draws it.

### List row (`MacosListRowBuilder`) — mapped

- `MacosListTile` is the library's row and takes both press callbacks, so `onTap` and `onLongPress` map directly; the gesture wrapper this package's card needs is not required here.
- `title` and `subtitle` are the widget's own text slots, each ellipsised to one line. `trailing` has no slot on the tile — macOS rows end at their text, while a settings row commonly carries a chevron or a switch — so it sits beside the tile in a row; `selected` is painted as the row's own fill, and `divided` draws the hairline itself.
- `focusNode` and `autofocus` have no slot on the tile and are recorded as unmappable.

### Nav bar (`MacosNavBarBuilder`) — composed

- macOS has no bottom bar. The library's navigational list, `SidebarItems`, is a scrollable `ListView` sized for a column as tall as a window — not a strip under a page, and it is this package's shell surface rather than this control; `Sidebar`, its window-side wrapper, is not a widget in 2.2.2 but a descriptor `MacosWindow` reads.
- What the library does have is its own navigational cell, `MacosTab`, described in its own docs as the item that moves the user between the views of a tab view. So each destination is that cell with the library's `MacosIcon` in front of it, one cell checked — the checked cell paints its own selection chip, so the accent decision stays with the library.
- Every destination shares the row's width the way a macOS toolbar group does, and a disabled bar keeps its labels and stops reporting.

### Toast (`MacosToastBuilder`) — composed

- `macos_ui` 2.2.2 has no transient message widget: its exports carry no `Toast`, no `Banner` and no `Notification` (the 1.x `MacosToast` and the `ToastOverlay` host it required are gone from the library). The surface is therefore the library's own floating panel, `MacosSheet`, which is what a macOS HUD is drawn from.
- The panel is returned as a widget rather than shown: its `build` reads only `MacosTheme` and `MediaQuery`, so unlike `showMacosSheet` — a route, needing a `Navigator` — it requires nothing the core's overlay does not already provide. Placement, the fade and the timer are the core's, and `insetPadding` is zero for the same reason it is zero on the card: that clearance is a dialog route's job.
- The status colour is the token's, so `warning` looks like this app's `warning`, and the glyph is from the Cupertino set macOS draws from — `macos_ui` uses it internally but does not re-export it, so it is taken straight from the SDK.

### Dialog (`MacosDialogBuilder`) — mapped where the slots exist, composed where they don't

- The surface is `MacosAlertDialog` wherever the library's slots can carry the spec. Verified against 2.2.2: it is a plain `StatelessWidget` whose `build` only asserts `debugCheckHasMacosTheme` (which `wrap` installs) plus its own button-shape asserts, so — like `MacosSheet` — it needs no `Navigator` and no route of its own and can be handed straight to the core's `showLiveDialog`. This builder starts no `showMacosAlertDialog`, pushes no route and adds no `Center`: the route, the barrier, the fade-and-scale, the inset and the width cap are the core's, and `dismissible` is the core's barrier knob, so it is deliberately not drawn here.
- The mapping is exact only when the slots exist, and three of them are strict: `appIcon`, `title` and `message` are required widgets, and the two action slots are typed `PushButton` with an asserted `ControlSize.large`, in a fixed 260px column that takes the *last* action as the default one (`primaryButton`, drawn right) and the *first* as `secondaryButton`. So a spec with one or two actions that are exactly that shape becomes the library's alert, with the icon riding the `appIcon` slot at the 64pt the widget documents.
- Everything else — no actions at all (inventing an OK button the caller never asked for is not this adapter's to do), three or more actions, or an action that is not a `large` `PushButton` — has no slot in that widget, and the surface is composed out of the library's own panel instead: the same `MacosSheet` the card and the toast take, with its 140/48 dialog-route `insetPadding` zeroed because the core's frame already insets the surface. There the glyph goes over the heading and the actions keep the row and the order the spec asked for.
- A null `title` or `content` becomes an empty slot in the alert — the library requires a widget there and reserves the space whatever is given it — and the heading of the composed surface uses the token's text role, the way the other macOS surfaces take their type.

### Tab view (`MacosTabViewBuilder`) — composed

- The library does have a view, `MacosTabView`, but it is the whole control rather than this contract's half of it: it takes the `List<MacosTab>` strip *and* the `List<Widget>` bodies in one widget and drives them from a `MacosTabController` it asserts its `length` against, so the selection would live in the library rather than in the caller's index, and the strip this package already answers for would be drawn twice. `LanguageTabViewSpec` hands over pages and an index and keeps the controller outside, which is exactly the shape that widget cannot take.
- So the pane is assembled from the library's own numbers, read off `tab_view.dart`: the 5pt radius, the hairline and the fill it resolves per brightness, wrapped in the 12pt inset it gives its body, over an `IndexedStack` that keeps every page mounted so a page's own state survives a change of index.
- Two spec fields are deliberately not drawn, both because macOS does not do the thing: `onIndexChanged` reports a page moved by the viewer, and a macOS pane is never dragged — only the strip moves it, through the caller — and `duration` is how long a change takes where the language animates one, which the library's own view does not: its body swap is a `setState` on the index, no cross-fade, no slide.
- A page index outside `pages` is clamped rather than thrown at, and no pages at all is an empty box: the strip and the view are driven separately, and a frame where the two disagree must not take the window down.

### App host and shell (`MacosHostBuilder`, `MacosShellBuilder`) — the two structural surfaces

- The host is the library's own `MacosApp.router`, themed from the resolved token. It owns what a macOS window feels like: the cupertino route stack, the window-active/inactive tinting the library tracks, the overlay a sheet opens into, and the desktop accent colour it reads from the platform. Both `theme` and `darkTheme` carry the one resolved theme, so the host cannot second-guess the brightness the appearance setting already chose. Under another library's host the controls would be macOS and the behaviour someone else's, which is why the surface is declared and dispatched rather than assumed.
- The shell is **composed**, and the constraint is real: in `macos_ui` 2.2.2 neither `Sidebar` nor `SidebarItem` is a widget. Both are plain descriptor classes with no `build`. `Sidebar` is read only by `MacosWindow`, which turns its `minWidth`/`maxWidth`/`isResizable`/`top`/`bottom` fields into a resizable split around `sidebar.builder`; `SidebarItem` is read by `SidebarItems`, which mounts a private row widget per descriptor. A shell that is not a window cannot mount the first, so the shell maps only the list — `SidebarItems` of `SidebarItem` rows, the selected one painted with the system-accent chip, the spec's destinations turned into those descriptors one-for-one so the accent decision, the row metrics, the icon tint and the selection painting all stay the library's — inside a fixed-width, canvas-coloured column it draws itself beside the page. It is not a `MacosWindow` and adds no `ToolBar` and no title bar; the page frame stays with this language's `scaffold`.
- The consequences of that composition are stated plainly: the column is not drag-resizable and has no window-breakpoint auto-hide, because those are `MacosWindow` behaviours the descriptor only asks for; the descriptor's `top`/`bottom` slots are unreachable from outside a window, so `trailing` is pinned under the list by the shell's own column, padded to the list's 10-unit inset; the rail width is this library's metric, floored at 154 logical px, because a sidebar row sizes itself to `134 + visualDensity.horizontal` and the token's 88 would crush it; and `SidebarItems` asserts `currentIndex >= 0`, so an id that matches no destination selects the first row rather than crashing inside the library.
- `placement` is honoured by the shell's own rule — `rail` always, `bottom` never, `adaptive` whenever the environment reports a rail width above zero — so the same app changes form at the same window width whichever language is active. The `bottom` form is not drawn twice: the shell asks this language's `navBar` for its strip and drops `trailing`, which a strip has no slot for. `LiveShellDestination.enabled` has no counterpart in the library — `SidebarItem` has no disabled field and `SidebarItems.onChanged` is required — so every row is tappable and the shell refuses the tap itself, leaving a disabled destination visible, tinted and inert rather than missing. A `none` placement, or fewer than two destinations, is not a navigation choice at all: the shell stands aside and the page keeps its own frame.

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder may receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup.
`LanguageRegistry` is built from an adapter map, so registration is a construction at
the root rather than a mutation of a global:

```dart
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.macos: macosAdapter},
);
```

Registration surface (see §6): `createMacosAdapter()`, `macosAdapter` (const), `macosAdapterId`.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active language through `UiConfig.language`.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_macos` must not register itself through global static initialization or require the business layer to import it.

### Resolution and failure

Runtime resolution is performed by `LiveUiResolver` against the `LanguageRegistry`. It has three failure modes, and all three are raised rather than logged:

| Situation | What happens |
|---|---|
| The selected language has no registered adapter | `resolve(language)` throws `LiveUiResolutionException` |
| A control is declared in `capabilities` but has no matching override | `requireControl(language, control)` throws `LiveUiCapabilityException` |
| A surface is declared in `surfaces` but has no matching override | `requireSurface(language, surface)` throws `LiveUiCapabilityException` |

The only diagnostic still *emitted* is `unsupportedEffect`, and it reports what the device cannot afford — an effect such as a backdrop blur — not a missing implementation. `LiveUiDiagnostic` events carry `code`, `language` and, when the event is about one, a `control` or `surface`; they are delivered to a host-supplied `LiveUiDiagnosticSink`, never to a concrete logging package.

`LanguageRegistry` takes the adapter map and nothing else, so there is no fallback entry to configure: a build that ships macOS and asks for a language it did not register is a composition fault the app fixes at its root, not a skin it can settle for. Nothing switches styles silently.

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

Switching adapters changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services. `LiveUiResolver.resolve` reads `UiConfig.language` and returns that language's adapter, or throws `LiveUiResolutionException` when this build registered none, so a switch never leaves part of the subtree in the previous language.

Because macOS answers all seventeen controls and both structural surfaces itself, switching *into* this language replaces every rendering path with a `macos_ui` widget or a composition of its parts: the text field, checkbox, slider and select keep the caller's own controller and focus node across the change, and the app's router keeps owning the body the tab strip and the shell navigate. `test/integration/` asserts exactly that (§16).

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

Beyond the controls `macos_ui` lets a caller drive, this package keeps no focus plumbing of its own: `MacosSwitch` takes no focus node at all, and `PushButton`, `MacosCheckbox` and `MacosSlider` create and own their handlers, so §9 records those spec fields as unmappable rather than wrapping the controls in a second `Focus` that would hold the focus actually performing activation. There is no `interaction/` module yet; add one when behavior needs a home rather than scattering it across builders (see §4).

Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility. Test the actual controls with supported TV input devices and use the core interaction policy to fill gaps.

## 13. Platform behavior

The macOS style is a visual choice, not a declaration that every operating system provides native macOS controls. The adapter can be selected on any platform; the primary fit is macOS desktop.

| Platform | Expected behavior |
|---|---|
| macOS | Primary fit: native `macos_ui` controls, desktop keyboard, pointer and hover, native application integration |
| Windows | macOS visual style drawn in full by `macos_ui`; retain appropriate Windows integration |
| Linux | macOS visual style; verify platform-specific rendering and dependencies |
| Android | macOS visual style with touch-friendly sizing |
| Android TV | macOS visual style plus explicit D-pad and focus testing |
| iOS | macOS visual style while retaining iOS lifecycle and accessibility behavior |

Vibrancy, transparency and window-material effects are deliberately not mapped (§8.1), so there is nothing here to lose when a platform cannot produce them; where a requested effect cannot be afforded, the core reports `unsupportedEffect` and a verified degraded visual stands in. Native macOS window APIs must never become a required dependency of the basic adapter, and this package's shell is not a `MacosWindow` (§9).

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

Two kinds of problem live here, and the runtime treats them differently.

**A capability this language does not serve is a fault, not a downgrade.** There is nothing underneath `LanguageAdapter` to render a control this package has not implemented, so:

- A selected language with no registered adapter raises `LiveUiResolutionException`.
- A control declared in `macosCapabilities` without a matching override, or a surface declared in `macosSurfaces` without one, raises `LiveUiCapabilityException` from `requireControl` / `requireSurface`. This package declares all seventeen controls and both surfaces and implements all nineteen methods, so neither exception is reachable from a macOS build — which is exactly why the declaration is asserted in a test (§16) rather than trusted.

**An effect the device cannot afford is a diagnostic.** `LiveUiDiagnosticCode` has one member, `unsupportedEffect`, for a visual the environment cannot produce — a backdrop blur, for instance. `LiveUiDiagnostic` carries `code`, `language` and, when the event names one, `control` or `surface`, and is delivered to a host-supplied `LiveUiDiagnosticSink`, never to a concrete logging package. Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- A macOS run that renders the whole contract puts nothing in the sink: no control and no surface is downgraded, because every one of them is answered here. `test/integration/` asserts the control-and-surface slice of the sink is empty (§16).
- A spec field `macos_ui` has no slot for is recorded in §9, and the builder either honours it from that library's own parts (the card's and list row's pointer affordance, the app bar's `bottom`, the scaffold's floating action) or does not draw it at all (the button's `selected` and `style`, the progress `showLabel`, the segmented `expand`, the tab strip's `spacing`, the tab view's `onIndexChanged` and `duration`, a disabled sidebar row).
- A spec shape the library asserts on is normalised before the widget is built: the select drops an off-list or repeated value and shows its placeholder, and a slider with no callback takes its assembled inert form.
- Invalid control data follows core validation rules.
- Programming errors must not be swallowed.
- Diagnostics must avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Contract tests (`test/adapter/macos_contract_test.dart`)

- Stable adapter id `macos`, `displayName` `macOS`, `language` `LiveDesignLanguage.macos`.
- `macosCapabilities` is the whole contract — all seventeen `LiveUiControl` members, and no others — and `macosSurfaces` is the whole of `LiveUiSurface`, both `appHost` and `appShell`. The same comparison is what §17 makes against the methods `MacosLanguageAdapter` overrides.
- Through the real `LanguageRegistry` + `LiveUiResolver`: macOS resolves to this adapter, `requireControl` succeeds for every control of the contract, and a language this build did not register raises `LiveUiResolutionException` instead of degrading.

### Theme tests (`test/theme/macos_theme_test.dart`)

- Brightness, `primaryColor` and `canvasColor` follow the resolved token (§8.1), and a
  dark token yields a different canvas than the light one (§8.3).
- Toggling brightness re-skins through `wrap`, with no restart.
- Typography and density are deliberately *not* mapped — `accentColor` is macOS's own
  fixed swatch and its typography is a `MacosTypography` object (§8.1 "map only
  supported") — so there is nothing here to assert, and §8.1 says so.

### Widget tests (`test/widgets/macos_native_controls_test.dart`)

Driven through a real `LiveConfigProvider` with the adapter registered, so the dispatch path itself is under test:

- Button: callback when enabled, input rejected while loading, the variant reaching `PushButton.color`, and `expand`, `tooltip` with the accessible label reaching the control.
- Text field: controller and `onChanged` pass-through; prefix, suffix and the error
  message; an inline `Style` overriding the token body text; and the caller's `FocusNode`
  being the node that actually takes focus (§9/§16).
- Checkbox: reporting the next value, and a null callback reaching the library as null
  rather than a swallowing closure.
- Slider: rendering natively with the spec's `min`/`max`, and a dead slider drawn as the library's own `ProgressBar` rail with the assembled thumb — the drag leaves the value where the spec put it, and a null callback renders the same inert form (§9).
- Switch, segmented, progress and select: each asserted as the library's own widget, including a disabled switch arriving as a null `onChanged`, a disabled track wrapped so the tap never moves the selection, a percentage-scaled bar against the spinner form for a null value, and a select whose value is not among its items reading as nothing chosen while its menu keeps each legal value once.
- The composed controls: the card as a `MacosSheet` panel that takes the tap; the tab strip and the destination strip as `MacosTab` cells carrying their `MacosIcon` glyphs and staying controlled by the spec index; the toast surface as a `MacosSheet` that the core's overlay places, fades and times out; a dialog with one or two `large` push buttons as `MacosAlertDialog` — default action on the right — and a dialog with three as the `MacosSheet` form; and the page switcher as the library's pane over an `IndexedStack` that shows one body at a time.
- Chrome and the two surfaces: a full page as `MacosScaffold` with its `ToolBar`, the app hosted by `MacosApp` with no `MaterialApp` standing in, and the shell in each form — the rail drawing the library's `SidebarItems` list with a disabled destination left visible and inert, `bottom` delegating to this language's `navBar` and dropping `trailing`, `adaptive` taking the rail form, and `none` or a single destination drawing no navigation at all.

Not covered: accessibility semantics and layout under narrow versus wide constraints —
the library's focus ring, keyboard traversal and screen-reader behaviour are §12/§19 hardware
items, and this suite does not claim them.

### Integration tests (`test/integration/macos_style_switching_test.dart`)

- Every `LiveUiControl` and every `LiveUiSurface` resolves to this adapter: the two declarations equal `LiveUiControl.values` and `LiveUiSurface.values`, and `requireControl`/`requireSurface` succeed for each member.
- A run with macOS active puts no control or surface entry in the diagnostic sink, because nothing in the contract is served by anything else (§15).
- A re-theme through this language changes the rendering path without changing the caller's state: the text typed into `LiveTextField` is still there afterwards, and the field, checkbox, slider and select are still the library's own widgets.
- Select returns its typed value through the pop-up button's menu, from the caller's own item list (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum, include macOS desktop, a mobile target, and Android TV in the planned validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_macos` depends on `live_uikit` and `macos_ui` only for its core integration.
- `live_uikit_macos` does not depend on other style adapters (`live_uikit_fluent`, `live_uikit_cupertino`, `live_uikit_material`, `live_uikit_glass`, `live_uikit_neumorphic`, `live_uikit_wind`).
- The core package does not depend on `macos_ui`.
- Business packages do not import `package:macos_ui/macos_ui.dart`.
- The public barrel exports only `src/adapter/macos_registration.dart`.
- The adapter exports no localization delegates.
- `macosCapabilities` matches the set of control methods `MacosLanguageAdapter` overrides — declaring a control with no override and overriding a control without declaring it are both drift — and `macosSurfaces` matches its `appHost`/`shell` overrides the same way. The package must also hold exactly one `*_adapter.dart`, one `*_capabilities.dart` and at most one `*_surfaces.dart` under `lib/src/adapter/`.
- Every `package:macos_ui/` import inside this package uses the `as macos` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `macosCapabilities`: a control named in
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

- Align the adapter with the finalized core contract. Done: `MacosLanguageAdapter implements LanguageAdapter` — the interface directly, with no base class underneath — id `macos`, the `macosCapabilities` and `macosSurfaces` declarations, and the registration exports.
- Register macOS from the application composition root.
- Keep the contract test green as the guard on id, language, and capabilities.

### Phase 2 — Theme integration ✅

- Complete theme mapping in `macos_theme_builder.dart` / `macos_theme_mapper.dart`.
- Verify `MacosThemeScope` installation through `wrap`.
- Test brightness, `primaryColor` and `canvasColor`; typography and density stay at the
  library's defaults, since `accentColor` is a fixed `AccentColor` swatch and its typography
  is a `MacosTypography` object the token cannot name (§8.1).
- Verify runtime theme updates and invalidation.

### Phase 3 — Full control coverage ✅

- All seventeen controls are answered, each in its own builder and each declared in
  `macosCapabilities`: eleven hand the spec to a `macos_ui` widget — `PushButton`,
  `MacosTextField`, `MacosSwitch`, `MacosCheckbox`, `MacosSlider`,
  `MacosSegmentedControl`, `ProgressBar`/`ProgressCircle`, `MacosPopupButton`,
  `MacosScaffold`, `ToolBar` and `MacosListTile` — and six are composed out of that
  library's parts because it has no widget of that shape: card, tab bar, nav bar, toast,
  tab view, and a dialog whose actions `MacosAlertDialog` has no slots for (§9).
- Both structural surfaces are owned: `MacosApp` as the host, and the library's
  `SidebarItems` navigation list inside a column of the shell's own as the shell (§9).
- A control is covered only when the builder, the override and the capability entry land
  in the same change; §17 fails the build on any other combination.
- Testing now covers every one of them, mapped and composed alike (§16).

### Phase 4 — Interaction and accessibility ◐

- Headless half done: caller state, callbacks and the spec fields `macos_ui` can carry are asserted in `test/widgets/`; the fields it cannot take (`focusNode`/`autofocus` on `PushButton`, `MacosCheckbox`, `MacosSwitch`, `MacosListTile` and the card's `MacosSheet`, `focusNode` on `MacosSlider`) are documented in §9 rather than faked.
- Open, needs hardware: focus traversal, hover behavior, Android TV D-pad.
- Factor keyboard, focus, and hover behavior into an `interaction/` module when it needs a home.
- Test Android TV D-pad behavior under the macOS style.
- Validate semantics and accessibility.
- Keep the §9 record current: a spec field the library cannot take stays documented there, with the composed or simply-undrawn handling named, rather than being silently approximated.

### Phase 5 — Production readiness ◐

- The architectural CI checks in §17 are enforced by `tool/check_architecture.ps1` (library boundary, `macos` import prefix, registration-only barrel, capability/override and surface/override match, README control list, §4 tree).
- Integration resolution is asserted in `test/integration/`; what is still open is a cross-adapter switch, which §3.3 keeps out of this package and into the application suite.
- Verify all claimed platforms.
- Optionally add `icons/`, `diagnostics/`, and `example/`.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `macos_ui` only for its core integration.
- [x] It implements the core `LanguageAdapter` interface directly, as an `abstract interface class` with nothing underneath it.
- [x] It uses the stable adapter id `macos` and display name `macOS`.
- [x] `macosCapabilities` declares all seventeen controls, and each is an override on `MacosLanguageAdapter`.
- [x] `macosSurfaces` declares both structural surfaces, and both are overridden: `MacosApp` for the host, the library's `SidebarItems` list inside the shell's own column for the shell.
- [x] It maps the resolved `DesignToken` into `macos_ui` theme values through `MacosThemeMapper` and `MacosThemeScope`.
- [x] It uses a `macos_ui` widget where the library has one and composes the control out of that library's own parts where it does not; §9 records which is which.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell: the host is chosen by the composition root, and the shell adds a sidebar, not a `MacosWindow`.
- [x] It adds no localization delegates, reusing the core Material/Cupertino localization.
- [x] The public barrel exports only `src/adapter/macos_registration.dart`.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, pointer, accessibility, and TV focus behavior are tested — a caller's `FocusNode` reaching the field's focus tree is (§16), but pointer hover, the library's focus ring and D-pad traversal need a Mac and a TV runtime.
- [x] Spec fields the library cannot take are documented in §9, and a capability declared without an override is a `LiveUiCapabilityException` rather than a quiet substitute.
- [x] Diagnostics use the shared core contracts and a host sink, not a logging package.
- [x] Tests and static analysis pass for `packages/live_uikit_macos`.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_macos` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, `DesignToken` model, runtime selection via `LiveUiResolver` and `LanguageRegistry`, and the exception and diagnostic policy.
- `LanguageAdapter` is an `abstract interface class` with no implementation: seventeen control builders, `wrap`, and the two structural-surface methods, which every adapter answers itself.
- `live_uikit_macos` maps those contracts to macOS presentation: eleven controls take a `macos_ui` widget directly, six are composed out of that library's own parts, and both structural surfaces are owned — `MacosApp` for the host, `SidebarItems` inside the shell's own column for the shell.
- `macos_ui` supplies the underlying macOS widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences; this package adds no localization delegates of its own.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive offer a desktop-first macOS aesthetic — with native keyboard and pointer interaction and native macOS application integration on its primary platform, and the same `macos_ui` rendering wherever the style is selected — without forcing business packages to know which UI library is currently rendering their controls.
