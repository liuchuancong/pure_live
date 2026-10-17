# `live_uikit_cupertino` Architecture and Integration Specification

- **Package:** `live_uikit_cupertino`
- **Parent package:** `live_uikit`
- **Implementation library:** `cupertino_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_cupertino` is the Cupertino UI adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `cupertino_ui` controls and Cupertino-specific visual behavior. `cupertino_ui` is a fork of Flutter's Cupertino widgets and is selected through the `LiveDesignLanguage.cupertino` value. This adapter implements the whole `LanguageAdapter` contract itself — every control and both structural surfaces — and must not implement business pages or duplicate the core theme system.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_cupertino
       |
       v
cupertino_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `cupertino_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`. The `LanguageAdapter` interface, the spec types, `LiveUiCapabilities`, and the resolver are all defined there and consumed here as finalized code.
2. **Cupertino owns Cupertino visuals.** Use native `cupertino_ui` controls wherever the library has one, and compose a control from Cupertino's own parts wherever it does not, rather than re-drawing a Cupertino-style widget from scratch; let the fork re-skin its own subtree via `cu.CupertinoTheme`.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application; the text field passes the caller's `controller` and `focusNode` straight through and never creates a competing one.
5. **Runtime switching is supported.** Switching from Cupertino UI to another style must not require business pages to import or construct different control classes.
6. **Touch-first, mobile-oriented.** Cupertino's aesthetic is a touch/mobile interaction language; hit targets and control affordances are sized for fingers, and D-pad/TV focus is a secondary consideration verified explicitly rather than assumed.
7. **Serve the whole contract.** This adapter implements every one of the seventeen controls and both structural surfaces with `cupertino_ui`. A control it declares but does not override is a `LiveUiCapabilityException`, and a language this build did not register is a `LiveUiResolutionException` — a shortfall is a fault the app hears about, never a silently foreign-looking widget.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Cupertino UI theme mapping (resolved `DesignToken` → `cu.CupertinoThemeData`).
- Cupertino UI construction for all seventeen controls, plus both structural surfaces — the `CupertinoApp` host and the composed shell.
- Cupertino-specific control defaults (filled vs ghost button, decoration, clamping, and the inert forms a library widget would assert away).
- Reporting the whole contract to the core registry through `cupertinoCapabilities` and both surfaces through `cupertinoSurfaces`.
- Supplying `cupertino_ui`'s own localization delegates for the composition root.
- Adapter-level tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The multi-style selector UI.
- Shared design-token definitions.
- Global configuration storage.
- Riverpod, GetX, or other application state management.
- Application navigation and business page composition.
- Playback, media sessions, or platform window management.
- Plugin installation, permissions, or script execution.
- Direct dependencies on other style adapters.
- Overriding the global `Locale` — locale is coordinated through the composition root.

### 3.3 Dependency rules

| Dependency | Allowed? | Reason |
|---|---|---|
| `live_uikit` | Yes | Shared contracts, tokens, and resolver |
| `cupertino_ui` | Yes | Native Cupertino UI controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_fluent` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| `live_uikit_material` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

Note: `cupertino_ui` is a fork of Flutter's own Cupertino widgets. This adapter is that fork-backed `cupertino` language; it depends on the package, not on Flutter's Cupertino library, and reaches it only through the `cu` import prefix (§17), because the fork deliberately shadows well-known Flutter widget names.

## 4. Package directory

Current implemented structure:

```text
packages/
└── live_uikit_cupertino/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_cupertino.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── cupertino_adapter.dart
    │       │   ├── cupertino_capabilities.dart
    │       │   ├── cupertino_registration.dart
    │       │   └── cupertino_surfaces.dart
    │       ├── theme/
    │       │   ├── cupertino_theme_builder.dart
    │       │   ├── cupertino_theme_mapper.dart
    │       │   └── cupertino_theme_scope.dart
    │       └── widgets/
    │           ├── cupertino_app_bar_builder.dart
    │           ├── cupertino_button_builder.dart
    │           ├── cupertino_card_builder.dart
    │           ├── cupertino_checkbox_builder.dart
    │           ├── cupertino_dialog_builder.dart
    │           ├── cupertino_host_builder.dart
    │           ├── cupertino_list_row_builder.dart
    │           ├── cupertino_nav_bar_builder.dart
    │           ├── cupertino_progress_builder.dart
    │           ├── cupertino_scaffold_builder.dart
    │           ├── cupertino_segmented_builder.dart
    │           ├── cupertino_select_builder.dart
    │           ├── cupertino_shell_builder.dart
    │           ├── cupertino_slider_builder.dart
    │           ├── cupertino_switch_builder.dart
    │           ├── cupertino_tab_bar_builder.dart
    │           ├── cupertino_tab_view_builder.dart
    │           ├── cupertino_text_field_builder.dart
    │           └── cupertino_toast_builder.dart
    ├── live-uikit-cupertino.md
    └── test/
        ├── adapter/
        │   └── cupertino_contract_test.dart
        ├── theme/
        │   └── cupertino_theme_test.dart
        ├── widgets/
        │   ├── cupertino_native_controls_test.dart
        │   └── stub_router.dart
        └── integration/
            └── cupertino_style_switching_test.dart
```

Not yet created (add only when functionality exists; do not create empty placeholder files):

| Module | Purpose | Status |
|---|---|---|
| `interaction/` | Focus, keyboard, and TV D-pad mapping beyond the built-in `focusNode`/`autofocus` pass-through | Not yet created (optional) |
| `icons/` | Map supported semantic icons to Cupertino icons | Not yet created (optional) |
| `diagnostics/` | Adapter-local diagnostic helpers, if the core sink is insufficient | Not yet created (optional) |
| `example/` | Runnable integration demo without business dependencies | Not yet created (optional) |

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | `CupertinoLanguageAdapter` contract implementation, the `cupertinoCapabilities` and `cupertinoSurfaces` declarations, and the registration exports |
| `theme/` | Translate the resolved `DesignToken` into `cu.CupertinoThemeData` and install it via the theme scope |
| `widgets/` | Build every control of the contract and both structural surfaces from the core `Language*Spec` types — one builder each |
| `test/` | Verify contract compliance, the capability/surface sets, and resolver behavior |

## 5. Package dependencies

Current `pubspec.yaml`:

```yaml
name: live_uikit_cupertino
description: Cupertino UI design-language adapter for live_uikit, rendering controls with the cupertino_ui package.
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  cupertino_ui: ^1.1.2
  flutter:
    sdk: flutter
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Because PureLive uses a Pub workspace, `live_uikit` is consumed as a workspace member (no explicit path or version) and `resolution: workspace` keeps it aligned with repository conventions. Do not pin or path-override it independently of the workspace.

The adapter must not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation. The `cupertino_ui` version is a caret range; verify the resolved version before relying on fork-specific control constructors — several builders record a limitation that holds for `cupertino_ui` 1.1.2 (see §9).

## 6. Public API

The public barrel exports only the registration API. Current entry point:

```dart
// lib/live_uikit_cupertino.dart
library;

export 'package:live_uikit_cupertino/src/adapter/cupertino_registration.dart';
```

`cupertino_registration.dart` provides the complete public surface:

| Export | Kind | Purpose |
|---|---|---|
| `createCupertinoAdapter()` | function | Returns a fresh `CupertinoLanguageAdapter` for the composition root |
| `cupertinoAdapter` | `const LanguageAdapter` | The const adapter instance to register |
| `cupertinoAdapterId` | `const String` | The stable runtime id, `'cupertino'` |
| `cupertinoLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | `cupertino_ui`'s own `GlobalCupertinoLocalizations.delegate` |

Do not export the internal builders (`CupertinoButtonBuilder`, etc.), the theme mapper/scope/builder classes, or `cupertino_ui` types (`cu.CupertinoTheme`, `cu.CupertinoButton`, and friends). Business code reaches this adapter only through the core API and the registry.

## 7. Adapter contract

`CupertinoLanguageAdapter` `implements` the core `LanguageAdapter` interface directly. `LanguageAdapter` is an `abstract interface class` with no base implementation behind it, so this adapter provides every member itself. The interface is:

- Getters: `language`, `id`, `displayName`, `capabilities`, `surfaces`.
- Methods: `wrap`, `appHost`, `shell`, and the seventeen control builders `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`, `select<T>`, `tabBar`, `scaffold`, `appBar`, `listRow`, `navBar`, `toast`, `dialog`, `tabView`.

This adapter's realized mapping:

| Contract member | Implementation here |
|---|---|
| `language` | `LiveDesignLanguage.cupertino` |
| `id` | `'cupertino'` (matches `cupertinoAdapterId`) |
| `displayName` | `'Cupertino UI'` |
| `capabilities` | `cupertinoCapabilities` — all seventeen controls |
| `surfaces` | `cupertinoSurfaces` — `appHost` and `appShell` |
| `wrap` | `CupertinoThemeMapper.wrap` (installs `cu.CupertinoTheme`) |
| `button` | `CupertinoButtonBuilder.build` — mapped to `cu.CupertinoButton` / `.filled` |
| `card` | `CupertinoCardBuilder.build` — composed from `cu.CupertinoListSection.insetGrouped` |
| `textField` | `CupertinoTextFieldBuilder.build` — mapped to `cu.CupertinoTextField` |
| `switchWidget` | `CupertinoSwitchBuilder.build` — mapped to `cu.CupertinoSwitch` |
| `checkbox` | `CupertinoCheckboxBuilder.build` — mapped to `cu.CupertinoCheckbox` |
| `slider` | `CupertinoSliderBuilder.build` — mapped to `cu.CupertinoSlider` |
| `segmented` | adapter method / `CupertinoSegmentedBuilder.build` — mapped to `cu.CupertinoSegmentedControl` (inert cell for a sub-two-label track) |
| `progress` | `CupertinoProgressBuilder.build` — mapped to `cu.CupertinoLinearActivityIndicator` / `cu.CupertinoActivityIndicator` |
| `select` | `CupertinoSelectBuilder.build` — composed from `cu.CupertinoMenuAnchor` + `cu.CupertinoMenuItem` + `cu.CupertinoButton` |
| `tabBar` | `CupertinoTabBarBuilder.build` — composed from a row of `cu.CupertinoButton` |
| `scaffold` | `CupertinoScaffoldBuilder.build` — mapped to `cu.CupertinoPageScaffold` |
| `appBar` | `CupertinoAppBarBuilder.build` — mapped to `cu.CupertinoNavigationBar` |
| `listRow` | `CupertinoListRowBuilder.build` — mapped to `cu.CupertinoListTile` |
| `navBar` | adapter method / `CupertinoNavBarBuilder.build` — mapped to `cu.CupertinoTabBar` (inert bar for an empty, one-cell, or out-of-range spec) |
| `toast` | `CupertinoToastBuilder.build` — composed from `cu.CupertinoPopupSurface` |
| `dialog` | `CupertinoDialogBuilder.build` — mapped to `cu.CupertinoAlertDialog` (surface only) |
| `tabView` | `CupertinoTabViewBuilder.build` — composed from `PageView` + `cu.CupertinoScrollBehavior` |
| `appHost` | `CupertinoHostBuilder.build` — mapped to `cu.CupertinoApp.router` |
| `shell` | `CupertinoShellBuilder.build` — composed from `cu.CupertinoListSection` / `cu.CupertinoListTile`, or handed back to `navBar` for a bottom strip |

`segmented` and `navBar` are drawn partly by the adapter method itself: `CupertinoLanguageAdapter` forwards a well-formed spec to the builder and renders the shapes the fork asserts away (a one-label track, an empty or out-of-range bar) with its own inert cells.

### Adapter identifier

Use one stable machine-readable identifier everywhere:

```text
cupertino
```

`id` returns `'cupertino'`, `language` is `LiveDesignLanguage.cupertino`, and `cupertinoAdapterId` exposes the same string. Do not use `cupertino_ui` (the package) or `Cupertino UI` (the human label) as the runtime style id. `displayName` (`'Cupertino UI'`) is the human label for the selector and is never persisted or compared.

### Capability declaration

`cupertinoCapabilities` declares all seventeen controls and `cupertinoSurfaces` declares both structural surfaces; together they must stay in sync with the methods the adapter actually overrides (§16, §17).

The declaration is checked, not trusted. `LiveUiCapabilities` wraps a `Set<LiveUiControl>` and exposes `supports(control)`; `LiveUiSurfaceCapabilities` does the same over `LiveUiSurface`. `LiveUiResolver.requireControl` and `requireSurface` raise a `LiveUiCapabilityException` for anything declared without a matching override — there is no substitute rendering behind a declaration. Because this adapter implements the whole contract, a well-formed Cupertino registry raises neither a capability exception nor `LiveUiResolutionException`; the only runtime diagnostic the core still emits is `unsupportedEffect`, for an effect a device cannot afford (§15).

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized token. The Cupertino UI adapter translates that resolved `DesignToken` into `cupertino_ui`'s theme and installs it around the subtree it renders.

The data flow is:

```text
LiveConfig
     |
     v
DesignToken (resolved by core)
     |
     v
CupertinoThemeMapper.wrap(context, token, child)
     |
     v
CupertinoThemeScope  (StatelessWidget)
     |
     v
CupertinoThemeBuilder.build(token)  ->  cu.CupertinoThemeData
     |
     v
cu.CupertinoTheme(data: ..., child: child)
     |
     v
native cupertino_ui controls
```

The adapter's `wrap` calls `_theme.wrap(...)`, where `_theme` is a `const CupertinoThemeMapper()`. `CupertinoThemeMapper` returns `CupertinoThemeScope(token: token, child: child)`; the scope builds `cu.CupertinoTheme(data: CupertinoThemeBuilder.build(token), child: child)`. No `cupertino_ui` application shell is introduced just to apply the theme.

### 8.1 Theme properties to map

| Core token property | Cupertino UI mapping | Notes |
|---|---|---|
| Brightness (`token.isDark`) | `cu.CupertinoThemeData.brightness` | `Brightness.dark` when `token.isDark`, else `Brightness.light` |
| Accent / primary (`token.color.primary`) | `cu.CupertinoThemeData.primaryColor` | Brand accent drives tinted controls |
| Text colors (`theme.colors.text`) | Applied per-control in builders | See §9; not part of the theme data draft |
| Container / border / radius | Consumed by the text-field builder from `LiveTheme` | Decoration drawn per control, not forked into theme data |
| Page surface (`token.color.surface`) | `cu.CupertinoThemeData.scaffoldBackgroundColor` | Mapped |
| On-primary (`token.color.onPrimary`) | `cu.CupertinoThemeData.primaryContrastingColor` | Mapped |

The current `CupertinoThemeBuilder.build` maps brightness, `primaryColor`, `primaryContrastingColor` and `scaffoldBackgroundColor` — four properties, and the theme test asserts each one moves with the token. Typography and density stay at the fork's defaults: `cupertino_ui` builds its text scale itself, and a token family cannot be folded in without replacing the whole scale, so §8.1 leaves them alone rather than half-mapping them. No second token model is invented; role styles come from `LiveTheme` at builder level.

### 8.2 Theme scope

Prefer the fork's `cu.CupertinoTheme` scope, which is what `CupertinoThemeScope` uses. Do not nest a `cupertino_ui` application widget inside an existing app solely to apply the style; a nested app shell introduces competing navigation, localization, and application-level configuration. The scope wraps only the adapter's own subtree. (The `cu.CupertinoApp` host in §9 is the application widget itself, not a scope introduced to theme a subtree.)

### 8.3 Runtime updates

When the user changes brightness, accent color, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `wrap` is called again with the new token, rebuilding `CupertinoThemeScope`.
4. `CupertinoThemeBuilder.build` derives fresh `cu.CupertinoThemeData`.
5. Existing business state remains owned by the business widgets and controllers.

Do not cache a `cu.CupertinoThemeData` object permanently if its source token can change. The mapper is stateless (`const`); the theme data is rebuilt whenever the resolved token changes.

## 9. Control implementation rules

Every control of the contract has a builder in `lib/src/widgets/`; a Cupertino control is drawn there and nowhere else. A builder maps a core specification onto a `cupertino_ui` widget where the library has one, and composes it from the library's own parts where it does not — the two cases are marked mapped or composed below and stated the same way in each builder's doc comment, which is the ground truth for the field-by-field notes.

### Button (`CupertinoButtonBuilder.build(context, spec)`) — mapped

- `ButtonVariant.ghost` maps to a plain `cu.CupertinoButton`; every other variant maps to `cu.CupertinoButton.filled`.
- Press eligibility comes from the spec: enabled, not loading, and a non-null callback together decide whether `onPressed` is passed or nulled.
- The label, an optional leading glyph, the loading spinner (`cu.CupertinoActivityIndicator`) and the icon-only glyph are composed here, with ghost buttons tinted `theme.colors.primary`.
- `focusNode` and `autofocus` are passed through — the fork's buttons take both.
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` wraps it in the core's language-neutral `LiveTooltip`. `cupertino_ui` has no hint slot, and an SDK Material `Tooltip` does not belong in a Cupertino subtree (§14/§15).
- `iconOnly` paints the bare glyph and takes the tooltip (or, failing that, the label) as its semantic name — the empty label the caller passed to satisfy the contract is never painted.
- `selected` is **not mapped here**. Cupertino's button has no toggled state to hand it to, so a selected button renders unselected. Recorded as the documented remainder of `docs/decisions/0004` (§15).
- `style` is **not mapped here either**. The button is the library's own widget and paints its own surface; applying a caller's `Style` would mean hand-painting an overlay over that widget — the same trade this section already refuses for `selected`.

### Text field (`CupertinoTextFieldBuilder.build(context, spec)`) — mapped

- Native `cu.CupertinoTextField`, passing the caller's `controller`, `focusNode`, `placeholder`, `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`, `textInputAction`, `prefix`, `suffix`, `onChanged`, and `onSubmitted` straight through.
- Obscure fields are forced to one line (`maxLines: 1` when `obscure`).
- The field never creates its own competing controller; when `spec.controller` is null the field's own default is used, matching the core ownership rule.
- Text style and decoration come from `LiveTheme.of(context)` (body text, `bgContainer` fill, `input.borderRadius`, border switching to `theme.colors.error` when `errorText != null`), and the spec's inline `Style` layers onto the body text so a caller override wins property by property.
- The fork has no error slot, so `errorText` also draws a caption line under the field, in the theme's caption style — the field means the same thing whether the error reads through the border, the caption, or both.

### Switch (`CupertinoSwitchBuilder.build(context, spec)`) — mapped

- Native `cu.CupertinoSwitch`, fully controlled by `spec.value`.
- `onChanged` is passed only when `spec.enabled`; otherwise null, which is Cupertino's disable mechanism.
- No local or persistent state is introduced.

### Slider (`CupertinoSliderBuilder.build(context, spec)`) — mapped

- Native `cu.CupertinoSlider` with `spec.min`/`spec.max` and the value clamped to range (`spec.value.clamp(spec.min, spec.max)`).
- Disabled by dropping `onChanged` (null) when `!spec.enabled` **or** when the spec's callback is null. The earlier version supplied a no-op listener so the thumb stayed draggable; that is the §15 defect this rule forbids — a control that looks live and never reports.
- Invalid ranges follow the core validation contract rather than being silently corrected here.

### Card (`CupertinoCardBuilder.build(context, spec)`) — composed

- Composed, not mapped: `cupertino_ui` 1.1.2 ships no card and no box widget, so the card is `cu.CupertinoListSection.insetGrouped` — the 10pt rounded panel iOS drops each row into, filled with the library's own `secondarySystemGroupedBackground` and clipped to its own superellipse. Its `margin` is zeroed and its `backgroundColor` made transparent, because those two belong to a grouped list rather than to a card that its caller places.
- `padding` and the `dense` step land inside the panel; `selected` and `Style.background` replace the panel fill, and the override keeps the library's 10pt corner. The parameter is typed `BoxDecoration`, so an override draws a circular radius while the library's own default is a superellipse — the one place the fork's typing is coarser than its drawing.
- `bordered` asks for an edge iOS cards do not have, so it adds nothing rather than inventing a hairline. `onTap`/`onLongPress` get an opaque hit area, since the library's tap handling lives inside its buttons and none of them is a card; `focusNode`/`autofocus` are unexpressible — a section is a surface, not a control — exactly as recorded for the Fluent and macOS cards (§15).

### Checkbox (`CupertinoCheckboxBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoCheckbox` is the library's only checkbox, and it is the one a Cupertino subtree is allowed to use, since any other answer would put a Material box in an iOS page. The fork documents the widget as macOS-styled and notes the iOS HIG has no checkbox at all (it points at `cu.CupertinoSwitch`, which this adapter already renders); the square with the white tick is still what `cupertino_ui` draws for a multi-selection box.
- `enabled` is the library's inert state — a null `onChanged` greys the box and refuses taps — and the box reports no value of its own, so `tristate` stays off and a null handed back by a `ValueChanged<bool?>` is dropped rather than passed on: the contract has no mixed state.
- `label` has no slot on the box, so it travels beside it and is also given as the box's `semanticLabel`, where iOS puts a control's name rather than in its drawing.

### Segmented (`CupertinoSegmentedBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoSegmentedControl` is the library's own one-choice-out-of-a-row, keyed by a value rather than an index, so the keys here are the indices the contract reports back. A disabled group is the library's inert state: every key goes into `disabledChildren`, which greys each segment and stops its tap from reporting, so `enabled` needs no extra work and the required `onValueChanged` never fires behind it.
- `expand` has no knob. The control divides the width it is handed equally between its segments and cannot shrink-wrap to its labels — which is also how iOS draws a track.
- An index outside the labels is legal and means "nothing selected", the same reading the contract gives.
- A track of fewer than two segments is not: the library asserts `children.length >= 2`, so the adapter draws a one-label track as the library's own inert `cu.CupertinoButton` cell (the unselected colour, no tap) and an empty one as nothing at all (§15).

### Progress (`CupertinoProgressBuilder.build(context, spec)`) — mapped

- Mapped in both of the spec's states, which the library answers with two different widgets: a known fraction is `cu.CupertinoLinearActivityIndicator` (whose `progress` is the contract's 0..1) and a null one is `cu.CupertinoActivityIndicator`, the spinning tick ring iOS uses while work has no measurable end.
- The fill colour follows the token (`barColor`, else `theme.colors.primary`); the track, the cap shape and the spin stay the library's. `height` is the linear bar's own thickness parameter and means nothing to a round spinner, so the spinner keeps the library's radius.
- `showLabel` draws the percentage beside the bar, and only when the value is known — a spinner has no percentage to name.

### Select (`CupertinoSelectBuilder.build(context, spec)`) — composed

- Composed of the library's own pull-down menu, because iOS answers "choose one of these" with a menu that opens *from* the control rather than a field that expands under it: `cu.CupertinoMenuAnchor` with `cu.CupertinoMenuItem` rows behind a `cu.CupertinoButton` trigger carrying the current value (or `placeholder` in the secondary colour) and the library's own `chevron_down`, and the choices open below with a checkmark on the selected one. Nothing here is a Material dropdown.
- `cu.CupertinoPicker` was the other candidate and is the wrong one: a wheel that needs a fixed height, shows every option at once and has no trigger to name the current value, so it cannot be the single inline widget the contract asks an adapter to return.
- `enableSwipe` is off — that knob is for a menu opened by dragging the anchor, and this anchor is an explicit button. `enabled` is the library's inert state twice over: a trigger with no callback cannot open, and an item with no callback reads as disabled.

### Tab bar (`CupertinoTabBarBuilder.build(context, spec)`) — composed

- Composed, not mapped: `cu.CupertinoTabBar` is the only index-controlled strip in the library, and it is the *bottom* bar — a full-width surface with its own background, top hairline and destination geometry — which is why this package gives it to `navBar`. iOS draws the in-page strip (Music's Overview/Songs) as a left-aligned row of plain text buttons in which the current tab is bold and tinted; so the row is composed here from `cu.CupertinoButton` with its minimum tap size and fill taken off, and the selection drawn the iOS way rather than with a Material tab strip and its ink bar.
- `enabled` is the library's inert state: a button with no callback keeps its label and loses its tap. `spacing` has no counterpart — a Cupertino strip spaces its tabs by the buttons' own padding.

### Scaffold (`CupertinoScaffoldBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoPageScaffold` owns the iOS bar behaviour the spec asks for — the translucent nav bar, the scroll-under and the keyboard policy — and takes the bar in its `navigationBar` slot. A dispatched `cu.CupertinoNavigationBar` arrives as an obstructing-preferred-size widget and enters that slot; a bar of any other shape goes above the content rather than being dropped.
- Three fields have no slot in this widget and are handled rather than dropped: the bottom strip (iOS puts one on `CupertinoTabScaffold`, a different widget, so the frame stacks it under the page), the floating action (Cupertino has no FAB; the core's overlay geometry places it), and `extendBodyBehindAppBar` (a Cupertino nav bar always overlays the scrollable content, which is the iOS answer to that flag).

### App bar (`CupertinoAppBarBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoNavigationBar` maps the spec's parts — `leading`, `middle` (the title, which iOS centres by itself, so a null `centerTitle` is left alone rather than forced), `trailing` takes a single widget so the action list travels as a row, and `bottom` lands in the library's own bottom slot.
- It returns a `PreferredSizeWidget`, which is what `LanguageScaffoldSpec.appBar` needs to enter the frame's navigation-bar slot instead of being stacked over the content.

### List row (`CupertinoListRowBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoListTile` is the iOS settings row — leading, title, subtitle and trailing map directly, and its own pressed background is the library's answer to a row that responds to a tap.
- Two fields have no slot on the tile and are handled rather than dropped: `onLongPress` (iOS rows do not long-press, so a gesture wrapper recognises it without changing how the tile looks) and `selected` (the tile takes a background colour, which is where the token selection fill goes). `divided` draws the hairline itself — a bare tile has no separator concept outside a `CupertinoListSection`.

### Nav bar (`CupertinoNavBarBuilder.build(context, spec)`) — mapped

- Mapped: `cu.CupertinoTabBar` is the contract's iOS counterpart — destinations carry an icon and a label, the selection and the callback are both an index, and the active tint comes from the theme rather than being painted here.
- `cu.CupertinoTabBar` asserts a non-empty item list and an in-range `currentIndex`, and a single destination is not a selection to make. So an empty bar, a one-cell bar and a bar whose index fell out of a shrunken shell are all drawn by the adapter method, out of the same parts the live bar uses: the bar's own surface role under the top hairline, with one inert `cu.CupertinoButton` cell per destination in the unselected colour. No destinations leaves the surface and its hairline only (§15).

### Toast (`CupertinoToastBuilder.build(context, spec)`) — composed

- Composed, and only the surface: the overlay the toast floats in, the fade, and the removal timer stay in the core's `LiveToast.show`, which is why `duration` is not read here. `cupertino_ui` 1.1.2 ships no `CupertinoToast` — that is a community widget, not part of the fork — and iOS itself has no transient message bar: its nearest shape is the HUD, a blurred rounded panel that appears over the content. That panel is already in the library as `cu.CupertinoPopupSurface`, the 13pt squircle iOS popups are drawn on, so the surface is that widget.
- The status colour and the message role come from the token, because the token decides that `warning` looks like this app's `warning` in every language; the glyphs are the library's own — `info`, `checkmark_circle`, `exclamationmark_triangle`, `exclamationmark_circle`.

### Dialog (`CupertinoDialogBuilder.build(context, spec)`) — mapped

- Mapped, and only the surface. `cu.CupertinoAlertDialog` is the fork's own alert and an ordinary widget with no route inside it, so it is handed back for the core's `showLiveDialog` to frame: the route, the barrier, the fade-and-scale and the dismissal stay in the core. Its ancestor requirements are a `MediaQuery` and a `cu.CupertinoLocalizations` (for the alert's semantics label), which `cupertinoLocalizationsDelegates` supplies — no `CupertinoApp`, which is why the same surface renders under any host.
- The three fields a Cupertino alert has no slot for, each handled rather than dropped: `icon` (iOS puts no glyph in an alert — that is the action sheet, which this contract does not ask for — so the glyph is drawn above the body inside the alert's own content section, tinted with the library's `secondaryLabel`); `dismissible` (the barrier and the route belong to the core, exactly as `duration` does, so it is not read here); and the core frame's width cap (the alert fixes its own width and insets itself off the keyboard, which is the iOS answer, while the core's `ConstrainedBox` still holds it).
- `actions` go in exactly as the caller built them — dispatched controls, so a Cupertino dialog's buttons are this package's `button`. The title and body are plain widgets: the alert merges its own iOS heading and message styles over each slot.

### Tab view (`CupertinoTabViewBuilder.build(context, spec)`) — composed

- Composed, and deliberately so. The fork's widget of that name, `cu.CupertinoTabView`, is not this contract's thing: it builds a `Navigator` per tab and takes its content from a `builder`/route table, so the caller's finished pages would have to be turned into routes and the widget would keep each tab's stack alive behind the contract's back. iOS itself has no standalone page-switcher widget to map to either, so the switcher is composed from `PageView` (`package:flutter/widgets.dart`, no Material) and given the library's own scroll chrome, `cu.CupertinoScrollBehavior`: no overscroll glow and a `CupertinoScrollbar` where a desktop shows one.
- Every field is read. `pages` are the view's children in order; `index` is the page shown, and a change to it from the caller animates across in `duration` with a decelerating curve, because an iOS page settles rather than easing in and out. `onIndexChanged` reports a swipe back, and a null callback or a single page makes the view non-swipeable. The one field with no counterpart is an empty `pages`: `PageView` asserts a non-empty child list, so the switcher answers with nothing rather than throwing.

### App host (`CupertinoHostBuilder.build(context, spec)`) — mapped

- `cu.CupertinoApp.router` is the only thing that gives a Cupertino page its iOS behaviour: the slide-from-right route, the swipe-back gesture, the scroll physics and the text-selection toolbar. A Material host draws those Material, and no amount of native bars fixes the feel. `CupertinoApp` takes one theme rather than a light and a dark slot, which suits the token: the resolved theme already carries the chosen brightness.

### Shell (`CupertinoShellBuilder.build(context, spec)`) — composed

- Composed, because `cupertino_ui` ships no navigation column. Its two shell-shaped pieces are both unusable here: `cu.CupertinoTabScaffold` binds a bottom bar of two to five destinations to a `cu.CupertinoTabView` body per tab — the opposite of the router-owned body this contract carries — and `cu.CupertinoTabBar` is that same bottom bar on its own, already given to `navBar`. Neither takes a vertical column, so the rail is assembled from `cu.CupertinoListSection` of `cu.CupertinoListTile` rows (leading glyph, title, inert when given no `onTap`) — the pieces iOS draws its sidebars out of.
- The tinting is the library's, not the token's. This fork's `CupertinoThemeData` has no `accentColor`, so the selected row takes `primaryColor` (mapped from the token in `CupertinoThemeBuilder`) with `primaryContrastingColor` on the fill; a live but unselected row uses `CupertinoColors.secondaryLabel`, a disabled one `tertiaryLabel`, and the disabled row is refused its `onTap` because the tile has no disabled state of its own.
- `placement` is honoured on the width rule the core's shell uses, so a narrow window switches form at the same width whichever language is active: `rail` and an `adaptive` request with room compose the column; `bottom` hands the strip back through the adapter's `navBar` (the fork's `CupertinoTabBar`, with its guard for a bar it would assert on); and `none` or a single destination returns the frame to the page. `trailing` has no slot in a library that has no rail, so the column pins it to the bottom of the pane; the bottom strip has no such slot and drops it rather than inventing a place for it.

### Control mapping rule

Builders map semantic intent from the `Language*Spec` types; they must not inspect business page types. A button builder may branch on `spec.variant`; it must not special-case login, playback, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter by supplying it to the core `LanguageRegistry`, keyed by `LiveDesignLanguage`, and resolving through `LiveUiResolver`. Either exported form works — `cupertinoAdapter` is a `const` instance, `createCupertinoAdapter()` returns a fresh one:

```dart
// Register Cupertino UI under its language key.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter},
);
const resolver = LiveUiResolver(registry: registry);
```

`LanguageRegistry` takes only `adapters`, so every language this build claims must bring its own adapter; one it did not register is a fault the resolver raises rather than a partial re-skin.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active language (`UiConfig.language`, which is required).
- Providing configuration persistence.
- Coordinating runtime theme changes.
- Appending `cupertinoLocalizationsDelegates` to the localization delegates (§14).

`live_uikit_cupertino` must not register itself through global static initialization or require the business layer to import it.

### Registration and resolution failure

`LiveUiResolver` over a `LanguageRegistry`:

- `resolve(language)` returns the registered `LanguageAdapter`, or throws `LiveUiResolutionException` when this build registered none. A missing language is a composition fault, not a degraded render.
- `requireControl(language, control)` and `requireSurface(language, surface)` throw `LiveUiCapabilityException` when an adapter declares a capability it does not override. Because Cupertino UI implements the whole contract, both checks pass for every control and both surfaces.
- The one thing the runtime still *reports* rather than throws is an effect the environment cannot afford, delivered as the `unsupportedEffect` diagnostic (§15).

## 11. Runtime style switching

A business widget uses the core API only:

```dart
LiveButton(
  label: 'Save',
  onPressed: saveSettings,
)
```

It must not contain conditional style selection:

```dart
// Avoid style-specific branching in business packages.
if (language == 'cupertino') {
  // Build a Cupertino button.
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
      +---- Cupertino UI adapter (cupertino)
      +---- Fluent adapter
      +---- Material UI adapter
      +---- Other registered adapters
```

Switching from Cupertino UI to another language changes rendering and interaction presentation only. It must not replace business controllers, reset form values, or recreate unrelated application services. Because every control and both structural surfaces resolve to this adapter, a Cupertino page keeps its own rendering path across the whole subtree on either side of a switch; only a language this build did not register would fail, and it fails loudly as a `LiveUiResolutionException` rather than as a partial re-skin.

## 12. Keyboard, focus, and TV support

Cupertino UI is a touch-first language, so finger interaction is the primary path. Keyboard, focus, and Android TV D-pad behavior are secondary but must still be verified rather than assumed.

Current state: the specs carry `focusNode` and `autofocus`, and the builders that reach a focusable native control pass them through (button, text field, checkbox); controls driven straight by the fork widget, like the switch, take what that widget offers. Beyond that pass-through, there is no dedicated `interaction/` module yet (see §4). As focus/TV support matures:

- Rely on `cupertino_ui`'s own focus traversal for the controls that take focus; verify visible focus indication actually appears on desktop and TV.
- Confirm Enter/Space activation semantics and that disabled controls (`onPressed`/`onChanged` dropped) are skipped by traversal.
- Verify focus restoration and predictable traversal order after a runtime style switch.
- For Android TV D-pad, do not assume touch behavior transfers; test the actual controls with supported TV input devices and use the core interaction policy to fill gaps.

Where the fork cannot afford a focus or effect affordance on a device, the resolver reports `unsupportedEffect` and a verified degraded visual stands in (§15).

## 13. Platform behavior

Cupertino UI's aesthetic originates from iOS/macOS; those are its primary fit. It can be selected on any supported platform, but touch-target sizing and D-pad behavior must be validated per platform.

| Platform | Expected behavior |
|---|---|
| iOS | Primary fit — native Cupertino look, standard touch sizing and lifecycle/accessibility behavior |
| macOS | Primary fit — Cupertino look via `cupertino_ui`; verify pointer and keyboard focus |
| Android | Touch-friendly sizing; confirm hit targets meet the minimum touch size |
| Android TV | D-pad/focus navigation is not Cupertino's strength; call out focus behavior explicitly and test it |
| Windows | Cupertino look while retaining Windows integration; verify rendering and dependencies |
| Linux | Cupertino look; verify platform-specific rendering and dependencies |

Touch target sizing is a first-class check here: Cupertino controls are dimensioned for fingers, so on touch platforms verify that button/switch/slider hit areas remain comfortable. TV is functional but not central; document any D-pad limitations rather than claiming parity.

## 14. Localization and accessibility

`cupertino_ui` widgets require their own localization data — separate from Flutter's built-in Cupertino localizations. This package exposes:

```dart
const List<LocalizationsDelegate<dynamic>> cupertinoLocalizationsDelegates = [
  cu.GlobalCupertinoLocalizations.delegate,
];
```

The application composition root must append `cupertinoLocalizationsDelegates` to the core's localization delegate list on the app's root widget (via the delegate composition point `live_uikit` exposes). Do not add the delegate inside the adapter itself, and never independently override the global `Locale`.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing strings; all visible text comes from the specs (`label`, `placeholder`, `errorText`, `itemLabel`).
- Preserve semantic labels, hints, and tooltips (`LanguageButtonSpec.tooltip`, accessibility labels).
- Test long translated labels and right-to-left layouts, especially the text-field decoration and button label ellipsis.
- Verify focus visibility, text contrast, and touch-target sizing.

## 15. Error handling and diagnostics

The adapter reports structured diagnostics through the core contracts, delivered to a host-supplied `LiveUiDiagnosticSink` rather than a concrete logging package. What the runtime can report at all is deliberately narrow now: a language, control, or surface that cannot be served is a fault the resolver raises, not a downgrade to log.

Diagnostic code (`LiveUiDiagnosticCode`) — a single member:

| Code | When it fires for this adapter |
|---|---|
| `unsupportedEffect` | The environment cannot afford a focus/blur/backdrop effect (e.g. a backdrop blur); a verified degraded visual stands in |

A `LiveUiDiagnostic` carries the `language`, and the optional `control` or `surface` it concerns. Faults outside the diagnostic path are exceptions: a selected language with no registered adapter is a `LiveUiResolutionException`, and a capability declared without a matching override is a `LiveUiCapabilityException` naming that control or surface (§10).

Expected behavior:

- An unregistered language fails loudly at resolve; the app is never quietly re-skinned by a library the user did not choose.
- A control or surface this adapter declares is always implemented, so `requireControl`/`requireSurface` raise nothing for Cupertino UI.
- Invalid control data follows core validation rules; programming errors are not swallowed.
- Diagnostics must not log user-entered text, credentials, or other sensitive content.
- Do not add a direct dependency on Talker or another logging implementation; use `LiveUiDiagnosticSink`.

## 16. Testing strategy

### Contract / unit tests (`test/adapter/cupertino_contract_test.dart`)

- Stable id, display name, and language (`cupertino` / `Cupertino UI` / `LiveDesignLanguage.cupertino`).
- The declared capability set is exactly the whole contract — all seventeen `LiveUiControl` members — and `cupertinoSurfaces` is exactly `{appHost, appShell}`, so drift between the declaration and the overrides fails the test (§17).
- Resolution through a `LanguageRegistry` + `LiveUiResolver`: the registered language resolves to this adapter; `requireControl` passes for every control and `requireSurface` for both surfaces; a language this build did not register (`fluent`) throws `LiveUiResolutionException`.

### Widget tests (`test/widgets/cupertino_native_controls_test.dart`)

Driven through a real `LiveConfigProvider` with this adapter registered, so the assertions are about the dispatch path, not the builder in isolation:

- Button callback, disabled/loading gating, and ghost vs filled mapping; the `expand` and `tooltip` wrappers.
- Text-field controller and focus-node preservation (no second controller created), prefix/suffix pass-through, the error caption, and an inline `Style` overriding the token body text.
- Caller-owned focus: the node a page hands the field is the node that takes focus, and the button takes both the caller's node and its `autofocus` flag (§9/§16).
- Switch value updates and disable-by-null; slider clamping and a null callback reaching the fork as null rather than as a no-op listener.
- The controls the fork drives with its own widgets: checkbox (the library box, the label beside it, inert when disabled), segmented (the library track reporting its index, the disabled group, and the one-label inert cell), progress (the linear bar vs the spinner, and `showLabel`), select (the pull-down menu reporting the chosen value, the placeholder, and an inert trigger), tab bar (a row of the library buttons, not the bottom bar), and toast (the `CupertinoPopupSurface` HUD).
- The dialog (the alert card driven through `showLiveDialog`, and an icon with no alert slot still reaching the body) and the tab view (a Cupertino page view whose index the caller owns).
- The native chrome — `CupertinoPageScaffold`, `CupertinoNavigationBar`, `CupertinoListTile` and `CupertinoTabBar` — plus the inert one-cell/empty bottom bar, the composed app shell (rail column, an inert disabled destination, the bottom strip handed to `navBar`, and a single destination standing aside), and the host (`cu.CupertinoApp`, with no `MaterialApp` standing in).

### Theme tests (`test/theme/cupertino_theme_test.dart`)

- `CupertinoThemeBuilder.build` maps `token.isDark` → brightness, `token.color.primary` → `primaryColor`, `token.color.surface` → `scaffoldBackgroundColor`, and `token.color.onPrimary` → `primaryContrastingColor`.
- Theme rebuilds when the resolved token changes (no stale `CupertinoThemeData`), driven through `LiveConfigProvider` → resolver → `wrap` so the re-skin is proven at runtime (§8.3).

### Integration tests (`test/integration/cupertino_style_switching_test.dart`)

Against the production `LanguageRegistry` + `LiveUiResolver` and a real `LiveConfigProvider` with the diagnostics sink wired:

- Every `LiveUiControl` resolves as declared (all seventeen native, `requireControl` passing for each) and both surfaces pass `requireSurface`; a run that renders Cupertino reports no control or surface downgrade at all.
- Re-rendering through the same adapter keeps the rendering path present (`cu.CupertinoTextField`/`Switch`/`Slider`) and the caller-owned `TextEditingController` keeps its text; tabs are Cupertino's own strip (a row of the library buttons, not the bottom bar) and still report across the switch (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support, test on the corresponding runtime. At minimum include iOS/macOS (primary fit), a touch Android target (sizing), and Android TV (focus/D-pad) in the validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_cupertino` depends on `live_uikit` and `cupertino_ui` for its core integration.
- `live_uikit_cupertino` does not depend on any other style adapter (fluent, macos, material_ui, glass, neumorphic, wind).
- The core package does not depend on `cupertino_ui`.
- Business packages do not import `package:cupertino_ui/cupertino_ui.dart`.
- The public barrel exports only `src/adapter/cupertino_registration.dart`.
- The declared `cupertinoCapabilities` matches exactly the controls the adapter overrides, and the declared `cupertinoSurfaces` matches the `appHost`/`shell` overrides it actually provides (the contract-test invariant).
- Every `package:cupertino_ui/` import inside this package uses the `as cu` prefix, in `lib/`
  and `test/`: this fork deliberately shadows well-known Flutter widget names, so an
  unqualified import would resolve to the SDK's widgets and silently defeat the adapter (§3.3).
- The README's list of native controls is checked against `cupertinoCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands (run from the workspace root with the repository's normal Flutter SDK and workspace resolution):

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_cupertino
flutter analyze packages/live_uikit_cupertino
flutter test packages/live_uikit_cupertino
```

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Align the adapter with the finalized core `LanguageAdapter` contract.
- Lock the stable id (`cupertino`), display name, and `cupertinoCapabilities`.
- Expose `createCupertinoAdapter()` / `cupertinoAdapter` / `cupertinoAdapterId` / `cupertinoLocalizationsDelegates`.
- Keep the registration/contract test green.

### Phase 2 — Theme integration ✅

- `CupertinoThemeMapper` / `CupertinoThemeScope` / `CupertinoThemeBuilder` wired into `wrap`.
- Map brightness, primary color, page surface and on-primary today; typography/density stay at the fork's defaults.
- Test runtime theme rebuild on token change.

### Phase 3 — Full contract coverage ✅ (all seventeen controls, plus both surfaces)

Implemented and tested:

1. The twelve mapped controls (button, text field, switch, checkbox, slider, segmented, progress, scaffold, app bar, list row, nav bar, dialog).
2. The five composed controls (card, select, toast, tab bar, tab view), built from `cupertino_ui`'s own parts.
3. The two structural surfaces: the `cu.CupertinoApp` host and the composed shell.

Every member of the contract now has a builder in this package's `widgets/` module; nothing renders anywhere else.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: focus nodes and callbacks are preserved on the focusable controls and asserted in `test/widgets/`; disabled controls are wired dead rather than decorative.
- Open, needs hardware: focus traversal on a device, Android TV D-pad, touch-target sizing.
- Add an `interaction/` module for explicit focus traversal and visible-focus verification.
- Test Android TV D-pad behavior and desktop keyboard navigation.
- Validate semantics and touch-target sizing on mobile targets.
- Document D-pad limitations rather than claiming parity.

### Phase 5 — Production readiness ◐

- §17 architectural rules are enforced by `tool/check_architecture.ps1` (library boundary, `cu` import prefix, registration-only barrel, capability/surface/override match, README control list, §4 tree).
- Open: per-platform verification and any further cross-language device testing.
- Optionally add `icons/` (Cupertino icon mapping), `diagnostics/`, and `example/` as needs appear.
- Document known limitations and `cupertino_ui` upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `cupertino_ui` only for its core integration.
- [x] It implements the core `LanguageAdapter` interface directly — there is no base class to extend.
- [x] It uses the stable adapter id `cupertino` (never `cupertino_ui` or `Cupertino UI`).
- [x] `cupertinoCapabilities` declares all seventeen controls and `cupertinoSurfaces` both structural surfaces.
- [x] Every control and surface has a builder here, mapped onto a `cupertino_ui` widget or composed from its own parts; `selected`/`style` on the button and `bordered`/`focusNode` on the card are recorded as genuine Cupertino limitations (§9).
- [x] `wrap` installs the mapped `cu.CupertinoTheme` scope from the resolved `DesignToken`.
- [x] Controls preserve caller state (controller, focus node, callbacks) and never own business state.
- [x] The barrel exports only `cupertino_registration.dart`.
- [x] No dependency on Riverpod or any other style adapter; business packages do not import `cupertino_ui`.
- [x] `cupertinoLocalizationsDelegates` is appended via the composition root; the global locale is never overridden.
- [x] Runtime switching preserves business state (§16 integration suite; the device half stays in the checkbox below).
- [x] Diagnostics flow through the core sink (`unsupportedEffect`); an unregistered language or a capability without an override raises rather than degrading.
- [x] Tests and static analysis pass against `packages/live_uikit_cupertino`.
- [ ] Platform claims (iOS/macOS primary, others functional) are backed by actual tests.

## 20. Final architecture decision

`live_uikit_cupertino` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model (`LiveConfig` → `DesignToken`), and runtime selection.
- `live_uikit_cupertino` implements the full `LanguageAdapter` contract with `cupertino_ui`: `wrap`, all seventeen controls, and both structural surfaces.
- `cupertino_ui` supplies the underlying Cupertino widgets and theme facilities (its own fork of Flutter's Cupertino).
- The PureLive application composition root registers adapters, appends the `cupertino_ui` localization delegates, and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive offer a Cupertino UI style — every control and both surfaces drawn from `cupertino_ui`, mapped onto a library widget where one exists and composed from its parts where one does not — without forcing business packages to know which library is currently rendering their controls.
