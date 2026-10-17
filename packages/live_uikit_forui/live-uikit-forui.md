# `live_uikit_forui` Architecture and Integration Specification

- **Package:** `live_uikit_forui`
- **Parent package:** `live_uikit`
- **Implementation library:** `forui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_forui` is the ForUI adapter for PureLive's unified UI system.

It implements the `live_uikit` adapter contract end to end for ForUI: all seventeen
control specifications, the two structural surfaces, and forui-specific visual behavior.
Controls are drawn with native `forui` widgets — `FButton`, `FCard`, `FTextField`,
`FSwitch`, `FCheckbox`, `FSlider`, `FDeterminateProgress`/`FProgress`, `FSelect<T>`,
`FTabs`, `FScaffold`, `FHeader.nested`, `FTile`, `FBottomNavigationBar`, `FToast`,
`FDialog` — and, where the library has no widget for the job, composed out of that same
library's parts. It must not implement business pages or duplicate the core theme system.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_forui
       |
       v
forui
```

The application composition root registers this adapter. Business packages depend only
on `live_uikit` and must not import `forui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration
   models, and adapter registration contracts belong to `live_uikit`.
2. **ForUI owns ForUI visuals.** Every control is drawn from the `forui` library: use
   the library's own widget wherever it has one for the job, and compose the control out
   of that library's parts where it does not. Nothing is drawn by hand in order to look
   like some other library.
3. **No business logic.** The adapter must not manage accounts, playback sessions,
   routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business
   state remain controlled by the calling widget or application; `FTextFieldControl.managed`
   carries the caller's controller instead of minting a competing one.
5. **Runtime switching is supported.** Switching from ForUI to another style must not
   require business pages to import or construct different control classes.
6. **Platform-neutral by construction.** forui is a pure-Dart widget library with no
   operating-system chrome, so the style renders identically on every target; nothing
   here may start assuming native platform integrations.
7. **No silent substitute.** This adapter answers the whole contract itself. A control
   or surface it declares without overriding is a `LiveUiCapabilityException`, and a
   language this build did not register is a `LiveUiResolutionException`; a spec field
   the library cannot express is recorded as unmappable in §9 rather than painted over.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- ForUI theme mapping (the palette variant the resolved token can decide, §8.1).
- ForUI widget construction for all seventeen controls of the contract.
- The two structural surfaces: the application host (§9 app host) and the application
  shell (§9 app shell).
- ForUI-specific control defaults (variant kinds, sizes, the fork's own tooltip, label
  and error slots).
- Reporting implemented capabilities and surfaces to the core registry.
- Adapter-level tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The style-selector UI.
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
| `forui` | Yes | Native forui controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_material` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

The tree below is the package as it exists today: four adapter files, three theme
files, one builder per control and per surface, and one test directory per §16 concern.

```text
packages/
└── live_uikit_forui/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_forui.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── forui_adapter.dart
    │       │   ├── forui_capabilities.dart
    │       │   ├── forui_registration.dart
    │       │   └── forui_surfaces.dart
    │       ├── theme/
    │       │   ├── forui_theme_builder.dart
    │       │   ├── forui_theme_mapper.dart
    │       │   └── forui_theme_scope.dart
    │       └── widgets/
    │           ├── forui_app_bar_builder.dart
    │           ├── forui_button_builder.dart
    │           ├── forui_card_builder.dart
    │           ├── forui_checkbox_builder.dart
    │           ├── forui_dialog_builder.dart
    │           ├── forui_host_builder.dart
    │           ├── forui_list_row_builder.dart
    │           ├── forui_nav_bar_builder.dart
    │           ├── forui_progress_builder.dart
    │           ├── forui_scaffold_builder.dart
    │           ├── forui_segmented_builder.dart
    │           ├── forui_select_builder.dart
    │           ├── forui_shell_builder.dart
    │           ├── forui_slider_builder.dart
    │           ├── forui_switch_builder.dart
    │           ├── forui_tab_bar_builder.dart
    │           ├── forui_tab_view_builder.dart
    │           ├── forui_text_field_builder.dart
    │           └── forui_toast_builder.dart
    ├── live-uikit-forui.md
    └── test/
        ├── adapter/
        │   └── forui_contract_test.dart
        ├── integration/
        │   └── forui_style_switching_test.dart
        ├── theme/
        │   └── forui_theme_test.dart
        └── widgets/
            ├── forui_native_controls_test.dart
            └── stub_router.dart
```

Do not create empty files just to match this tree. Add modules as their functionality
is implemented.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability and surface declaration, registration |
| `theme/` | Translate the resolved PureLive token into forui's `FThemeData` and install it |
| `widgets/` | One builder per control and per structural surface, each built from forui's own widgets or its own parts |
| `interaction/` *(optional, not created)* | Keyboard, focus and TV-specific mapping, if forui's own focus treatment proves insufficient on a target |
| `icons/` *(optional, not created)* | Semantic icon remapping to forui's icon set |
| `diagnostics/` *(optional, not created)* | Adapter-local mapping diagnostics; the core contracts already carry the resolver's exceptions and the one reportable effect code |
| `example/` *(optional, not created)* | Runnable demo with no business dependencies |
| `test/` | Contract, theme-mapping, control and switching tests, one directory per §16 concern |

## 5. Package dependencies

```yaml
name: live_uikit_forui
description: ForUI design-language adapter for live_uikit, rendering controls with forui widgets.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  forui: ^0.27.5
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

The adapter adds no code-generation packages: it declares no generated value types.

## 6. Public API

The public entry point exposes only the adapter's registration API:

```dart
// lib/live_uikit_forui.dart
export 'package:live_uikit_forui/src/adapter/forui_registration.dart';
```

`forui_registration.dart` provides exactly four public symbols:

| Symbol | Kind | Purpose |
|---|---|---|
| `createForuiAdapter()` | Function | Constructs the adapter for the composition root to register |
| `foruiAdapter` | `const LanguageAdapter` | The const adapter instance, usable directly where a constant is required |
| `foruiAdapterId` | `const String` | The stable runtime id, `'forui'` |
| `foruiLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | forui's own `FLocalizations.delegate`, appended by the app (§14) |

The builders, the theme mapper/scope and the `forui`-prefixed types stay private:
exporting them would let a business page construct a forui control directly and bypass
runtime style switching.

## 7. Adapter contract

`ForuiLanguageAdapter implements LanguageAdapter`. The core's contract is an
`abstract interface class`, so there is no base class to extend and nothing underneath this
adapter: it implements every member itself, here and in `widgets/`. The contract is exactly:

- Getters: `language`, `id`, `displayName`, `capabilities`, `surfaces`.
- Theme: `wrap(context, token, child)`.
- Control builders: `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`,
  `segmented`, `progress`, `select<T>`, `tabBar`, `scaffold`, `appBar`, `listRow`,
  `navBar`, `toast`, `dialog`, `tabView`.
- Structural surfaces: `appHost(context, LanguageHostSpec)` and
  `shell(context, LanguageShellSpec)`.

The realized mapping:

| Contract member | Implementation here |
|---|---|
| `language` | `LiveDesignLanguage.forui` |
| `id` | `'forui'` (matches `foruiAdapterId`) |
| `displayName` | `'ForUI'` |
| `capabilities` | `foruiCapabilities` — all seventeen controls |
| `surfaces` | `foruiSurfaces` — `appHost` and `appShell` |
| `wrap` | `ForuiThemeMapper.wrap` — installs the mapped `FTheme` scope |
| `button` | `ForuiButtonBuilder.build` — native `FButton` / `FButton.icon` by `iconOnly` |
| `card` | `ForuiCardBuilder.build` — native `FCard` |
| `textField` | `ForuiTextFieldBuilder.build` — native `FTextField` |
| `switchWidget` | `ForuiSwitchBuilder.build` — native `FSwitch` |
| `checkbox` | `ForuiCheckboxBuilder.build` — native `FCheckbox` |
| `slider` | `ForuiSliderBuilder.build` — native `FSlider`, in its lifted form |
| `segmented` | `ForuiSegmentedBuilder.build` — composed: a row of ghost `FButton`s |
| `progress` | `ForuiProgressBuilder.build` — native `FDeterminateProgress` / `FProgress` |
| `select<T>` | `ForuiSelectBuilder.build<T>` — native `FSelect<T>.rich`, in its lifted form |
| `tabBar` | `ForuiTabBarBuilder.build` — native `FTabs`, lifted, with an empty panel per entry |
| `scaffold` | `ForuiScaffoldBuilder.build` — native `FScaffold` |
| `appBar` | `ForuiAppBarBuilder.build` — native `FHeader.nested` |
| `listRow` | `ForuiListRowBuilder.build` — native `FTile` |
| `navBar` | `ForuiNavBarBuilder.build` — native `FBottomNavigationBar` |
| `toast` | `ForuiToastBuilder.build` — native `FToast` surface |
| `dialog` | `ForuiDialogBuilder.build` — native `FDialog` frame, inside composed |
| `tabView` | `ForuiTabViewBuilder.build` — composed: the widgets-layer `PageView` |
| `appHost` | `ForuiHostBuilder.build` — `WidgetsApp.router` with `FTheme` above the routes |
| `shell` | `ForuiShellBuilder.build` — `Row[FSidebar, Expanded(child)]`, bottom form via `navBar` |

### Adapter identifier

Use one stable identifier everywhere:

```text
forui
```

The identifier is a machine-readable value, not a localized label. Do not use `for_ui`,
`ForUI`, or a package-name-derived identifier as the runtime style id; `foruiAdapterId`,
`ForuiLanguageAdapter.id` and `LiveDesignLanguage.forui.name` all resolve to `forui`.

### Capability declaration

`foruiCapabilities` is a *declaration of fact*: it lists precisely the controls
`ForuiLanguageAdapter` overrides. This language overrides all of them — `LiveUiControl`
has exactly seventeen members (`button, card, textField, switchWidget, checkbox, slider,
segmented, progress, select, tabBar, scaffold, appBar, listRow, navBar, toast, dialog,
tabView`) and the declaration names all seventeen, so there is no `text`, `icon`, `menu`
or any other entry to declare or omit. `foruiSurfaces` is declared the same way and names
both members of `LiveUiSurface`, `appHost` and `appShell`.

Fourteen of the seventeen controls map one-for-one onto a widget the library carries.
Three do not, and each builder says what it composes instead: `segmented` is a row of ghost
`FButton`s taking the library's own `selected` state, because forui's only single-choice
row is `FTabs`, which is a tab *view* and is spent on `tabBar`; `tabBar` is `FTabs` itself,
given an empty content panel per entry; and `tabView` is the widgets-layer `PageView`,
because the library's only page switcher is that same `FTabs`, whose panels hang off
labels a page switcher is never given. `dialog` sits between the two cases: the frame is
`FDialog`, and the inside is composed because 0.27.5's frame carries no content padding and
no action area.

`LiveUiResolver.resolve(language)` returns this adapter or throws
`LiveUiResolutionException` for a language this build did not register;
`requireControl` and `requireSurface` check the declarations against the methods and throw
`LiveUiCapabilityException` for anything claimed without a matching override. The contract
test asserts that each declared set *is* the overridden set, so a declaration that lies
about support fails the build (§16/§17).

## 8. Theme mapping

The core owns user preferences and resolves them into a normalized theme. The ForUI
adapter translates the one property the library lets a host decide, and records the rest
as unmappable rather than faking it.

The data flow is:

```text
UiConfig
     |
     v
core resolve (seed -> DesignToken)
     |
     v
ForuiThemeMapper
     |
     v
FThemeData (neutral light/dark variant)
     |
     v
FTheme scope
     |
     v
forui controls (context.theme)
```

### 8.1 Theme properties to map

`ForuiThemeBuilder.build` maps exactly one property, and the test suite pins both the
mapping and the non-mapping:

| Core theme property | ForUI mapping | Status |
|---|---|---|
| Brightness | `token.isDark` selects `FTheme.neutral.dark.touch` vs `FTheme.neutral.light.touch` | Mapped |
| Accent / primary color | None | Not mappable — `FThemeData` has a private constructor and its `copyWith` carries `colors`, `typography` and `style` through unchanged, so no host-writable field exists |
| Font family | None | Not mappable — same reason; the library's supported path is a generated palette (`dart run forui theme create`) rebuilt through `inherit(...)`, which this adapter promotes one control at a time, never by pretending |
| Neutral roles / radii / shadows | None | Not mappable — the neutral variants are the library's own |
| Density | Per-control `FButtonSizeVariant` | Control-level only; density is decided per control and no global step is wired |
| Focus appearance | forui's own focus treatment | Library default |
| Motion | `FTheme` interpolates palette changes | Library default |

The brightness-only mapping is not timidity: `FThemeData` cannot be recolored from
outside, and inventing a `Color`-bearing substitute widget would hand-paint the very
overlay §9 forbids. A theme test pins the limitation on purpose — if the library ever
opens a colour entry point, that test is where the adapter starts mapping it.

### 8.2 Theme scope

`ForuiThemeScope` wraps `child` in `forui.FTheme` with the mapped data. Every forui
widget resolves its appearance from that scope (`context.theme`), so a control rendered
without it would silently paint the library's stock palette instead of the app's
resolved brightness. forui ships no application widget of its own, so this scope is the
only thing the adapter puts above a subtree: `wrap` installs it around the content it
draws, and the app host installs one above the routed tree (§9 app host). Neither place
nests an application widget belonging to another library.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `UiConfig`.
2. The core resolves a new token.
3. The adapter maps the token (§8.1) and `wrap` reinstalls the `FTheme`.
4. forui's `_AnimatedTheme` interpolates the palette change — the re-skin settles
   rather than snapping, which the theme test drives with `pumpAndSettle`.
5. Existing business state remains owned by the business widgets and controllers.

A mapped `FThemeData` is never cached across token changes: `build` derives it from the
token it is handed, so there is nothing to invalidate.

## 9. Control implementation rules

Each control builder converts a core specification into a forui widget.

### Button

- Native `FButton`, or `FButton.icon` when `iconOnly` — the library's own textless
  variant, laid out by the library: squeezing the token square (`iconEdge`) around a
  full `FButton` clipped the glyph, so this language does not use that geometry.
- Variant kinds: `primary` → `FButtonVariant.primary`, `secondary` → `.outline` (the
  token model's secondary is a bordered supporting action, which is what `outline`
  paints, while forui's own `secondary` is a muted fill the token has no role for),
  `ghost` → `.ghost`, `danger` → `.destructive`. Sizes `sm`/`md`/`lg` map one to one.
- Press eligibility is decided by this builder: a null callback, a disabled spec or a
  loading state reach the fork as `onPress: null`, forui's own disabled state — no
  swallowing closure is ever invented to keep the widget looking live.
- `selected` **is mapped** onto `FButton.selected`, forui's own toggled affordance —
  the only adapter in the family that can say that. A toggled button takes the primary
  colour in this contract, and here the library's real state carries it rather than a
  colour applied over the widget (ADR 0004's remainder closes in this language). It is
  exercised through `LiveIconButton`, the control whose spec carries `selected`.
- `focusNode` and `autofocus` pass to the fork; `expand` becomes `mainAxisSize`.
- The accessible name of a textless button lives on the glyph the builder puts inside it
  (`Icon.semanticLabel`, named from the spec's `tooltip` and otherwise from its `label`),
  not on a second `FButton.semanticsLabel` — naming both would announce twice.
- `tooltip` wraps the control in forui's own `FTooltip`.
- `style` is **not mapped by this adapter**. Its button is the library's own widget and
  paints its own surface; applying a caller's `Style` to it would mean hand-painting an
  overlay over that widget. The core's rendering conventions (`live-uikit.md` §11) let a
  language honour the override where it draws the surface itself; this one records the
  field as unmapped instead.

### Card

- `FCard` paints the surface and none of the inside space, so the token padding (or the
  caller's explicit one) wraps the content in a `Padding` the builder adds — `dense` is
  the same ×0.66 step the rest of the family takes.
- An interactive card gets its gestures from a `GestureDetector` around the surface
  (forui composes interaction with `FTappable` rather than exposing a tappable card);
  a card with no callback gets no gesture surface, so a static card cannot absorb taps.
- `focusNode`/`autofocus` belong to controls, not to a surface, so the card has no slot
  for them.

### Text field

- Native `FTextField` with `FTextFieldControl.managed`: the caller's controller is
  carried (forui owns one when the caller brings none and reports through the same
  control object), and `onChanged` bridges through the control — a null callback stays
  null rather than becoming a swallowing closure.
- `hint` carries the placeholder; **`errorText` reaches the fork's real error slot**
  instead of being drawn as an invented caption — forui is the one library in this
  family whose bare field has a form-error surface the spec can hand the message to.
- `enabled`, `readOnly`, `obscure`, `keyboardType`, `textInputAction`, `focusNode`,
  prefix/suffix builders and `onSubmitted` pass through. An obscured field is
  single-line whatever `maxLines` asked.
- The text-field spec carries no `autofocus`: the core's `LanguageTextFieldSpec` never
  gained the field the other specs have, so there is nothing to pass until the contract
  does. Recorded here rather than faked.

### Switch

- Native `FSwitch`, fully controlled: the fork reports the next value and never keeps
  state of its own; a null callback is passed on as null rather than as a no-op, and
  `enabled` mirrors the spec's flag only — the callback gap is forui's own state to
  express, not a fake flag.
- `focusNode`/`autofocus` pass to the fork.

### Checkbox

- Native `FCheckbox`; the fork draws its own label row, so `label` becomes that label
  rather than a hand-built row beside the box.
- Preserve checked/unchecked; the core contract has no indeterminate state, so none is
  advertised. A null callback or `enabled: false` reaches the fork as `onChange: null`.
- `focusNode`/`autofocus` pass to the fork.

### Slider

- Native `FSlider`, handed the selection in the library's **lifted** form
  (`FSliderControl.liftedContinuous`): the spec's value goes in and the next value comes
  out, so the caller keeps owning the number and this builder mints no controller.
- forui measures a slider as a track percentage rather than in the spec's units, so
  `min`/`max` are used twice — once to normalise `value` into 0..1 and once to denormalise
  what the thumb reports back. The library's value bubble is switched off, because it
  would announce "40%" for a value the caller reads as 40 of a 0..100 range.
- `focusNode` has no slot: the widget is a form field and owns its focus internally, so
  the node is not mapped rather than hung off an invented wrapper. The library's inert
  state (`enabled: false`) is what both a disabled spec and a null `onChanged` reach,
  since the spec documents a null callback as disabling the control.

### Segmented

- **Composed, not mapped.** forui has no segmented-track widget: its only single choice
  out of a row is `FTabs`, and that is a *tab view* — every entry carries a content panel —
  which this package already spends on the tab bar. A segment is a value, not a view, so
  the track is assembled out of the library's own parts: `FButton`s in the ghost variant,
  where the chosen one takes `FButton.selected`. That is forui's real toggled affordance,
  the same one the button builder maps, so the selection is drawn by the library's style
  table rather than painted over it, and each segment reports its own index.
- `expand` gives every segment an equal share of the row; a disabled group is a group of
  buttons with no `onPress`, which is the library's own inert state.

### Progress

- The library splits the two states the spec expresses with a null `value` into two
  widgets, so both are mapped rather than approximated: a fraction is
  `FDeterminateProgress` and null is `FProgress`, the library's own indeterminate animation.
- `height` goes to the style's track constraints and `barColor` to the fill's colour, both
  through forui's style delta, which replaces only the field named and leaves the library's
  pill shape and track colour alone. An out-of-range fraction is clamped, because the
  widget asserts 0..1 on its own value.
- `showLabel` has no slot: forui's indicator paints a bar and nothing else, so the label is
  dropped rather than overlaid with a hand-built percentage. It is the one field of this
  control the library cannot express.

### Select

- Native `FSelect<T>`, generic over the caller's value type, so a chosen value comes back
  unchanged. The library builds it as a field plus a popover that opens on the caller's tap
  into the nearest overlay — the widget's own behaviour, not an ancestor this adapter has to
  provide — so the spec still gets a single inline widget back.
- The selection is lifted (`FSelectControl.lifted`): `value` goes in and the picked value
  comes out, so the caller keeps ownership and no `FSelectController` is minted here. The
  lifted control reports a deselection as null and this contract has no such case, so the
  null is dropped rather than handed to the caller as a value.
- Items go through `FSelect.rich` rather than the library's `items:` map constructor,
  because a map is keyed by the display label: two items the caller labels the same would
  collapse into one option, while this contract's items are values and `itemLabel` is only
  how each one is announced.
- `expands` is deliberately not asked for: the library's select field forwards its own
  `maxLines` to the text field underneath it, and that combination trips the fork's
  `minLines and maxLines must be null when expands is true` assertion — a measured fact of
  forui 0.27.5, not a style choice. The field takes the width it is given anyway.
- A disabled select is the library's own inert state (`enabled: false`), reached both by
  `enabled: false` and by a null `onChanged`. A null `placeholder` is left to the library,
  which labels the empty field with its own localized hint.

### Tab bar

- Native `FTabs`, mapped with one honest cost: every `FTabEntry` carries a content panel,
  because the library's tabs are a *tab view*. This contract's tabs are a strip — the
  caller's router owns the body in every language — so each entry gets an empty box and the
  strip arrives with the library's small content gap under it. That is what buys the
  library's own indicator, label weight and focus ring; composing the bar out of
  `FTappable`s instead would have re-drawn those decisions by hand.
- The selection is lifted (`FTabControl.lifted`): the spec's index is what the strip shows,
  and a tap only reports the index. `FTabs` moves its indicator when the index it was handed
  actually changes, which keeps the strip controlled and undoes a refused tap by itself. A
  disabled strip therefore keeps its look and reports nothing — forui has no disabled state
  for tabs.
- Two fields are handled rather than mapped: `spacing` has no slot, because the library
  pads its own strip, and the controller cannot show "nothing selected", so an out-of-range
  `index` is clamped into the tabs that exist. An empty list returns nothing at all, because
  `FTabs` asserts on it, and a changed tab count remounts the strip under a fresh key — the
  library keeps one controller for the widget's lifetime and does not resize it.

### Tab view

- **Composed, not mapped.** In 0.27.5 the library has no content-side page widget; its only
  one is `FTabs`, and that is a *pair* — every entry carries the panel under its own tab, so
  the strip owns the body. This contract splits the two: the strip is the tab bar above, and
  the body is this control, whose pages the caller builds and hands over with no labels for
  the library to hang them on. Re-using `FTabs` here would have meant inventing a second
  strip, so the view is the widgets-layer `PageView` and the pages stay exactly what the
  caller passed — dispatched controls, which already carry the language.
- There is therefore nothing to theme: no library knob covers a page change, so `duration`
  drives `PageController.animateToPage` with the widgets-layer curve, and the view follows
  the caller's index rather than owning a page of its own. As in the tab bar, a swipe is
  only possible when the caller can receive one — with no `onIndexChanged`, or with a single
  page, the physics refuse scroll and the callback is not wired.
- The builder returns a small stateful widget rather than calling the library directly,
  because the controller outlives a build and has to be disposed with this subtree.

### Scaffold

- Native `FScaffold` — header slot, content, footer — so the already-dispatched bar goes
  into `header` and the destination strip into `footer`, which is also where the library
  paints its own top border for the bottom bar. `avoidKeyboard` is the library's
  `resizeToAvoidBottomInset` under another name, and `background` is a style delta on the
  frame's background colour, so neither has to be painted over the widget.
- Two fields have no slot and are handled rather than dropped. `extendBodyBehindAppBar`
  asks for a body that starts under the bar, which the library's header slot cannot do (it
  stacks the bar above the content), so the frame gets no header and the bar is overlaid at
  the top of the content area, keeping its own safe-area inset. `floatingActionButton` is
  placed by this adapter's own geometry, because a ForUI page has no floating-action slot
  at all.

### App bar

- Native `FHeader.nested`, the library's own bar with both action slots: `leading` goes
  into `prefixes` and `actions` into `suffixes` as the arbitrary widgets the contract
  carries, which the library lays out and pads itself. The root variant is not used because
  it has no leading slot, and a bar the caller gave a back affordance to cannot lose it.
- `centerTitle` maps onto the header's `titleAlignment`, and null keeps the library's *page*
  bar default — start-aligned — since centring a title is what the nested variant does for a
  page inside a navigation stack, not what this contract's page bar does by default.
  `background` and `height` go through the style delta, so they are the library's own fields
  written by the caller rather than a box painted over the widget.
- `bottom` is stacked under the bar in a column: a ForUI header is one row, and the strip
  the contract puts there (a dispatched `LiveTabs`) belongs below it rather than inside it.

### List row

- Native `FTile`, which carries every part the spec does: `prefix` for `leading`, `suffix`
  for `trailing`, both press handlers, a real `selected` state and the caller's focus node —
  so the row's hover fill, ink and text roles come from the library's style table. A row
  with no callbacks stays exactly that: the tile is not hoverable when both handlers are
  null, so nothing has to be disabled by hand.
- `divided` is the one field a lone tile has no slot for — the library puts separators
  *between* items, through `FTileGroup`, and this contract has no group control to opt into —
  so the row draws the library's own `FDivider` under itself. That is the same widget a
  grouped list would paint, not an invented hairline.

### Nav bar

- Native `FBottomNavigationBar`, the contract's counterpart one-for-one: the children are
  `FBottomNavigationBarItem`s carrying an icon and a label, the selection is an index, and
  the callback is an index rather than a route — so a page's branch switching survives the
  language change, and the bar keeps the library's decoration, top border and safe-area
  padding.
- `enabled` is mapped by handing the library a null `onChange`, its own inert state: the
  destinations keep their labels and grey out instead of staying live with a swallowed
  callback.

### Toast

- Native `FToast`, returned directly rather than composed. Unlike the rest of forui's
  overlay widgets it is a plain `StatelessWidget`: it paints its decoration, its padding and
  its icon row and asks for nothing from an ancestor. What needs an overlay is the *toaster*
  around it (`FToaster`, `showFToast` and their controller), and that is the core's: the
  placement, the entrance animation and the removal timer live in `LiveToast.show`, which is
  why the spec carries a duration the surface never reads.
- Severity is forui's own two-step choice — `destructive` for a warning or an error,
  `primary` otherwise — while the glyph's colour stays the token's, written through the
  style delta on the library's icon style. The token decides that this app's `warning` looks
  like its `warning` in every language (ADR 0004).

### Dialog

- Native `FDialog`, the library's dialog frame in 0.27.5 — the older `FAlertDialog` is gone,
  and what is left is a frame plus a builder. It is returned as a plain widget and asks for
  two ancestors only: an `FTheme` (`context.theme`, installed by `wrap`) and a `MediaQuery`,
  both of which the routed tree already provides. What it does not need is an overlay: the
  route, the barrier, the fade-and-scale and the dismissal are the core's `showLiveDialog`,
  not forui's `FDialogRoute`/`showFDialog`, so nothing in here pushes a route.
- The library supplies the decoration, the width constraints and the two text roles
  (`titleTextStyle`/`bodyTextStyle`), and the title and body are handed to those roles rather
  than re-styled by hand. Two of its behaviours are turned down because the core already does
  them: the library's `insetPadding` is zeroed, since the core's frame insets the surface,
  and its `animation` is left null, so the entrance stays the core's fade-and-scale instead
  of a second one inside it.
- The rest is composed, because the frame has no slot for it. It ships no content padding at
  all, so the token card padding wraps the column — the same number this language's card
  fills with — and it has no action area, so `actions` arrive as a right-aligned row of the
  widgets the caller already dispatched; the frame must not re-pick the language's button.
  `icon` keeps the token's own accent, for the same reason the toast does. `dismissible` is
  the barrier's question, not the surface's, so it is not read here.

### App host

- forui ships no application widget — the library is a theme plus a set of components, and
  nothing in it owns a route, a title or a locale — so this adapter hosts the app itself, on
  Flutter's own `WidgetsApp.router` with the library's theme installed above the routed tree.
  That is what takes the page transitions, the scroll physics and the dialog barrier out of
  Material's hands: a `MaterialApp` would keep all three no matter which controls were drawn
  above them.
- The theme is the outermost thing inside the app, so a route's own overlay content resolves
  it too, and the caller's `builder` — the translation scope — stays inside it. Where the
  router has nothing to show, the app widget hands the builder a child it has not built, and
  the theme scope still wraps something rather than nothing.
- `WidgetsApp` asks for a colour outright; it is the resolved theme's primary, so the host's
  own chrome — a scrollbar thumb, a text selection — stays on-theme even where no forui
  widget paints it.
- `LanguageHostSpec.localizationsDelegates` is how forui's strings reach the tree from here,
  which makes the delegate in §14 a requirement rather than a convenience.

### App shell

- `FSidebar` is the library's own structural navigation column, and it is usable on its own:
  its only ancestor requirement is the `FTheme` scope this adapter already installs, because
  an `FSidebarItem` resolves its style through `FSidebarData` to the theme's sidebar style
  when there is no `FSidebarGroup` around it. It paints nothing but its own header, content
  and footer strip and carries no body area, so the shell composes the `Row[sidebar,
  Expanded(child)]` itself with the router's page on the right. The library's default width
  (256, a constraint inside `FSidebarStyle`) is kept rather than the token's rail metric: the
  form rules are the contract's, and the column's own look is the language's.
- `LiveShellDestination.enabled` has no slot on `FSidebarItem` — the widget models a
  `selected` state but never a disabled one — so a disabled destination is refused here: the
  item keeps its place in the column, inert, with its label still readable.
- `LiveShellPlacement` is honoured the way every language honours it. `bottom` goes back
  through this adapter's `navBar`, which draws the library's own `FBottomNavigationBar`;
  `rail` draws the sidebar; and `adaptive` reads the same window geometry the contract's
  rail metric uses, so a narrow window switches form at the same width whichever language is
  active. `trailing` has a real slot in the sidebar — its sticky footer — and the bottom
  strip has none, so that form drops it rather than inventing a place for it. `none`, and a
  destination list shorter than two, leave the shell standing aside: the frame is the page's
  own.

### Control mapping rule

Builders must map semantic intent, not inspect business page types.

For example, a button builder can receive `variant: primary`; it must not special-case
login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup:

```dart
registry: const LanguageRegistry(
  adapters: {LiveDesignLanguage.forui: foruiAdapter},
),
```

`LanguageRegistry` takes the adapter map and nothing else: a design language is served by
its own adapter or by none at all.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active style.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_forui` must not register itself through global static initialization or
require the business layer to import it.

### Registration failure

`LiveUiResolver.resolve(language)` returns the adapter registered for that language and
throws `LiveUiResolutionException` when this build registered none — the fault is raised at
resolution, not papered over with another library's window. `requireControl` and
`requireSurface` throw `LiveUiCapabilityException` when an adapter declares a control it
does not override or a surface it does not own; this adapter declares the whole contract,
and §17 makes the declaration and the overrides one checked fact. Do not catch either
exception to keep a page rendering: both mean the build is not what it claims to be.

## 11. Runtime style switching

A business widget uses the core API (`LiveButton`, `LiveCard`, …) and never branches on
the active style. Switching adapters changes rendering and interaction presentation — the
page frame, the bars, the shell and the host all answer in the new language — but it must
not replace business controllers, reset form values, or recreate unrelated application
services. `UiConfig.language` is required, so there is no default language to settle for:
switching to a language this build registers re-skins the subtree, and switching to one it
does not register is a `LiveUiResolutionException`. The integration test pumps a ForUI page,
re-issues the same configuration, and asserts that the caller's controller text survives
while every one of the seventeen controls keeps resolving to this adapter, with nothing
left for the run to report (§16).

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms.

The adapter should account for:

- Keyboard navigation and focus traversal.
- Visible focus indication (forui's own focus ring).
- Enter and Space activation semantics.
- Disabled controls being skipped or handled correctly.
- Focus restoration after dialogs or menus.
- Remote-control navigation on Android TV.
- Predictable focus behavior after runtime style switching.
- Accessibility semantics for interactive controls.

The headless half is done: `focusNode`/`autofocus` reach the fork on every control that
accepts them — the slider excepted, since its widget is a form field that owns its focus
internally (§9 Slider) — and the widget tests assert caller ownership. What remains open
needs hardware: focus traversal on a real Windows target, the fork's focus ring visibility,
and Android TV D-pad behavior. forui is a touch/desktop-pointer library with no D-pad
story of its own; document limitations rather than claiming parity.

## 13. Platform behavior

forui is pure Dart with no operating-system chrome, so one rendering applies to every
target:

| Platform | Expected behavior |
|---|---|
| Windows / macOS / Linux | ForUI styling with desktop keyboard and mouse support |
| Android | ForUI styling with touch-friendly sizing |
| Android TV | ForUI styling plus explicit D-pad and focus testing (§12) |
| iOS | ForUI styling with iOS lifecycle and accessibility behavior |

No native window API is a dependency of this adapter, and Acrylic/Mica-style effects do
not exist here to degrade. The one effect the core still reports is
`LiveUiDiagnosticCode.unsupportedEffect`, and it is about the device rather than the
language: a configured backdrop blur the hardware cannot do is reported once per language
change. Nothing is reported for a control or a surface, because the core keeps no such
diagnostic: an adapter that cannot serve a member simply does not declare it, and this
adapter declares all seventeen controls and both surfaces.

## 14. Localization and accessibility

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints.
- Avoid introducing a second, conflicting locale source.
- Test long translated labels and right-to-left layouts.

### The forui delegate is required, not optional

forui resolves its own `FLocalizations` type and labels several controls through
`LocalizedText` (supporting Material's 115 languages). Nothing supplies it by accident:
this language's host is `WidgetsApp`, which localizes only what the app hands it, and the
core localizer covers Flutter's global delegates. Left out, a forui control throws the
library's localization assertion the first time it builds. The package therefore exports
the delegate and the composition root appends it:

```dart
const List<LocalizationsDelegate<dynamic>> foruiLocalizationsDelegates = [
  forui.FLocalizations.delegate,
];

LiveApp(
  routerConfig: /* the app's router */,
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...foruiLocalizationsDelegates,
  ],
  supportedLocales: /* the app's locale policy */,
)
```

`LiveApp` forwards that list into `LanguageHostSpec`, where this adapter's host builder
passes it to the app widget it builds (§9 app host).

Rules:

- Order matters: the core delegates come first so app-level strings keep priority and
  forui supplies only its own internal strings.
- `live_uikit_forui` must not install a delegate itself, wrap the app in a localization
  widget, or override the global locale — that is the composition root's job.
- `supportedLocales` must include a locale every active delegate covers; English is the
  safe common denominator.
- The adapter adds no `flutter_localizations` dependency of its own; the app supplies
  the localizer and this package contributes only the delegate list.

## 15. Error handling and diagnostics

The adapter reports nothing through a logger of its own: it introduces no direct
dependency on Talker or another application logging implementation. Its failures are
exceptions the resolver raises, not a degraded render this package publishes, and the only
thing it can report at all is the one effect code the core still keeps.

Expected behavior:

- Every control and both structural surfaces resolve to this adapter, so a ForUI run has
  nothing of its own to report: the core contract keeps no diagnostic for a control or a
  surface. A capability declared without a matching override is a
  `LiveUiCapabilityException`, and the contract test plus §17 catch that drift before a
  page can ever hit it.
- A language this build did not register is a `LiveUiResolutionException` at resolution,
  not a degraded render (§10/§11).
- The one diagnostic the core still emits is `unsupportedEffect` — an effect the device
  cannot afford, such as a configured backdrop blur — reported once per language change by
  the provider, never by this package (§13).
- Invalid control data follows core validation rules: a progress fraction and a tab index
  are clamped into what the library accepts, a slider's value is normalised through the
  spec's own `min`/`max`, and a null callback reaches the library as its inert state
  rather than as a swallowing closure.
- Programming errors are not swallowed; diagnostics never log user-entered text,
  credentials, or other sensitive content.

## 16. Testing strategy

Three directories plus the switching pass, one per concern: `test/adapter/` (contract),
`test/theme/` (§8.1 mapping and the §8.3 re-skin), `test/widgets/` (§9 controls, both
structural surfaces and the widgets-layer stub router they drive through a real
`LiveConfigProvider` + `LiveUiResolver`, so the assertions are about the dispatch path and
not a builder in isolation), `test/integration/` (§11).

### Contract tests (`test/adapter/forui_contract_test.dart`)

- Stable adapter id `forui`, display name, language, and `foruiCapabilities` truthfulness:
  the declared set *is* the whole contract, asserted against `LiveUiControl.values` so a
  control added to the contract cannot go undeclared by accident. `foruiSurfaces` is
  asserted the same way against `LiveUiSurface.values` — `appHost` and `appShell`.
- Dispatch through the core resolver: `resolve` hands back this adapter, and
  `requireControl` accepts all seventeen members with nothing to report. A language this
  build did not register throws `LiveUiResolutionException` rather than resolving to
  somebody else.
- The const instance and the factory hand back the same adapter; the delegate list is
  exported (§14).

### Theme tests (`test/theme/forui_theme_test.dart`)

- The palette variant follows the resolved brightness, mapped to the library's own
  neutral light/dark themes.
- The accent and the global font **cannot** be mapped, and the builder says so — the
  unmappability is pinned so a library that opens a colour entry point is caught by
  this suite first (§8.1).
- Runtime re-skin through `LiveConfigProvider` → `wrap`, settling through forui's
  animated theme (§8.3).

### Widget tests (`test/widgets/forui_native_controls_test.dart`)

Driven through a real `LiveConfigProvider` + `LiveUiResolver`, so the assertions are about
the dispatch path and not about a builder in isolation.

- Button callback, disabled and loading gating (`onPress: null` is forui's disabled
  state), variant/size kind mapping, `selected` mapped onto the fork's affordance,
  focus ownership, the textless button named by its glyph, and the `FTooltip` wrapper.
- Card gestures only when interactive, and the padding triple (token / `dense` step /
  caller's explicit).
- Text field controller preservation and change bridge, null-callback-stays-null, hint,
  the real error slot, obscure-forces-single-line, maxLines, enabled/readOnly, and the
  icon slots.
- Switch fully controlled and reporting the next value; disabled/null-callback states;
  the checkbox's label row; caller focus on both controls.
- Slider as the lifted `FSlider` in the caller's units, a dragged thumb denormalised back
  through `min`/`max`, and a null callback reaching the library's inert state.
- Segmented as the ghost `FButton` row it is composed from: one selected segment, the
  tapped index reported, and a disabled row whose buttons carry no `onPress`.
- Progress as `FDeterminateProgress` at the spec height, and as the library's own
  `FProgress` when the value is null.
- Select as `FSelect<T>` carrying the value, the placeholder, and — with none — the
  library's own localized hint, plus its disabled state.
- Tab bar as `FTabs`: the icon tab, the tapped index reported, nothing thrown.
- Page frame as `FScaffold` with the dispatched bar and destination strip; app bar as
  `FHeader` keeping its leading, its actions and its bottom strip.
- List row as `FTile` with both lines, its tap, and the library's own `FDivider` for
  `divided`; destination strip as `FBottomNavigationBar`, with a disabled bar reporting no
  handler at all.
- Toast surface as the library's `FToast`, shown through `LiveToast.show`, with the
  core's overlay rather than the library's `FToaster`; dialog surface as the library's
  `FDialog` inside the core's frame, its actions arriving as already-dispatched controls.
- Tab view as the widgets-layer `PageView` over the caller's pages, following the index
  the caller holds and deliberately not `FTabs`.
- App host pumped with no outer application widget: the tree is hosted by `WidgetsApp`
  under `FTheme`, with no `MaterialApp` standing in.
- App shell in all three forms: the rail drawing `FSidebar` with its sticky footer and
  refusing a disabled destination, the bottom request delegating to
  `FBottomNavigationBar` and dropping `trailing`, and `none` leaving the page's own frame.

### Integration tests (`test/integration/forui_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: all seventeen resolve to this adapter, and
  `requireControl` accepts each one. A run that renders a ForUI page has nothing to report,
  because the only diagnostic the core still carries is `unsupportedEffect`, and that one
  speaks about the device rather than about the language (§15).
- A ForUI page built from the button, the card, the text field, the switch and the progress
  indicator is pumped repeatedly under the same configuration. The library's own `FButton`,
  `FCard`, `FTextField`, `FSwitch` and `FDeterminateProgress` are found on every pass, and
  the controller the caller handed in keeps the text it was given (§11).
- A page built from the scaffold, the app bar, the tab strip, the segmented row, the select,
  the list row and the destination bar pumps with nothing thrown, which is what a language
  that serves the whole contract has to do.
- The structural surfaces are covered by their own assertions in `test/widgets/` rather
  than by a cross-language swap: §3.3 forbids depending on another style adapter, so a
  ForUI-against-Fluent switch belongs to the application integration suite.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. forui's
pure-Dart nature makes the rendering claim cheap, but the D-pad and desktop keyboard
claims still need the real targets (§12).

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, fatal in
`.github/workflows/architecture.yml`, from one adapter → widget-library map for the
whole family:

- `live_uikit_forui` depends on `live_uikit` and `forui` only.
- `live_uikit_forui` does not depend on other style adapters.
- The core package does not depend on `forui`; no business package imports
  `package:forui/`.
- All public exports are intentional (registration-only barrel, §6).
- The adapter's declared capabilities match its control overrides, and its declared
  surfaces match its `appHost`/`shell` overrides — both sets compared, in both directions.
- Every `package:forui/` import inside this package uses the `as forui` prefix, in
  `lib/` and `test/`.
- This package exports the localization delegate its §14 tells the composition root to
  append.
- The README's prose list of controls is checked against `foruiCapabilities`, so the
  document cannot claim a control the declaration does not carry.
- §4's directory tree is checked against the package: every file the current-layout
  tree names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_forui
flutter analyze packages/live_uikit_forui
flutter test packages/live_uikit_forui
```

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Adapter aligned with the finalized core contract; stable id `forui`; capability
  declarations; registration API; contract tests.

### Phase 2 — Theme integration ✅

- The one mappable property (brightness variant) mapped and installed through the
  `FTheme` scope; the unmappable properties recorded and pinned by test (§8.1); the
  animated re-skin covered (§8.3).

### Phase 3 — The whole control contract ✅ (seventeen builders)

1. Button (`FButton` / `FButton.icon`, with the family's only native `selected`)
2. Card (`FCard`)
3. Text field (`FTextField`, with the family's only native error slot)
4. Switch (`FSwitch`)
5. Checkbox (`FCheckbox`)
6. Slider (`FSlider`, in its lifted form, normalised through the spec's `min`/`max`)
7. Segmented (composed: a row of ghost `FButton`s taking `FButton.selected`)
8. Progress (`FDeterminateProgress` for a fraction, `FProgress` for a null value)
9. Select (`FSelect<T>.rich`, lifted, so two identically labelled items cannot collapse)
10. Tab bar (`FTabs`, lifted, with an empty content panel per entry)
11. Scaffold (`FScaffold`)
12. App bar (`FHeader.nested`)
13. List row (`FTile`, plus the library's `FDivider` for `divided`)
14. Nav bar (`FBottomNavigationBar`)
15. Toast (`FToast` surface; the toaster, overlay and timer stay the core's)
16. Dialog (`FDialog` frame with its inside composed; the route stays the core's)
17. Tab view (composed: the widgets-layer `PageView` over the caller's pages)

Each promotion moved the builder, the adapter override, the `foruiCapabilities` entry, the
contract test and the README in one change, because §17 fails on any half of that pair.

### Phase 4 — Structural surfaces ✅

- App host: `WidgetsApp.router` with `FTheme` above the routed tree, since forui ships no
  application widget of its own (§9 app host).
- App shell: `FSidebar` inside a `Row` beside the router's page, the bottom form delegated
  to this adapter's `navBar`, `trailing` carried by the sidebar's sticky footer and dropped
  in the strip form (§9 app shell).
- Both declared in `foruiSurfaces` and compared against the two overrides by the guard (§17).

### Phase 5 — Interaction and accessibility ◐

- Headless half done: focus nodes reach the fork buttons, switch, checkbox, text field and
  list row; a disabled control is wired dead rather than decorative. The slider's form
  field and the library's tabs keep their focus to themselves (§9).
- Open, needs hardware: keyboard navigation and the fork's focus ring on a real Windows
  target, Android TV D-pad.
- Add an `interaction/` module only if that testing finds a forui-specific gap.

### Phase 6 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Re-themeing inside this language is covered in `test/integration/`; a cross-adapter
  switch belongs to the application suite (§3.3).
- Verify all claimed platforms (§13); document known limitations and `forui` upgrade
  compatibility: today the theme recolor ceiling (§8.1), the inline `style` remainder
  on the button (§9), the field spec's missing `autofocus` (§9), and the per-control
  slots recorded in §9 (`LanguageProgressSpec.showLabel`, `LanguageSliderSpec.focusNode`,
  `LanguageTabsSpec.spacing`, the sidebar item's missing disabled state).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `forui` only for its core integration.
- [x] It implements the core `LanguageAdapter` interface directly — there is no base class
  behind it — and answers every member of that interface.
- [x] It uses the stable adapter ID `forui`.
- [x] It reports accurate capabilities and surfaces: all seventeen controls in
  `foruiCapabilities`, both `LiveUiSurface` members in `foruiSurfaces`, each asserted
  against the overrides it claims.
- [x] It maps the resolved core theme into forui's theme as far as the library allows,
  and pins the ceiling instead of faking a recolor (§8.1).
- [x] It uses native forui controls where the library has one and composes the rest out of
  that library's own parts, recording which is which per builder (§9).
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It hosts the app itself — `WidgetsApp` under `FTheme` above the routed tree — and
  composes its shell from `FSidebar`, nesting no other library's application widget
  (§9 app host, §9 app shell).
- [x] Runtime switching preserves business state (controller text across a re-theme, §16).
- [x] A capability the adapter declares but cannot serve is a `LiveUiCapabilityException`,
  and a language this build did not register is a `LiveUiResolutionException`; the only
  diagnostic the core still reports is `unsupportedEffect`, for an effect the device cannot
  afford (§13/§15).
- [x] Diagnostics and resolution failures use the core's contracts (§10/§15).
- [x] `button.selected` is carried by the fork's own affordance, not a hand-painted
  overlay (ADR 0004's remainder closes in this language).
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the headless half is
  (§16); the fork's focus ring, D-pad traversal and screen-reader behaviour need
  hardware (§12).
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests (§13/§16).

## 20. Final architecture decision

`live_uikit_forui` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, the public controls, the theme model and runtime
  selection; each design language draws them from its own widget library.
- `live_uikit_forui` implements the whole of that contract in ForUI: every control, the
  application host and the application shell.
- `forui` supplies the underlying shadcn-style widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user
  preferences.
- Business packages depend only on the unified `live_uikit` API.
