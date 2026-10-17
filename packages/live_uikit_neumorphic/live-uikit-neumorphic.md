# `live_uikit_neumorphic` Architecture and Integration Specification

- **Package:** `live_uikit_neumorphic`
- **Parent package:** `live_uikit`
- **Implementation library:** `flutter_neumorphic_ui_kit`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_neumorphic` is the Neumorphic (soft-UI) adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into `flutter_neumorphic_ui_kit` controls and soft-UI visual behavior. It must not implement business pages or duplicate the core theme system.

Neumorphism renders controls as extruded or inset surfaces shaped by a light source, a shadow depth, and a single base/accent surface color. This adapter expresses that vocabulary for every control the core dispatches: eight are drawn with a widget `flutter_neumorphic_ui_kit` ships, nine are composed from that library's own container faces and theme values because it ships no widget for the job, and both structural surfaces — the app host and the shell — are answered here too. Nothing a Neumorphic page asks for is rendered by another library.

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
2. **Neumorphic owns soft-UI visuals.** Render a control with the `flutter_neumorphic_ui_kit` widget that already is that control; where the library has none, compose it from that library's own container faces and `NeuTheme` values rather than reaching outside the dependency or drawing a flat imitation of the style.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from Neumorphic to another style must not require business pages to import or construct different control classes.
6. **Surfaces are shadow-driven.** A neumorphic container's identity is its shadow set; the adapter must render a legible, on-theme surface even when shadows are reduced or unavailable.
7. **The contract is answered in full.** Every control the resolver can dispatch, and both structural surfaces, have an override in this adapter. A control this library cannot state is a field the builder records as unmappable (§15), never a widget borrowed from another design language.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Neumorphic theme mapping from the resolved design token.
- Neumorphic construction of all seventeen controls the core dispatches — eight mapped onto a `flutter_neumorphic_ui_kit` widget, nine composed from that library's own container faces and theme values.
- Both structural surfaces: the `WidgetsApp` host that carries `NeuTheme`, and the navigation shell composed from the same faces.
- Neumorphic-specific control defaults (depth, soft/inset surface shape, padding).
- Declaring the served controls in `neumorphicCapabilities` and the owned surfaces in `neumorphicSurfaces`, so the resolver's checks match this adapter's overrides.
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
| `live_uikit_cupertino` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_material` | No | Adapters must remain independent |
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
    │       │   ├── neumorphic_adapter.dart
    │       │   ├── neumorphic_capabilities.dart
    │       │   ├── neumorphic_registration.dart
    │       │   └── neumorphic_surfaces.dart
    │       ├── theme/
    │       │   ├── neumorphic_theme_builder.dart
    │       │   ├── neumorphic_theme_mapper.dart
    │       │   └── neumorphic_theme_scope.dart
    │       └── widgets/
    │           ├── neumorphic_app_bar_builder.dart
    │           ├── neumorphic_button_builder.dart
    │           ├── neumorphic_card_builder.dart
    │           ├── neumorphic_checkbox_builder.dart
    │           ├── neumorphic_dialog_builder.dart
    │           ├── neumorphic_host_builder.dart
    │           ├── neumorphic_list_row_builder.dart
    │           ├── neumorphic_nav_bar_builder.dart
    │           ├── neumorphic_progress_builder.dart
    │           ├── neumorphic_scaffold_builder.dart
    │           ├── neumorphic_segmented_builder.dart
    │           ├── neumorphic_select_builder.dart
    │           ├── neumorphic_shell_builder.dart
    │           ├── neumorphic_slider_builder.dart
    │           ├── neumorphic_switch_builder.dart
    │           ├── neumorphic_tab_bar_builder.dart
    │           ├── neumorphic_tab_view_builder.dart
    │           ├── neumorphic_text_field_builder.dart
    │           └── neumorphic_toast_builder.dart
    ├── live-uikit-neumorphic.md
    └── test/
        ├── adapter/
        │   └── neumorphic_contract_test.dart
        ├── theme/
        │   └── neumorphic_theme_test.dart
        ├── widgets/
        │   ├── neumorphic_native_controls_test.dart
        │   └── stub_router.dart
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
| `adapter/` | Implements `LanguageAdapter`, declares `neumorphicCapabilities` and `neumorphicSurfaces`, and exports the registration entry points |
| `theme/` | Translate the resolved design token into a `NeuThemeData` and scope |
| `widgets/` | Build every control of the contract, plus the app host and the shell, from the core specifications using `flutter_neumorphic_ui_kit`'s widgets and faces |
| `interaction/` | (Optional) Map keyboard, focus, and TV-specific behavior |
| `icons/` | (Optional) Map supported semantic icons to Neumorphic icons |
| `diagnostics/` | (Optional) Report an effect the device cannot afford and adapter errors |
| `test/` | Verify contract compliance, the capability and surface declarations, and each builder's mapping |
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

Because PureLive uses a Pub workspace, `live_uikit` is resolved through the workspace rather than a hard-coded path. Keep the `flutter_neumorphic_ui_kit` version aligned with the resolved workspace dependency before merging; `^1.0.1` is what the workspace resolves today.

Beyond the two packages, the adapter uses Flutter's own `widgets.dart` primitives — `WidgetsApp` for the host, `PageView` for the tab view, `Focus`, `GestureDetector`, `SafeArea` and `Semantics` where the library has no equivalent concept — and enters `material.dart` only for the `Icons` catalogue, which is a value rather than a widget. No Material control is constructed by these builders.

The adapter should not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation.

## 6. Public API

The public entry point exposes only the adapter's registration API.

```dart
// lib/live_uikit_neumorphic.dart

library;

export 'package:live_uikit_neumorphic/src/adapter/neumorphic_registration.dart';
```

That registration file is the entire public surface:

| Symbol | Kind | Purpose |
|---|---|---|
| `createNeumorphicAdapter()` | function | Builds a `LanguageAdapter` for the composition root |
| `neumorphicAdapter` | `const LanguageAdapter` | The ready-to-register const adapter instance |
| `neumorphicAdapterId` | `const String` | The stable runtime id, `neumorphic` |

The concrete `NeumorphicLanguageAdapter` stays inside `src/`: the registration file hands it back typed as the core's `LanguageAdapter`, so no caller can depend on a Neumorphic-specific entry point. Do not export internal widget builders, the theme mapper, or `flutter_neumorphic_ui_kit` types. This package adds no localization delegates; the public API is registration only.

## 7. Adapter contract

`NeumorphicLanguageAdapter` implements the core interface directly — there is no adapter base class to extend:

```dart
class NeumorphicLanguageAdapter implements LanguageAdapter {
  const new();

  @override LiveDesignLanguage get language => LiveDesignLanguage.neumorphic;
  @override String get id => 'neumorphic';
  @override String get displayName => 'Neumorphic';
  @override LiveUiCapabilities get capabilities => neumorphicCapabilities;
  @override LiveUiSurfaceCapabilities get surfaces => neumorphicSurfaces;
}
```

The core contract is `abstract interface class LanguageAdapter`. Its members are `language`, `id`, `displayName`, `capabilities`, `surfaces`, `wrap(context, token, child)`, the seventeen control builders `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`, `select`, `tabBar`, `scaffold`, `appBar`, `listRow`, `navBar`, `toast`, `dialog` and `tabView`, and the two structural members `appHost(context, LanguageHostSpec)` and `shell(context, LanguageShellSpec)`. `LiveUiControl` names exactly those seventeen controls and `LiveUiSurface` exactly the two surfaces. This adapter overrides every one of them: each control delegates to its builder under `widgets/`, the theme to `theme/`, and the surfaces to `NeumorphicHostBuilder` and `NeumorphicShellBuilder`. No business state lives in the adapter.

Do not create a second competing adapter interface inside `live_uikit_neumorphic`.

### Adapter identifier

Use one stable identifier everywhere:

```text
neumorphic
```

The identifier is a machine-readable value exposed by `id` and `neumorphicAdapterId`, not a localized label. Do not use `flutter_neumorphic_ui_kit`, `Neumorphic`, or a platform-dependent value as the runtime style ID. `displayName` is `Neumorphic` and is only for the selector UI.

### Capability declaration

`neumorphicCapabilities` declares all seventeen controls and `neumorphicSurfaces` declares both structural surfaces. The declaration is checked, not trusted: `LiveUiResolver.requireControl` and `requireSurface` raise `LiveUiCapabilityException` for anything a language claims without an override behind it, and `LiveUiResolver.resolve` raises `LiveUiResolutionException` for a language this build registered no adapter for. Nothing stands underneath an adapter, so this package's obligation is to keep the declaration and the builders saying the same thing (§17).

The realized mapping, control by control. **Mapped** means the library ships the widget; **composed** means the builder assembles the control from that library's own `NeuContainer` faces and `NeuTheme.of` depth, radius and accent because the library has no widget for that job:

| Control | How this adapter renders it | Kind |
|---|---|---|
| Button | `NeuButton`; its content — label, leading glyph, loading bar, icon-only glyph — built from the library's parts | Mapped |
| Card | `NeuCard` with the token padding plus a gesture layer when a tap or long press was given | Mapped |
| Text field | `NeuTextField`, forwarding the caller's controller, focus node and callbacks | Mapped |
| Switch | `NeuSwitch`, fully controlled by the spec | Mapped |
| Checkbox | `NeuCheckbox`; the optional trailing label is composed here, since the box paints none | Mapped |
| Slider | `NeuSlider`, clamped to the spec range | Mapped |
| Progress | `NeuProgressBar` — already a recessed trough with a domed fill; the caption label is appended | Mapped |
| App bar | `NeuAppBar` — a `NeuContainer` plane around a `NavigationToolbar`; only its `bottom` slot is handled outside the widget | Mapped |
| Segmented | A `pressed` dish of cells with the chosen one domed `convex` | Composed |
| Select | A field plane plus an option dish that opens inline | Composed |
| Tab bar | A row of `NeuContainer` cells, the chosen one domed | Composed |
| Scaffold | A flat plane at zero depth and zero radius with the dispatched bars stacked on it | Composed |
| List row | A flat plane that becomes a pressed dish when selected | Composed |
| Nav bar | A docked slab whose active destination presses *into* it | Composed |
| Toast | A raised plane; the core keeps the overlay, the fade and the timer | Composed |
| Dialog | A `convex` panel at twice the theme depth; the route, the barrier and the scale-in are the core's | Composed |
| Tab view | Flutter's `PageView` inside a `concave` well — the inverse of the domed tab | Composed |

Both structural surfaces are declared apart from the controls, because owning one says nothing about the other. This adapter owns both: `appHost` is a `WidgetsApp` with `NeuTheme` installed above the routed tree, and `shell` is a vertical column composed from the same container faces. The library ships no application widget, no rail, no sidebar and no `NavigationView`, and its one navigation widget — `NeuBottomNav`, a horizontal floating pill that asserts two items, demands a non-null callback, wraps itself in a `SafeArea` and fires `HapticFeedback` — can carry neither the nav bar nor the shell contract (§9).

Every builder's own doc comment states which of the two kinds it is and names the spec fields it could not map (§9). `neumorphic_contract_test.dart` asserts the declaration matches the overrides, so the two cannot drift.

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

Each control builder converts a core specification into a soft shape — extruded for raised, inset for sunken — rendered either with the `flutter_neumorphic_ui_kit` widget that already is that control, or, where the library has none, assembled from that library's own `NeuContainer` faces and `NeuTheme.of` values. Builders must not reach into another widget library for a surface: `flutter/material.dart` is entered only for the `Icons` catalogue, a value rather than a widget, and no Material control is constructed here. (The library itself is built on Material primitives — `NeuAppBar` wraps a `NavigationToolbar` — and that stays inside the dependency.)

### Button — mapped (`NeuButton`)

- Built by `NeumorphicButtonBuilder` as a `NeuButton`.
- Press enabled-ness is computed in the builder: enabled, not loading, and holding a callback — `NeuButton` reads a null `onPressed` as its inert state.
- The button's content is composed here from the library's own parts: the label, an optional leading glyph, an indeterminate `NeuProgressBar` while loading (the library ships no button spinner), and the bare glyph of an icon-only button, whose empty label is never painted.
- Padding is driven by the token (`theme.button.paddingInline`, `theme.token.scale.sizes.sm`).
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` in the core's language-neutral `LiveTooltip`; `NeuButton` exposes neither slot, and it has no focus parameter of its own, so `focusNode`/`autofocus` are recorded as unmappable (§15).
- Do not place business actions inside the adapter.
- `iconOnly` needs no surface of its own: the builder paints the glyph alone, with the
  tooltip (or the label) as its `semanticLabel`, so a textless button arriving from
  `LiveIconButton` never paints the empty label its caller passed to satisfy the contract.
- `selected` is **not mapped by this adapter**. A soft surface states an active thing
  with depth, and `NeuButton` has no selected affordance to take; reproducing a tinted
  toggle would mean hand-painting an overlay on top of the library's widget. Recorded
  as the documented remainder of `docs/decisions/0004` (§15).
- `style` is **not mapped by this adapter either**. Its button is the library's own
  widget and paints its own surface; applying a caller's `Style` to it would mean
  hand-painting an overlay over that widget — the same trade this section already
  refuses for `selected`. A language whose button has no surface of its own can take
  the field; this one declines it (`live-uikit.md` §11).

### Card — mapped (`NeuCard`)

- Built by `NeumorphicCardBuilder` as a `NeuCard` — the soft surface is the card's identity.
- Honors `padding` from the spec, else the token padding with the `dense` step applied, and wraps content in a gesture layer only when `onTap` or `onLongPress` is present; `NeuCard` takes no callbacks itself.
- `selected` and `bordered` have no soft-surface equivalent — the card is its shadow, not a border or fill — so they are left to the library's own pressed state rather than faked with an outline (§15).
- Preserve content, padding, and click semantics; do not assume every card is interactive.

### Text field — mapped (`NeuTextField`)

- Built by `NeumorphicTextFieldBuilder` as a `NeuTextField`.
- Passes the caller's `controller`, `focusNode`, hint, error, obscuring, line count, keyboard type and action, leading/trailing slots, enable state and both callbacks straight through; the field owns its controller when the spec supplies none. The inline `Style` layers onto the token body text.
- Do not create a second controller or silently own its lifecycle. `readOnly` has no `NeuTextField` parameter and is recorded as unmappable (§15) rather than emulated by dropping the callback, which would change what the field means.

### Switch — mapped (`NeuSwitch`)

- Built by `NeumorphicSwitchBuilder` as a `NeuSwitch`.
- Fully controlled by the spec value; disabled by dropping the callback when `enabled` is false, which is how this library draws an inert switch.
- Do not introduce local persistent state.

### Checkbox — mapped (`NeuCheckbox`)

- Built by `NeumorphicCheckboxBuilder` as a `NeuCheckbox`.
- The optional trailing label is composed here as a `Row` in the token's body text role, because the library's checkbox paints no label of its own.
- Preserve checked/unchecked and disabled semantics; a null `onChanged` (or `enabled: false`) reaches the library as null, which is what renders the box disabled. The `bool?`→`bool` bridge closure exists only when the caller can be called back — a closure that swallowed the value would leave a live-looking control (§15).

### Slider — mapped (`NeuSlider`)

- Built by `NeumorphicSliderBuilder` as a `NeuSlider`.
- Clamps the value to `[min, max]` and disables by dropping `onChanged` when `enabled` is false.
- Handle invalid ranges according to the core validation contract.

### Progress — mapped (`NeuProgressBar`)

- Built by `NeumorphicProgressBuilder` as a `NeuProgressBar`, the library's own linear bar, which already draws the Neumorphic reading of progress: a recessed trough with a domed fill at the theme's accent.
- `value` goes to the widget clamped to `0..1`, because the widget asserts the range; `height` sizes the track and `barColor` overrides the fill, defaulting to the theme accent.
- `showLabel` has no counterpart — the library's bar carries no text — so the percentage is appended beside the bar in the token's caption role, and a label asked for on an indeterminate bar is dropped rather than invented.
- A null `value` is the library's own pulse, which repeats until the widget leaves the tree; the contract asks no timer of the language, so nothing here disposes it.

### App bar — mapped (`NeuAppBar`)

- Built by `NeumorphicAppBarBuilder` as a `NeuAppBar`: a `NeuContainer` plane around a `NavigationToolbar` carrying the leading widget, the title and the trailing actions, and taking the status-bar inset itself.
- It is an ordinary `StatelessWidget` that also implements `PreferredSizeWidget`, so it renders inline in a page and needs neither a Material frame nor an application shell above it.
- `leading`, `actions`, `centerTitle` (whose null default of `true` is this style's centred bar), `height` (null taking the library's 56) and `background` → `baseColor` all map straight through; an empty action list is passed as null so the toolbar reserves no slot.
- `bottom` is the one field with no usable slot: the library types it as `PreferredSizeWidget?` while the contract's bottom strip is any dispatched widget, and the Neumorphic tab strip is a `Row` of cells with no preferred size. The strip is therefore stacked under the bar in a column on the same plane (§15).
- The title is left as a bare `Text` in the bar's own type, with ellipsis added so a long title cannot overflow the toolbar.

### Segmented — composed

- Built by `NeumorphicSegmentedBuilder`. The library ships no segmented track, so the group is a `NeuContainer` in `pressed` — a recessed dish — holding one cell per segment, where the chosen cell is the same plane pushed back out as a `convex` dome at the theme depth.
- That is the library's own idle/pressed pair read as a selection rather than as a touch; the selected label takes `NeuThemeData.accentColor` the way its bottom bar tints the active destination. This style states a choice with depth, not with a colour fill.
- Radii come from the theme: the track takes `NeuThemeData.borderRadius` and a cell takes that radius minus the track's inset, so the dome nests inside the dish instead of clipping it.
- `expand` gives every cell an equal share of the row; a disabled group is cells with no callbacks in the token's disabled text role, which is the library's inert state.

### Select — composed

- Built by `NeumorphicSelectBuilder`. The library carries no dropdown, so the field is the library's own interactive plane — `flat` when shut, `pressed` once open, because a recessed surface is how this style says "you are inside me" — and the option list is a `concave` dish of cells under it, the chosen value pushed back out as a `convex` dome with the theme's accent on its label.
- The list opens *inside the tree* rather than in a popover on purpose: the core owns the overlay and asks the language for a control body it can place anywhere, so this widget must render with no `ScaffoldMessenger`, no `Navigator`, no overlay controller and no animated ancestor. The library offers no anchored popover, and a Material one would be another language's surface borrowed into a Neumorphic page.
- The cost is stated, not hidden: the caller reserves the room the open list takes, and the list closes on a choice or a second tap on the field.
- `placeholder` is the shut field's text when nothing is selected; `enabled: false` or a null `onChanged` leaves a field that greys and will not open. The value is matched by identity against `items`, so an off-list value reads as "nothing selected" rather than as a phantom row.

### Tab bar — composed

- Built by `NeumorphicTabBarBuilder`. The library's only strip widget is `NeuBottomNav`, and it cannot be this control: it asserts at least two items (a strip may render one, or none while a router is still filling the list), its `onTap` is a non-null `ValueChanged<int>` where a disabled strip is a null callback, every item must carry an icon *widget* while `LiveTab.icon` is an optional glyph, and it wraps itself in `SafeArea` plus an outer margin because it is a docked bottom bar rather than a strip a page can place under a title.
- The strip is therefore one `NeuContainer` cell per tab on the library's own plane, the selected one raised as a `convex` dome at the theme depth and labelled in the theme accent, the others left flat — the same depth-plus-accent reading the library uses for its own active destination, and the reason a Neumorphic tab needs no ink bar.
- `spacing` is honoured as the gap between cells; a disabled strip keeps its labels and loses its callbacks.

### Scaffold — composed

- Built by `NeumorphicScaffoldBuilder`. The library ships no page frame — every widget in it is a surface a caller places, and the only frame-shaped thing reachable from the dependency is Material's own `Scaffold`, which would hand the page back its canvas colour, its floating-action placement rule and its keyboard-resize policy. The frame is a `NeuContainer` on its default flat face at zero depth and zero radius: `baseColor` filling the slot with no shadow pair behind it, i.e. the page surface rather than a raised card.
- It renders inline: no Material `Scaffold`, no `Navigator`, no `ScaffoldMessenger`, no overlay controller. The `NeuTheme` the plane and the bars read is installed above the page by `wrap`, so the page is themed by the token rather than by whatever application shell sits outside it.
- `appBar` and `bottomBar` are stacked above and below the body by flex rather than by `PreferredSizeWidget.preferredSize`, which is what lets this bar's own `bottom` strip work without one; `body` is the only thing that scrolls or grows and keeps the core frame's safe-area policy.
- `avoidKeyboard`: no frame in this library resizes, so the policy is carried out here — the body takes the view's bottom inset as padding and the floating action rides the same inset; `false` ignores the inset.
- `extendBodyBehindAppBar` makes the body `Positioned.fill` with the bar pinned to the top edge of the plane, and is ignored when there is no bar to run under.
- `floatingActionButton` has no slot in the library or the plane, so the core's overlay geometry places it at the trailing bottom corner, inset by `LiveEnvironmentScope`'s page padding or the token's `md`.
- `background` maps onto the plane's `baseColor` rather than onto a fill painted over it: overriding a surface in this style means changing the surface. Null keeps the theme's base colour, which the token already drove.

### List row — composed

- Built by `NeumorphicListRowBuilder`. The library ships no list tile, and `NeuCard` is the wrong one for a row — it is an embossed plane whose whole job is to stand apart from the page. An idle row is therefore a flat plane at zero depth, which is the page itself.
- Selection is stated the way this style states every active thing: with depth, not with a fill. A selected row sinks into `pressed` and lifts its title in the theme accent — the same dish the nav bar's active destination and the segmented track use. The token's `selectedBackground` has no place on a soft surface and is not painted.
- `leading`/`trailing` sit before and after the text column, which takes the remaining width; `subtitle` is the second line in the token's secondary role.
- `onTap` and `onLongPress` both go into one gesture layer over the whole plane, so an `onTap`-only caller is not stripped of a long press and a long-press-only caller keeps its callback.
- `focusNode` and `autofocus` are honoured by a `Focus` wrapper — the library has no concept of focus at all — and Space/Enter/NumpadEnter/Select activate the row the way a tap does. A row with no `onTap` cannot take focus.
- `divided` draws the hairline itself, at the token's line width and the list-row divider colour, because a Neumorphic surface has no divider of its own to borrow.

### Nav bar — composed

- Built by `NeumorphicNavBarBuilder`. `NeuBottomNav` looks like this control and is not it, for four reasons tested against the widget: it asserts `items.length >= 2`, its `onTap` is non-null, it hard-wraps itself in a `SafeArea` plus an outer margin so a frame that already reserves the bottom inset gets it twice, and it reaches for `HapticFeedback` on every change — which the contract does not ask for and a desktop build would feel as a wrong device.
- The bar keeps the one thing `NeuBottomNav` gets right about this style: the active destination is a **dish**, not an underline. A full-width `NeuContainer` on its flat face, raised at the theme depth, holds one equal-share cell per destination, and the chosen cell sinks into `pressed` with its glyph and label in the theme accent.
- That is also what separates this control from `tabBar`: the strip domes its chosen cell and floats free of any bar, while a nav bar is a docked slab whose chosen cell presses *into* it.
- `enabled: false` is the library's inert state — the cells keep their glyphs and labels and lose their callbacks.

### Toast — composed

- Built by `NeumorphicToastBuilder`, and only the surface. The library ships no transient message, and `LiveToast.show` in the core keeps the overlay, the fade and the removal timer because every language wants the same behaviour there.
- The returned widget renders inline: no `ScaffoldMessenger`, no `Navigator`, no overlay controller, no animated ancestor. It is a raised `NeuContainer` plane with the status glyph and the message.
- `duration` and any placement are therefore unread here — the timer and the position are the core's. The glyph's colour is the token's status role (`info`/`success`/`warning`/`error`), because the token decides that a warning looks like this app's warning in every language; the plane, its radius and its depth are the library's own `NeuThemeData`.

### Dialog — composed

- Built by `NeumorphicDialogBuilder`, and only the surface. The library ships no modal and nothing in it owns a route, a barrier or a scale-in; those are the core's `showLiveDialog`, which already dims the barrier, fades and scales, and frames the child it is handed (`Center → Padding → ConstrainedBox(maxWidth)`). This builder therefore starts no route of its own.
- `dismissible` is unread here — it is the core's barrier knob, not something the surface draws.
- What the language decides is what a floating panel looks like, and the soft answer is depth: a `convex` panel at *twice* the theme depth, so it reads as lifted clear off the page. That is the opposite gesture to `navBar`'s sunk cell and the same dome-when-active reading `tabBar` uses, at panel scale.
- The corner and the base are the theme's; the heading rides in the token's title role, the glyph in the theme's accent, and `actions` — already-built, dispatched controls — are laid out right-aligned on one row so a dialog's buttons match the language rather than being re-picked here.

### Tab view — composed

- Built by `NeumorphicTabViewBuilder`. The library ships no page view, so the pages are slid with Flutter's own `PageView` — a `widgets.dart` scrollable, not a Material render widget — because a tab view swipes for a reason and a view that refused the gesture would be less capable than the strip that drives it.
- The surface it swipes across is the language's own: a `NeuContainer` on its recessed (`concave`) face, a well the content drops into, at the theme's base colour, radius, depth and distance. That recess is the whole point of the split from `tabBar`, which *domes* its chosen cell — press the dome, see the plate — so a Neumorphic page can tell its strip from its view by touch alone.
- `index` is the caller's and is never copied: the view animates to whatever index it is handed, and `onIndexChanged` reports a viewer-driven swipe. A null `onIndexChanged`, or a single page, leaves the view non-interactive. `duration` is the caller's too, since the contract hands the change length to whoever owns the index.

### Structural surfaces

- `flutter_neumorphic_ui_kit` ships no application widget — it is a theme plus components, and nothing in it owns a route, a title or a locale — so the host is Flutter's own `WidgetsApp.router` with `NeuTheme` installed by the host's `builder`, above the routed tree. That is a real host, not a placeholder: a Material application host would decide the page transitions, the scroll physics and the dialog barrier no matter which controls were drawn under it. `color` is the token's accent, and `LanguageHostSpec.localizationsDelegates` carries the chrome strings and text behaviours that no Material application widget is there to supply.
- The shell is composed for the same reason `navBar` and `tabBar` are: the library has no rail, no sidebar and no `NavigationView`, and its one navigation widget is a horizontal floating pill that asserts two items, demands a non-null callback, adds its own `SafeArea` and margin and fires `HapticFeedback`. The rail form is one full-height `NeuContainer` on its flat face carrying a cell per destination, the chosen one sunk into `pressed` in the theme's accent — the same reading as the nav bar's slab, turned vertical.
- `placement` is read the way the contract states it: `rail`, and `adaptive` with room for a pane, compose the column at `LiveEnvironmentScope`'s rail width (or `LiveSizing.railWidth` when no environment scope sits above); `bottom` hands the strip back through this adapter's own `navBar` rather than drawing it twice; `none`, or fewer than two destinations, gives the frame back to the page.
- Three faces, three readings, kept distinct on purpose: `tabBar` domes its chosen cell and floats free of any bar, `navBar` is a docked horizontal slab whose chosen cell presses *into* it, and the shell is that same pressed reading drawn as a vertical column beside the page. A Neumorphic window can tell its tabs from its bar from its shell by touch, with no Material control in the subtree.
- `trailing` has a slot in the composed column, pinned under a `Spacer`; the docked slab shares its width equally between destinations and has none, so the bottom form drops the footer rather than smuggling it in as another destination. A disabled destination keeps its cell so the column does not shift when it opens, greys to the token's disabled text role and loses its callback — the `NeuContainer` has no disabled state to ask for.
- `LanguageShellSpec` is not a control and never reaches `capabilities`; ownership is declared in `neumorphicSurfaces`, and `LiveUiResolver.requireSurface` raises `LiveUiCapabilityException` if the declaration and the method ever disagree (§17).

### Control mapping rule

Builders must map semantic intent, not inspect business page types. A button builder receives `variant`, `size`, and state; it must not special-case login pages, playback pages, or plugin settings screens. Where the library's widget has no parameter for that intent, the builder says so instead of inventing one: `NeuButton` exposes no emphasis or size step, so this language's button takes its geometry from the token padding and leaves `variant`/`size` unstated (§9 Button), and its `enabled`/`loading`/`onPressed` triad is what the widget's null `onPressed` can express.

## 10. Runtime registration

The application composition root registers the adapter during startup using the exported API:

```dart
LanguageRegistry registerUiAdapters() => const LanguageRegistry(
  adapters: {
    LiveDesignLanguage.neumorphic: neumorphicAdapter,
    // …plus every other language this build claims to support
  },
);
```

`LanguageRegistry` takes the adapter map once, as a const value; there is no `register` call to make and no fallback slot to fill. `createNeumorphicAdapter()` is there for a root that cannot be const. Both entry points yield a `NeumorphicLanguageAdapter`, keyed by `LiveDesignLanguage.neumorphic` and `neumorphicAdapterId` (`neumorphic`).

The composition root is responsible for registering adapters, loading the user's style preference, selecting the active language, providing persistence, and coordinating runtime theme changes. `live_uikit_neumorphic` must not register itself through global static initialization or require the business layer to import it.

### Registration and resolution failures

A design language is either registered in this build or it is not, so the failures at this boundary are raised rather than reported as a degraded render:

- `LiveUiResolutionException` — `LiveUiResolver.resolve(language)` was asked for a language this build registered no adapter for. A startup-level composition fault: nothing stands underneath an adapter, so the alternative to throwing would be a window painted by a library the user did not choose.
- `LiveUiCapabilityException` — `requireControl` or `requireSurface` was handed a declaration the adapter cannot serve, i.e. `neumorphicCapabilities`/`neumorphicSurfaces` claiming a member `NeumorphicLanguageAdapter` does not override. Neither case arises for this language as written; the exception exists so a future drift fails loudly instead of quietly.
- `unsupportedEffect` — the one member of `LiveUiDiagnosticCode`, and the only thing the runtime still reports as a diagnostic: the environment cannot afford an effect (blur, backdrop filter, TV focus), so a verified degraded visual stands in (§13/§15).

Diagnostics reach the host through the `LiveUiDiagnosticSink`, never through a concrete logging package. Selecting Neumorphic draws Neumorphic or fails loudly; it never silently becomes another style.

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

The swap is whole-language and whole-window: every one of the seventeen controls, the app host and the shell come from this adapter together, so a Neumorphic page never mixes another library's surface into the subtree, and the caller's controllers, focus nodes and text survive the change (§16).

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

The `interaction/` module is not yet created; when keyboard, focus, and TV mapping is implemented, add it there and cover it with tests. Do not assume desktop keyboard behavior guarantees Android TV D-pad compatibility. What is built today is inside the builders: `listRow` wraps its plane in a `Focus` and activates on Space/Enter/NumpadEnter/Select because the library has no focus concept of its own (§9 List row), and the shell marks its chosen destination with `Semantics(selected:)` (§9 Structural surfaces). Where the device cannot afford a focus effect at all, report the `unsupportedEffect` diagnostic and stand a verified degraded visual in — do not drop focus silently.

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

The style claims nothing about the operating system: every platform above runs the same `WidgetsApp` host under `NeuTheme` (§9 Structural surfaces), so a Neumorphic window's page transitions, scroll physics and dialog barrier are the language's own on Linux as much as on Windows, and platform integration stays the application's job rather than this adapter's.

## 14. Localization and accessibility

`live_uikit_neumorphic` adds no localization delegates. It uses the localization configuration supplied by `live_uikit` and the application composition root.

Because the host this adapter builds is a `WidgetsApp` rather than a Material or Cupertino application widget, the chrome strings and text behaviours arrive through `LanguageHostSpec.localizationsDelegates` — the composition root passes the core's `liveLocalizationsDelegates` for every language, and this package appends nothing of its own (§9 Structural surfaces).

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints from the specs.
- Avoid introducing a second, conflicting locale source.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast against the base surface, and touch target sizing.

Neumorphic low-contrast soft surfaces are an accessibility risk; verify text and control contrast on both light and dark base colors.

## 15. Error handling and diagnostics

Failures at this boundary split into two kinds, and the distinction is the whole point of §10.

A language or a capability that cannot be served is a fault, not a diagnostic:

- `LiveUiResolutionException` — the selected language has no registered adapter in this build.
- `LiveUiCapabilityException` — `neumorphicCapabilities` or `neumorphicSurfaces` claims a member this adapter does not override. Neither arises today; `neumorphic_contract_test.dart` and `tool/check_architecture.ps1` exist so a drift cannot ship (§17).

What is *reported* through the core's diagnostic channel is one thing only:

- `unsupportedEffect` — the device cannot afford an effect the style would otherwise use (backdrop blur, a focus glow, a shadow pair on a low-power target), so a verified degraded visual stands in.

A field the library cannot state is neither of those. It is documented where it is refused — in the builder's own doc comment and in §9 — and the control renders without it: `readOnly` on the text field, `selected`/`bordered`/`focusNode`/`autofocus` on the card, `focusNode`/`autofocus`/`selected`/`style` on the button, and `focusNode`/`autofocus` on the switch and the checkbox — focus is not a concept any of those library controls carry — plus `duration` and placement on the toast, `dismissible` on the dialog, and `trailing` on the bottom form of the shell. None of them is emulated by changing what the spec means, and none of them is handed to another design language. (The app bar's `bottom` is not in that list: the strip is stacked under the bar rather than dropped, because the field is real and only the library's slot type is not — §9 App bar.)

Use the diagnostics contracts from `live_uikit` (`LiveUiDiagnostic`, `LiveUiDiagnosticCode`, and `LiveUiDiagnosticSink`). Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- Unaffordable effects degrade through `unsupportedEffect`, with the stand-in verified.
- Invalid control data follows core validation rules.
- Programming errors are not swallowed.
- Diagnostics avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

### Contract tests (`test/adapter/neumorphic_contract_test.dart`)

`test/adapter/neumorphic_contract_test.dart` verifies:

- Stable id (`neumorphic`), `displayName` (`Neumorphic`), and `language` (`LiveDesignLanguage.neumorphic`).
- The capability set equals `LiveUiControl.values` — every control the resolver can dispatch — so a control added to the interface cannot go unhandled here without failing this expectation, and the surface set equals exactly `appHost` and `appShell`.
- Through `LiveUiResolver` over a `LanguageRegistry`: `resolve` hands back this adapter, `requireControl` passes for each of the seventeen controls, and a language the build registered no adapter for throws `LiveUiResolutionException`.

### Theme tests (`test/theme/neumorphic_theme_test.dart`)

- Base surface, accent and radius follow the resolved token (§8.1), and a dark token
  yields a different base surface than the light one (§8.3).
- Toggling brightness re-skins through `wrap`, with no restart.
- The slider's rendering is asserted in `test/widgets/`; the builder clamps the value to
  the spec range before handing it to the library, but no test here pins that clamping
  yet, and the same gap applies to the progress bar's `0..1` clamp.

### Widget tests (`test/widgets/neumorphic_native_controls_test.dart`)

- Button: `onPressed` fires when enabled, input is rejected while loading, and `expand`
  plus `tooltip` wrap the control.
- Text field: the caller's controller survives, the rest of the caller state passes
  through, and the caller's `FocusNode` is the node that takes focus (§9/§16).
- Switch, checkbox, slider: reporting the next value, a null callback disabling the
  checkbox instead of faking one, and the card and slider rendering natively.
- Card: `dense` and an explicit `padding` both reach the surface, and a tap, a long press
  and an `onLongPress`-only caller each keep their callback.
- The composed controls are asserted as compositions: the segmented track domes its chosen
  cell and reports the index, the select opens inline and reports a typed value, the tab
  strip is a row of cells rather than the library's bottom nav, and the toast draws this
  package's pill inside the overlay the core keeps.
- Progress maps to the library's bar and carries the caption label it appends.
- Chrome: the page frame is the library's own plane rather than a frame from another
  language, it extends the body behind the bar and keeps the keyboard clear, the bar is
  `NeuAppBar` with the dispatched strip stacked beneath the title, a row is a composed
  plane that dishes when selected and hands its own `FocusNode` to the focus tree, and a
  destination bar is composed rather than the library's bottom nav. A page mixing these
  controls is asserted to hold no renderer from outside this dependency.
- Surfaces: the rail form is a composed column of the library's faces, a disabled
  destination keeps its cell and takes no tap, a `bottom` request hands the strip back
  through this package's own `navBar`, one destination is not a choice so the shell stands
  aside, and the tree is hosted by `WidgetsApp` under `NeuTheme`. The dialog is a raised
  surface on the core's route and the tab view swipes the caller's index inside a recessed
  well.

Not covered yet: accessibility semantics, layout under narrow versus wide constraints, and
anything a `NeuTheme` scope decision needs on a real device — the hardware half §19 still
keeps open.

### Integration tests (`test/integration/neumorphic_style_switching_test.dart`)

- Every `LiveUiControl` the adapter declares resolves through `LiveUiResolver` to this adapter, `requireControl` passes for each of them, and the diagnostic sink records no control or surface downgrade at all — this language answers the whole contract, so the expected report is empty.
- Re-rendering the same language keeps `neu.NeuButton`, `NeuCard`, `NeuTextField` and `NeuSwitch` on screen and leaves the caller's controller text untouched; the render path never left this adapter, so nothing resets (§11).
- The segmented control is this package's own composed dish-and-dome track, and it stays callable across a re-theme rather than changing hands to another renderer.

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
- The declared capabilities match the control methods actually overridden, and the declared surfaces match the surface overrides; both sets are compared by the guard and asserted again by the contract test.
- Every `package:flutter_neumorphic_ui_kit/` import inside this package uses the `as neu` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `neumorphicCapabilities`: a control named in
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
- Registration API (`createNeumorphicAdapter`, `neumorphicAdapter`, `neumorphicAdapterId`) exported.
- Contract and resolution tests in place.

### Phase 2 — Theme integration ✅

- `NeumorphicThemeMapper`, `NeumorphicThemeBuilder`, and `NeumorphicThemeScope` wired through `wrap`.
- Verify brightness/accent tracking and runtime theme updates.

### Phase 3 — The whole contract ✅

Implemented and behind the builders, and declared in `neumorphicCapabilities`:

1. Button, Card, Text field, Switch, Checkbox, Slider — the library's own widgets
2. Progress (`NeuProgressBar`) and App bar (`NeuAppBar`) — also the library's own widgets
3. Segmented, Select, Tab bar, Scaffold, List row, Nav bar, Toast — composed from `NeuContainer` faces and `NeuTheme.of` values
4. Dialog and Tab view — composed surfaces, the route and the overlay staying with the core

Each stage is covered by a widget test driven through the public `Live*` control (§16).

### Phase 3b — Structural surfaces ✅

- `appHost` on `WidgetsApp` with `NeuTheme` above the routed tree, and `shell` as the composed column that hands its bottom form back through `navBar`.
- Both declared in `neumorphicSurfaces` and asserted by the contract test and the architecture guard.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: caller state, callbacks and the spec fields the library carries are asserted in `test/widgets/`.
- Open, needs hardware: focus visibility on soft surfaces and Android TV D-pad.
- Add the optional `interaction/` module for keyboard, focus, and TV mapping.
- Test Android TV D-pad behavior and focus visibility on soft surfaces.
- Validate contrast and semantics.
- Document the `unsupportedEffect` degradation for shadow-heavy surfaces.

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Integration tests for style switching are in `test/integration/` (§16); a switch measured against a sibling adapter belongs to the application suite, because §3.3 forbids the dependency here.
- Verify all claimed platforms, including the low-power/TV shadow-degradation path.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `flutter_neumorphic_ui_kit` only for its core integration.
- [x] It implements the core `LanguageAdapter` interface directly; the contract is an `abstract interface class`, there is no adapter base class to extend, and every member of it is answered in this package.
- [x] It uses the stable adapter id `neumorphic` with `displayName` `Neumorphic`.
- [x] `neumorphicCapabilities` declares all seventeen controls the resolver dispatches, and `requireControl` passes for each one.
- [x] Eight of them take a `flutter_neumorphic_ui_kit` widget and nine are composed from that library's own container faces and `NeuTheme` values.
- [x] `neumorphicSurfaces` declares both structural surfaces, and both are answered here: a `WidgetsApp` host carrying `NeuTheme`, and a composed shell column.
- [x] It maps the resolved `DesignToken` into `NeuThemeData` and applies it through `wrap`.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It exports only the registration API and adds no localization delegates.
- [x] It does not create a nested application shell unnecessarily.
- [x] Runtime switching preserves business state.
- [x] Neumorphic surfaces degrade acceptably when shadows cannot be afforded (`unsupportedEffect`).
- [ ] Keyboard, accessibility, and TV focus behavior are tested. What is tested today is that a caller's `FocusNode` reaches the library's own field focus tree and that a row activates from it (§16); focus visibility on the soft surfaces, D-pad traversal and screen-reader announcements still need hardware.
- [x] Diagnostics use the core's own contract and sink; `unsupportedEffect` is the only member of `LiveUiDiagnosticCode`.
- [x] A language this build registered no adapter for, and a capability declared without an override behind it, are both raised as exceptions rather than reported as downgrades.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_neumorphic` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, the public controls, the theme model, and runtime selection, and it resolves a language through the registry or raises.
- `live_uikit_neumorphic` implements that contract in full: eight controls taken from a `flutter_neumorphic_ui_kit` widget, nine composed from that library's own container faces and theme values, and both structural surfaces answered here.
- `flutter_neumorphic_ui_kit` supplies the underlying soft-UI widgets and `NeuTheme` facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive add or replace UI styles — including the shadow-driven Neumorphic look and its low-power degradation — without forcing business packages to know which UI library is currently rendering their controls.
