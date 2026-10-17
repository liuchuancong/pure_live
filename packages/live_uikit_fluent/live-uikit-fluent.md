# `live_uikit_fluent` Architecture and Integration Specification

- **Package:** `live_uikit_fluent`
- **Parent package:** `live_uikit`
- **Implementation library:** `fluent_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_fluent` is the Fluent Design adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `fluent_ui` controls,
the library's own application host and navigation shell, and Fluent-specific visual
behavior. It must not implement business pages or duplicate the core theme system.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_fluent
       |
       v
fluent_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `fluent_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`.
2. **Fluent owns Fluent visuals.** Use native Fluent controls wherever practical rather than drawing Fluent-style controls from scratch.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application.
5. **Runtime switching is supported.** Switching from Fluent to another style must not require business pages to import or construct different control classes.
6. **Platform-aware behavior.** Fluent appearance can be selected on any supported platform, but native Windows appearance and system integrations must not be assumed on every platform.
7. **No silent substitution.** This adapter answers the contract itself: every control and both structural surfaces have a Fluent rendering written here, taken from a `fluent_ui` widget where the library has one for the job and composed from the library's own parts where it does not. A spec field the library cannot express is documented as unmapped (§9) rather than faked with a hand-painted overlay, and a language the build did not register is a fault the resolver raises (§15), not a foreign look the UI can settle for.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Fluent theme mapping.
- Fluent widget construction.
- Fluent-specific control defaults.
- Fluent-specific icon mapping where supported.
- Fluent focus and keyboard interaction integration.
- Mapping the core's control specifications to Fluent controls, and composing a Fluent rendering from the library's own parts where the library has no widget for the job.
- Declaring the controls and the structural surfaces this adapter renders, and keeping that declaration in step with the methods it overrides.
- Adapter-level tests and compatibility checks.

### 3.2 What this package must not own

- Global theme preferences or their persistence.
- The eight-style selector UI.
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
| `fluent_ui` | Yes | Native Fluent controls and theme |
| Flutter SDK | Yes | Widget and rendering primitives |
| Riverpod | No | State management belongs to the app |
| `live_uikit_material` | No | Adapters must remain independent |
| `live_uikit_macos` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

## 4. Package directory

The tree below is the package as it exists today: one builder per control and per
structural surface, twenty files under `widgets/`, three theme files, the four
adapter-contract files, and one test directory per §16 concern. The modules after
it are expansion points that have not been created.

```text
packages/
└── live_uikit_fluent/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── live-uikit-fluent.md
    ├── lib/
    │   ├── live_uikit_fluent.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── fluent_adapter.dart
    │       │   ├── fluent_capabilities.dart
    │       │   ├── fluent_registration.dart
    │       │   └── fluent_surfaces.dart
    │       ├── theme/
    │       │   ├── fluent_theme_mapper.dart
    │       │   ├── fluent_theme_builder.dart
    │       │   └── fluent_theme_scope.dart
    │       └── widgets/
    │           ├── fluent_app_bar_builder.dart
    │           ├── fluent_button_builder.dart
    │           ├── fluent_card_builder.dart
    │           ├── fluent_checkbox_builder.dart
    │           ├── fluent_dialog_builder.dart
    │           ├── fluent_host_builder.dart
    │           ├── fluent_list_row_builder.dart
    │           ├── fluent_nav_bar_builder.dart
    │           ├── fluent_progress_builder.dart
    │           ├── fluent_scaffold_builder.dart
    │           ├── fluent_segmented_builder.dart
    │           ├── fluent_select_builder.dart
    │           ├── fluent_shell_builder.dart
    │           ├── fluent_slider_builder.dart
    │           ├── fluent_switch_builder.dart
    │           ├── fluent_tab_bar_builder.dart
    │           ├── fluent_tab_view_builder.dart
    │           ├── fluent_text_field_builder.dart
    │           └── fluent_toast_builder.dart
    └── test/
        ├── adapter/
        │   └── fluent_capabilities_test.dart
        ├── theme/
        │   └── fluent_theme_test.dart
        ├── widgets/
        │   ├── fluent_native_controls_test.dart
        │   └── stub_router.dart
        └── integration/
            └── fluent_style_switching_test.dart
```

Do not create empty files just to match this tree. Add modules as their functionality is implemented.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability and surface declaration, registration |
| `theme/` | Translate resolved PureLive theme into Fluent theme values |
| `widgets/` | Build a Fluent rendering for every control specification and both structural surfaces — the library's widget where it has one, a composition of the library's own parts where it does not |
| `interaction/` *(optional, not created)* | Keyboard, focus and TV-specific mapping, if Fluent's own focus treatment proves insufficient on a target |
| `icons/` *(optional, not created)* | Semantic icon remapping to Fluent icons |
| `diagnostics/` *(optional, not created)* | Adapter-local mapping diagnostics; the core diagnostic contract already covers what this adapter reports (§15) |
| `example/` *(optional, not created)* | Runnable demo with no business dependencies |
| `test/` | Contract, theme-mapping, control and switching tests, one directory per §16 concern |

## 5. Package dependencies

The package's `pubspec.yaml` as it stands:

```yaml
name: live_uikit_fluent
description: Fluent design-language adapter for live_uikit, rendering controls with fluent_ui widgets.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  fluent_ui: ^4.16.1
  flutter:
    sdk: flutter
  live_uikit:

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

`fluent_ui ^4.16.1` is the constraint the builders are written against, and the
workspace resolves it to 4.16.1 — the version every library claim in this
document cites, from the `ContentDialog` surface check in §9 to the missing
`Pivot` behind the composed tab view.

Because PureLive uses a Pub workspace, `live_uikit` is declared bare and resolved
as a workspace member rather than given a `path:`. Keep that convention aligned
with the rest of the family.

The adapter should not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation.

## 6. Public API

The public entry point exposes only the adapter's registration API:

```dart
// lib/live_uikit_fluent.dart

/// Fluent design-language adapter for `live_uikit`.
///
/// Public entry exposes only the registration API (§6).
library;

export 'package:live_uikit_fluent/src/adapter/fluent_registration.dart';
```

`fluent_registration.dart` provides exactly four public symbols:

| Symbol | Kind | Purpose |
|---|---|---|
| `createFluentAdapter()` | Function | Constructs the adapter for the composition root to register |
| `fluentAdapter` | `const LanguageAdapter` | The const adapter instance, usable directly where a constant is required |
| `fluentAdapterId` | `const String` | The stable runtime id, `'fluent'` |
| `fluentLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | `fluent_ui`'s own `FluentLocalizations.delegate`, appended by the app (§14) |

The builders, the theme mapper/scope and the `fluent`-prefixed types stay private: exporting them would let a business page construct a Fluent control directly and bypass runtime style switching. The package name in the export is a `package:` URI rather than a relative path, matching the other adapters and the guard that rejects cross-package private imports.

## 7. Adapter contract

`FluentLanguageAdapter implements LanguageAdapter` — the core's `abstract
interface class`, implemented directly, so this package states the whole contract
itself: five getters, `wrap`, the seventeen control builders and the two
structural surfaces.

The core declares:

```dart
abstract interface class LanguageAdapter {
  LiveDesignLanguage get language;
  String get id;
  String get displayName;
  LiveUiCapabilities get capabilities;
  LiveUiSurfaceCapabilities get surfaces;

  Widget wrap(BuildContext context, DesignToken token, Widget child);

  Widget button(...); Widget card(...); Widget textField(...);
  Widget switchWidget(...); Widget checkbox(...); Widget slider(...);
  Widget segmented(...); Widget progress(...); Widget select<T>(...);
  Widget tabBar(...); Widget scaffold(...); Widget appBar(...);
  Widget listRow(...); Widget navBar(...); Widget toast(...);
  Widget dialog(...); Widget tabView(...);

  Widget appHost(BuildContext context, LanguageHostSpec spec);
  Widget shell(BuildContext context, LanguageShellSpec spec);
}
```

`LiveUiControl` has exactly seventeen members and `LiveUiSurface` exactly two;
`capabilities` and `surfaces` are the two declarations a host consults, and
`LanguageRegistry` takes only the adapters it was handed.

Do not invent a competing adapter shape (an earlier draft of this document proposed a
`LiveUiAdapter` with a single `buildControl(context, control)` entry point; the core
never adopted it, and per-control methods are what the resolver, the capabilities set
and the adapters are built around).

The realized mapping:

| Contract member | Implementation here |
|---|---|
| `language` | `LiveDesignLanguage.fluent` |
| `id` | `'fluent'` (matches `fluentAdapterId`) |
| `displayName` | `'Fluent'` |
| `capabilities` | `fluentCapabilities` — all seventeen controls |
| `surfaces` | `fluentSurfaces` — `appHost` and `appShell` |
| `wrap` | `FluentThemeMapper.wrap` — installs the mapped `FluentTheme` scope |
| `button` | `FluentButtonBuilder.build` — mapped: `fluent.FilledButton` (primary/danger) or `fluent.Button`; the content is composed here |
| `card` | `FluentCardBuilder.build` — mapped: `fluent.Card` |
| `textField` | `FluentTextFieldBuilder.build` — mapped: `fluent.TextBox`; the error caption is composed here |
| `switchWidget` | `FluentSwitchBuilder.build` — mapped: `fluent.ToggleSwitch` |
| `checkbox` | `FluentCheckboxBuilder.build` — mapped: `fluent.Checkbox`; the label row is composed here |
| `slider` | `FluentSliderBuilder.build` — mapped: `fluent.Slider` |
| `segmented` | `FluentSegmentedBuilder.build` — composed: a row of `fluent.ToggleButton`, one checked |
| `progress` | `FluentProgressBuilder.build` — mapped: `fluent.ProgressBar` |
| `select<T>` | `FluentSelectBuilder.build<T>` — mapped: `fluent.ComboBox<T>` of `ComboBoxItem<T>` |
| `tabBar` | `FluentTabBarBuilder.build` — composed: `fluent.HoverButton` cells with Fluent's accent underline |
| `scaffold` | `FluentScaffoldBuilder.build` — mapped: `fluent.ScaffoldPage` |
| `appBar` | `FluentAppBarBuilder.build` — composed: `fluent.PageHeader` with the actions in its command slot |
| `listRow` | `FluentListRowBuilder.build` — mapped: `fluent.ListTile` |
| `navBar` | `FluentNavBarBuilder.build` — composed: a row of `fluent.ToggleButton`, icon over label |
| `toast` | `FluentToastBuilder.build` — mapped: `fluent.InfoBar` at the spec's severity |
| `dialog` | `FluentDialogBuilder.build` — mapped: `fluent.ContentDialog` used as a plain surface |
| `tabView` | `FluentTabViewBuilder.build` — composed: an `AnimatedSwitcher` page swap keyed by the index |
| `appHost` | `FluentHostBuilder.build` — `fluent.FluentApp.router` |
| `shell` | `FluentShellBuilder.build` — `fluent.NavigationView` over a `NavigationPane` of `PaneItem`s |

### Adapter identifier

Use one stable identifier everywhere:

```text
fluent
```

The identifier is a machine-readable value, not a localized label. Do not use
`fluent_ui`, `Fluent UI`, or a platform-dependent identifier as the runtime style id;
`fluentAdapterId`, `FluentLanguageAdapter.id` and `LiveDesignLanguage.fluent.name`
all resolve to `fluent`.

### Capability declaration

`fluentCapabilities` is a *declaration of fact*: it lists precisely the seventeen
controls `FluentLanguageAdapter` overrides — the whole of `LiveUiControl`, namely
`button, card, textField, switchWidget, checkbox, slider, segmented, progress,
select, tabBar, scaffold, appBar, listRow, navBar, toast, dialog, tabView`. There is
no `text`, `icon` or `menu` entry to declare: a modal surface is
`LiveUiControl.dialog`, a page switcher is `LiveUiControl.tabView`, and a tappable
row is `LiveUiControl.listRow`.

`fluentSurfaces` is the same claim about the two structural surfaces, and it is
declared apart from the controls because owning the window says nothing about
owning the navigation column, and vice versa. Fluent owns both: `FluentApp` for the
host and `NavigationView` for the shell.

`LiveUiCapabilities.supports()` and `LiveUiSurfaceCapabilities.supports()` are what
`LiveUiResolver.requireControl` and `requireSurface` consult, and both raise
`LiveUiCapabilityException` when a declaration has no matching override. The
declaration carries no grades — a control is served by this language or the call
throws — so the only distinction left to document is *how* it is served, and §9
states it per control: twelve of the seventeen are a one-for-one mapping onto a
widget of `fluent_ui`, and five are composed from the library's own parts.

Fluent renders `select` with the library's `fluent.ComboBox<T>`, which absorbs the
spec's generic item list, item-label function, placeholder and disabled state
without this adapter ever owning caller state.


## 8. Theme mapping

The core owns user preferences and resolves them into a normalized theme. The Fluent adapter translates that resolved theme into `FluentThemeData`.

The data flow uses the core's real types:

```text
UiConfig
     |
     v
LiveConfigProvider --(ThemeAlgorithms)--> DesignToken
     |
     v
LiveUiResolver.resolve(language) --> LanguageAdapter
     |
     v
adapter.wrap(context, token, child)
     |
     v
FluentThemeMapper --> FluentThemeBuilder --> FluentThemeData
     |
     v
FluentTheme scope
     |
     v
Fluent controls, host and shell
```

`LiveConfigProvider` carries the token and the resolved adapter down the tree together
as `LiveTheme`, and `wrap` reads the `DesignToken` from that theme without re-resolving
the language — the dispatch decision is already made (§10).

### 8.1 Theme properties to map

`FluentThemeBuilder.build` maps three properties today, and each unmapped row below
records why it is left alone rather than half-wired:

| Core theme property | Fluent mapping | Status |
|---|---|---|
| Brightness | `FluentThemeData.brightness` from `token.isDark` | Mapped |
| Accent / primary color | `FluentThemeData.accentColor` — `AccentColor.swatch({'normal': token.color.primary})` | Mapped |
| Font family | `FluentThemeData.fontFamily`, which flows into `typography.body.fontFamily` | Mapped |
| Text styles | Fluent `Typography` roles | Library default; the fork's type scale is not built from the token's roles |
| Density | `VisualDensity` and per-control `ControlSize` | Neither is wired from the token today: no builder reads `ControlSize`, and the library's own density default stands |
| Focus appearance | `FocusThemeData` | Library default — verify against the resolved `fluent_ui` version before claiming token control |
| Surface / background | `scaffoldBackgroundColor`, `cardColor`, `acrylicBackgroundColor`, `micaBackgroundColor`, `menuColor`, `resources` | Not token-mapped today; map a surface only when the token has an authoritative role for it |
| Transparency | Acrylic / Mica surfaces | Effect-budget concern (§15), not a token mapping |
| Motion | `AnimationDuration`/`AnimationCurve` on `AnimationFocusChangedBehavior`-style resources | Library defaults |

The accent mapping deserves a note: Fluent's accent is a swatch of named shades, and
its `dark`/`darker`/`light`/`lighter` getters fall back to `normal` when a shade is
missing. Supplying only `normal` is therefore the faithful mapping — inventing tonal
steps the token never declared is exactly the half-mapping §8.1 forbids.

Avoid forcing all eight style libraries to use identical widget dimensions. The core tokens define shared design intent; the Fluent adapter translates that intent into the closest appropriate Fluent presentation.

### 8.2 Theme scope

`wrap` installs a `fluent.FluentTheme` whose data comes from `FluentThemeBuilder` — that scope is the only theme mechanism this package puts into the tree, and every builder reads its colours and typography back through it.

Do not automatically nest a `FluentApp` inside an existing application solely to apply the Fluent style. A nested application widget can introduce competing navigation, localization, and application-level configuration. `FluentThemeScope` installs the theme and nothing more, for exactly that reason.

The single `FluentApp` in a Fluent tree is the one this adapter's `appHost` builds, and it is the window rather than a wrapper around one: the composition root picks the language, `LiveApp` dispatches to `appHost`, and `FluentApp.router` supplies the route transition, the overlay, the Fluent scrollbar and the library's strings (§9). A control that needs a `FluentTheme` ancestor finds the one `wrap` installed under that host.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `UiConfig`.
2. The core resolves a new theme.
3. The active adapter maps the new theme.
4. The relevant theme scope rebuilds.
5. Existing business state remains owned by the business widgets and controllers.

Do not cache a `FluentThemeData` object permanently if its source configuration can change. Rebuild or invalidate the mapped theme when the resolved theme changes.

## 9. Control implementation rules

Each control builder converts a core specification into a Fluent widget — the
library's own widget where `fluent_ui` has one for the job, a composition of the
library's parts where it does not — and the host and shell builders do the same for
the two structural surfaces.

### Button

- Map the spec's four variants onto the classes the library ships: `primary` and `danger` take `fluent.FilledButton`, `secondary` and `ghost` take `fluent.Button`.
- Press eligibility is computed in the builder from `enabled`, `loading` and `onPressed`; the label, its optional leading glyph, the `fluent.ProgressRing` shown while loading and the bare glyph of an icon-only button are all composed here, so nothing a Fluent button paints comes from outside this package.
- Preserve `onPressed`, enabled state, loading state, and accessibility labels, plus `focusNode`, `autofocus`, `expand` (a full-width wrap) and `tooltip` (the core's language-neutral `LiveTooltip`, since Fluent's own `TooltipButton` exists only on `Button` and choosing it would drop the filled variant).
- Do not place business actions inside the adapter.
- `ghost` keeps the plain `fluent.Button` and takes the theme's primary colour for its content, which is how Fluent draws a quiet action.
- `iconOnly` is handled in this builder: the content becomes the bare `Icon`, sized
  to the theme's label step and named by its tooltip (or its label, when the caller
  gave one) as the `semanticLabel`, so the empty label that satisfied the contract is
  never painted.
- `selected` is **not mapped**. `fluent_ui` gives `Button` and `FilledButton` no
  selected state, and reproducing one means painting over a surface the library
  owns; a toggled Fluent button therefore renders as an ordinary one, and the gap is
  recorded here instead. This is the documented remainder of `docs/decisions/0004`
  (§15).
- `style` is **not mapped either**. This button is the library's own widget and
  paints its own surface, so honouring a caller's inline `Style` would mean
  hand-painting an overlay over it — the same trade this section already refuses for
  `selected`.

### Card

- Prefer Fluent card visuals where they match the intended role: `fluent.Card` with the token padding, the `dense` step, and an explicit `padding` override.
- `selected` maps to the token primary background and `bordered` (or a selection) to the token border colour — the fork exposes both slots, so they are real, not approximations. The inline `Style` is read for those two properties only, `background` and `borderColor`; the rest of a `Style` has no slot a `fluent.Card` offers.
- Preserve content, padding, and click behavior; an interactive card also gets the pointer cursor. `focusNode`/`autofocus` belong to controls, not to a surface, so the card has no slot for them (§15).
- Do not assume every card is interactive.

### Text field

- Use the native Fluent text input (`fluent.TextBox`).
- Preserve the supplied controller, focus node, callbacks, enabled/read-only/obscure state, `maxLines`, keyboard type and action, prefix/suffix, and the inline `Style`.
- `errorText` has no Fluent slot on a bare `TextBox`: this builder composes the caption below the field, in the theme's error colour, so the message reaches the user instead of being dropped (§15).
- A field that obscures is pinned to one line, because `fluent.TextBox` would otherwise wrap a password across a multiline box.
- Do not create a second controller or silently own its lifecycle.
- Respect text direction, keyboard type, and accessibility labels.

### Switch

- Use the native Fluent toggle switch.
- Preserve controlled value and change callback.
- Do not introduce local persistent state.

### Checkbox

- Use the native Fluent checkbox. `fluent.Checkbox` paints no label of its own, so the trailing label is composed beside it in a `Row` laid out with this theme's body text role.
- Preserve checked/unchecked; the core contract has no indeterminate state, so none is advertised.
- Preserve disabled state and callback semantics: Fluent's callback is `bool?`, so the bridge closure exists only when the caller can be called back, and `focusNode`/`autofocus` pass to the fork.

### Slider

- Use the native Fluent slider.
- Preserve minimum, maximum, current value, and callbacks; a null callback or `enabled: false` disables.
- The value is clamped into `[min, max]` before it reaches the fork, which is the spec's range contract. This builder forwards the value, the bounds and the disabled state; the spec's `focusNode` is not handed to the control.
- The spec has no `divisions` field, so stepped behaviour is not invented here.
- Handle invalid ranges according to the core validation contract.

### Segmented

- Composed, not mapped: `fluent_ui` has no segmented track widget. The library's own answer to "one choice out of a row" is a group of `fluent.ToggleButton`s — what WinUI calls a segmented pick — so the row is assembled here and each segment reports its own index.
- The selection is the accent-filled checked state of the chosen `ToggleButton`, never a sliding thumb.
- `expand` gives every segment an equal share of the row; a disabled group is a group of buttons with no callback, which is the library's own inert state.

### Progress

- Use the native `fluent.ProgressBar`.
- Fluent's bar takes a percentage, so the spec's `0..1` fraction is scaled to `0..100`; a null value stays null and keeps the library's own indeterminate animation.
- `height` maps to the fork's `strokeWidth` and `barColor` overrides the primary tint, with the track taken from the theme's secondary fill.
- `showLabel` has no slot on `ProgressBar` and is dropped rather than overlaid with a hand-built label (§15).

### Select

- Use the native `fluent.ComboBox<T>` with one `fluent.ComboBoxItem<T>` per spec item, so the caller's own value type survives the swap and the selected value comes back unchanged.
- A disabled select drops its callback — `fluent_ui` disables the combo box whenever `onChanged` is null — and keeps the placeholder visible through `disabledPlaceholder`.
- The adapter stores no selection of its own; the spec's `value` is the only truth.

### Tab bar

- Composed, not mapped. The library's tab widget, `fluent.TabView`, is a tab *view*: every `Tab` carries a body and the widget paints a content area under the strip. This contract's tab bar is a strip only — the caller's router owns the body, exactly as it does in every other language — so the strip is assembled here from `fluent.HoverButton`, the same building block the library's own navigation cells are made of.
- The selection is drawn the way Fluent draws a selected header: accent-coloured text and label weight over a short accent underline, on the theme's inactive colour for everything unselected. That mark is what separates a Fluent tab from a Fluent segment.
- Icons precede the label and take the same tint as the text.
- `spacing` has no counterpart: the cells use the library's own header padding, and the knob is recorded as unmapped rather than converted into a gap no Fluent header has (§15). `enabled: false` removes the taps and keeps the labels.

### Scaffold

- Use the native `fluent.ScaffoldPage`, the library's own page frame: its `header` slot takes the dispatched app bar, its `bottomBar` slot the dispatched navigation strip, and `resizeToAvoidBottomInset` is Fluent's name for `avoidKeyboard`.
- `extendBodyBehindAppBar` is not mapped: a Fluent page draws its header inside the content column anyway, so the body already reaches the top edge the way the flag asks.
- `background` has no slot — the frame takes its surface from `FluentTheme` — so an override is painted behind the page in a `DecoratedBox`.
- `floatingActionButton` is placed by this builder over the frame, at the trailing bottom corner, inset by the environment's page padding or the theme's medium step: Fluent pages have no FAB slot of their own.

### App bar

- Use `fluent.PageHeader`, the library's own page bar and the one widget `ScaffoldPage.header` is designed to take, with `leading`, the title in the theme's title type role, and a command area.
- `actions` are arbitrary already-built widgets while `fluent.CommandBar` constructs its own items from icons and callbacks the spec does not carry, so the actions enter the header's `commandBar` slot as a row rather than through that widget.
- `bottom` — normally the dispatched tab strip — is stacked under the header in a column, because a Fluent page has one header row.
- `centerTitle` and `height` are not mapped: a Fluent header is left-titled and content-sized, and centring it would be the bar making a statement about another platform rather than about the caller (§15). `background` is applied through a `DecoratedBox`, since the header takes its surface from the theme.

### List row

- Use the native `fluent.ListTile`: leading, title, subtitle, trailing, `onPressed` and focus are the same parts the spec carries, so the row's hover fill, ink and typography come from `FluentTheme`.
- `selected` maps onto the library's `tileColor` through a state-resolved colour, because `ListTile` has no selected state to set.
- `onLongPress` is recognised by a gesture wrapper around the whole tile, and `divided` draws its own hairline under the row — Fluent's `Divider` takes no colour, so the theme's divider colour and line width are applied to a box instead.
- Title and subtitle are single-line and ellipsized; a row that needs to wrap is a card, not a row.

### Nav bar

- Composed, not mapped. Fluent has no bottom bar: the library's destinations live in a `NavigationView` pane, which is the shell and not this control, so a page that asks for a strip of destinations gets the library's own mutually-exclusive control instead — a row of `fluent.ToggleButton`s, one checked, each carrying its icon over its label.
- The strip stays inside `FluentTheme`'s metrics and accent, and it is what lets a `bottomBar` slot on a Fluent page be answered in Fluent rather than in a bar shape some other library drew.
- `enabled: false` is the library's inert state: the buttons keep their labels and lose their callback.

### Toast

- Use `fluent.InfoBar`, the library's answer to a transient status message, at the severity the spec's type names: info, success, warning and error map straight across, and the library draws the matching glyph.
- `icon` and `accent` are recorded as unmapped: an `InfoBar` picks both from its severity, and forcing an override glyph or colour onto it would give a Fluent screen a banner Fluent does not recognise (§15).
- The message is a banner, not a pill — full width, its own severity colour, no shadow — handed to the library widget as its title with the long layout enabled, which is the arrangement the library recommends for content that wraps.
- Placement, the fade-and-slide and the dismissal timer belong to the core (`LiveToast`), so the message still arrives from the top of the window and leaves by itself.

### Dialog

- Mapped: `fluent.ContentDialog` is the library's own dialog surface and works as a plain widget. Verified against fluent_ui 4.16.1 (`lib/src/controls/flyouts/content_dialog.dart`): its `build` only asserts `debugCheckHasFluentTheme`, so it needs the `FluentTheme` that `wrap` installs and never a `Navigator` or a route — which is what lets the adapter hand it to the core's route.
- The division of labour: the surface belongs to this builder; the route, the barrier, the fade-and-scale and the dismissal belong to core's `showLiveDialog`, which already frames the child it is given. This builder starts no `fluent.showDialog` and adds no `Center`.
- `dismissible` is the core's barrier knob and is deliberately not drawn here.
- `icon` has no slot in the library widget, so the glyph rides above the heading inside the title widget, which `ContentDialog` still paints with its own title style.
- An empty action list is handed to the library as null — an empty list would paint the action band with nothing in it. The surface keeps the library's `kDefaultContentDialogConstraints` (the 368px Windows guideline); where core's frame is narrower, the tighter constraint wins.

### Tab view

- Composed, not mapped: `fluent_ui` 4.16.1 ships no page-switcher widget. Its `TabView` is browser-style tabs with the body fused to the strip, and this version has no `Pivot`.
- The view is an `AnimatedSwitcher` keyed by the page index, in the library's own motion vocabulary: Windows replaces a tab body in place with a cross-fade — the timing the library's dialogs fade with is `FluentThemeData.fastAnimationDuration` — and never slides pages sideways, so there is no `PageView` and no shape change here.
- `onIndexChanged` reports a viewer-driven swipe, which a Fluent view does not have: the tab strip owns the index and the caller pumps it through `index` (§15).
- The duration is the spec's, not the theme's, because the contract hands the change length to the caller. An index outside the page list is clamped rather than thrown — the strip and the view are driven separately, and a frame where the two disagree must not take the window down.

### App host

- Mapped to `fluent.FluentApp.router`, the library's own host. It is what makes a Fluent page behave like Windows rather than merely look like it for one frame: the route transition, the overlay a `ContentDialog` or `Flyout` opens into, the Fluent scrollbar and the navigation-view strings all come from here. Hosting the same tree in another library's app widget would keep that library's page slide, dialog barrier and ink splash underneath the Fluent controls.
- The theme is handed to both `theme` and `darkTheme`: the token has already picked the brightness, so the host must not re-pick it from the platform.
- `title`, `onGenerateTitle`, `localizationsDelegates`, `supportedLocales`, `locale`, `builder` and `debugShowCheckedModeBanner` pass straight through to the router constructor (§14).

### Shell

- Mapped to `fluent.NavigationView` over a `fluent.NavigationPane` of `fluent.PaneItem`s — the library's own structural widget: a pane of destinations down the left, the selection painted with the sticky indicator, the content in the open area.
- The spec's destinations map onto the pane one-for-one. Because the app's router — not the pane — decides what the body shows, the body comes from the library's `paneBodyBuilder`; giving each item a body of its own would put a second, competing copy of the page tree inside the shell.
- `placement` has no direct counterpart and is answered rather than dropped: the pane is vertical, so `rail` takes `PaneDisplayMode.compact`, `bottom` takes `PaneDisplayMode.top` — Windows' horizontal navigation strip — and `adaptive` and `none` take the library's own responsive `auto`.
- `trailing` is dropped: the pane has no free-form footer widget slot, only further pane items, so a shell asked for one leaves it out and the app moves that entry into the page's own actions (§15).
- Selection is read back from `selectedId` and reported through `onSelected`; a disabled destination is refused in the pane callback rather than handed on, because the pane has no per-item disabled state to draw. The shell keeps no second copy of the navigation state.

### Control mapping rule

Builders must map semantic intent, not inspect business page types.

For example, a button builder can receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup. The core's
registry is a const map from language to adapter — there is nothing else to hand it:

```dart
const appLanguageRegistry = LanguageRegistry(
  adapters: {
    LiveDesignLanguage.fluent: fluentAdapter,
    // …one entry per language this build links in
  },
);
```

`fluentAdapter` is the exported const instance; `createFluentAdapter()` is there for a
root that wants to construct it in a non-const position. Both return the same
`FluentLanguageAdapter`.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active style.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_fluent` must not register itself through global static initialization or require the business layer to import it.

### Registration failure

There is no partial registration to detect. What the composition root has to get right, and what the core surfaces when it does not:

- A language the app claims to support with no entry in `adapters`: `LiveUiResolver.resolve` throws `LiveUiResolutionException`. That is a boot-time wiring fault, not a render.
- A control or a surface declared in `fluentCapabilities`/`fluentSurfaces` with no matching override on the adapter: `requireControl`/`requireSurface` throw `LiveUiCapabilityException`. The adapter defines every member today, so this only fires when a declaration and the methods drift apart — which §17 also asserts statically, so the build fails before a device ever sees the exception.
- Duplicate adapter ids, and a registry built without a language it was asked to serve: both are the same fault as the first bullet, caught the first time the resolver is consulted.

Silently choosing a different library's rendering is not an available behavior, and a host must not implement one either: the alternative to a loud fault is a window painted by a library the user did not select.

## 11. Runtime style switching

A business widget should use the core API:

```dart
LiveButton(
  label: 'Save',
  onPressed: saveSettings,
)
```

It must not contain conditional style selection:

```dart
// Avoid style-specific branching in business packages.
if (style == 'fluent') {
  // Build a Fluent button.
} else {
  // Build another library's button.
}
```

The intended rendering flow is:

```text
Business widget
      |
      v
LiveButton
      |
      v
LiveUiRuntime
      |
      v
Selected adapter
      |
      +---- Fluent adapter
      +---- Material adapter
      +---- Cupertino adapter
      +---- Other registered adapters
```

Switching adapters changes rendering and interaction presentation. It must not replace business controllers, reset form values, or recreate unrelated application services.

The switch is the whole tree, not only the controls: `LiveApp` re-hosts through the new language's `appHost`, the shell redraws from that adapter's `shell`, and every control dispatches to its builder. A language this build did not register is not a target the app can switch to — the resolver raises `LiveUiResolutionException` (§10). Nothing in this package holds a value, a controller or a focus node of its own, so there is no Fluent-side state a switch could lose; the cross-language switch itself is an application-level test (§16), while `test/integration/` proves the re-theme through this adapter leaves the caller's controller text intact.

## 12. Keyboard, focus, and TV support

PureLive targets desktop and Android TV as well as mobile platforms. Fluent styling must therefore be tested for more than mouse input.

The adapter should account for:

- Keyboard navigation and focus traversal.
- Visible focus indication.
- Enter and Space activation semantics.
- Disabled controls being skipped or handled correctly.
- Focus restoration after dialogs or menus.
- Remote-control navigation on Android TV.
- Predictable focus behavior after runtime style switching.
- Accessibility semantics for interactive controls.

`fluent_ui` provides focus-related theming capabilities, including reveal-focus styling. Its availability and behavior must be verified against the exact resolved package version. <Cite refs={["turn568076search1","turn568076search11"]}/>

Do not assume that desktop keyboard behavior automatically guarantees Android TV D-pad compatibility. Test the actual controls with the supported TV input devices and use the core interaction policy to fill gaps.

## 13. Platform behavior

Fluent is a visual style choice, not a declaration that every operating system provides Windows-native controls.

| Platform | Expected behavior |
|---|---|
| Windows | Fluent styling with desktop keyboard and mouse support |
| macOS | Fluent styling while retaining appropriate macOS application integration |
| Linux | Fluent styling; verify platform-specific rendering and dependencies |
| Android | Fluent styling with touch-friendly sizing |
| Android TV | Fluent styling plus explicit D-pad and focus testing |
| iOS | Fluent styling while retaining iOS lifecycle and accessibility behavior |

Acrylic or transparency effects must degrade gracefully where unavailable or inappropriate. Transparency is the only thing this family degrades into a reported condition: an effect the environment cannot afford fires the core's `unsupportedEffect` diagnostic, and a verified flat surface stands in (§15). This adapter requests no acrylic of its own — `FluentThemeData` paints the library's backgrounds, and the surface roles stay at the library's defaults rather than being token-mapped (§8.1) — so a Fluent window has no effect here to disable, and a Fluent run reports nothing unless the device refuses one.

The same rule covers what a platform does not give the interaction model: a `NavigationView` pane that has no room for its labels, or keyboard focus on a target with no keyboard, is a §12 verification concern rather than a control this adapter stops drawing.

Do not make native window APIs a required dependency of the basic adapter.

## 14. Localization and accessibility

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints.
- Use the application's localization configuration.
- Avoid introducing a second, conflicting locale source.
- Test long translated labels and right-to-left layouts.
- Verify focus visibility, text contrast, and touch target sizing.

### The Fluent delegate is required, not optional

`fluent_ui` resolves its own `FluentLocalizations` type, which the core localizer never
supplies — it covers Flutter's global delegates only. Left out, a Fluent control throws
"No FluentLocalizations found" the first time it builds, which is exactly what the §16
suites hit before this was wired. The package therefore exports the delegate and the
composition root appends it:

```dart
const List<LocalizationsDelegate<dynamic>> fluentLocalizationsDelegates = [
  fluent.FluentLocalizations.delegate,
];

LiveApp(
  routerConfig: router,
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...fluentLocalizationsDelegates,
  ],
  supportedLocales: /* the app's locale policy */,
)
```

`LiveApp` hands that list to this language's host, and `FluentApp.router` appends its own
`FluentLocalizations.delegate` after whatever the caller passed. Appending the exported
delegate anyway is what keeps the string source identical whether the tree is hosted by
`FluentApp` or — as every `test/widgets/` harness here does — by a `MaterialApp` around
the subtree, which supplies nothing Fluent reads.

Rules:

- Order matters: the core delegates come first so app-level strings keep priority and
  Fluent supplies only its own internal strings; a test that swaps the order and still
  resolves a core string is the check that holds this.
- `live_uikit_fluent` must not install a delegate itself, wrap the app in a localization
  widget, or override the global locale — that is the composition root's job. The one
  exception is the host this adapter owns: `FluentHostBuilder` passes the spec's delegates
  straight to `FluentApp`, which then adds the library's own.
- `supportedLocales` must include a locale every active delegate covers; English is the
  safe common denominator.
- The adapter adds no `flutter_localizations` dependency of its own; the app supplies the
  localizer and this package contributes only the delegate list.

## 15. Error handling and diagnostics

Two different things can go wrong, and they travel by two different routes.

**Faults are thrown.** A language this build did not register is a
`LiveUiResolutionException` out of `LiveUiResolver.resolve`; a control or surface
declared in `fluentCapabilities`/`fluentSurfaces` with no matching override on the
adapter is a `LiveUiCapabilityException` out of `requireControl`/`requireSurface`.
Neither is a condition the adapter can render its way out of — the only substitute for
a control this language cannot draw is a control drawn by some other language — so the
resolver raises and the composition root hears about it.

**Degradations are reported.** `LiveUiDiagnosticCode` has exactly one member,
`unsupportedEffect`, for an effect the environment cannot afford — backdrop blur or a
translucency a target will not pay for, answered with a verified flat stand-in. That is
the only code a Fluent run can put on the wire, and this adapter asks for no such effect
itself (§13), so the ordinary case is a quiet sink.

Use the diagnostics contracts from `live_uikit`. Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- A spec field the library has no slot for is documented in §9 and left alone, never
  faked with a hand-painted overlay: `LanguageButtonSpec.selected` and `.style`,
  `LanguageCardSpec.focusNode` and `.autofocus`,
  `LanguageProgressSpec.showLabel`, `LanguageTabsSpec.spacing`,
  `LanguageAppBarSpec.centerTitle` and `.height`,
  `LanguageScaffoldSpec.extendBodyBehindAppBar`, `LanguageToastSpec.icon` and `.accent`,
  `LanguageDialogSpec.dismissible` (the core's barrier knob),
  `LanguageTabViewSpec.onIndexChanged` and `LanguageShellSpec.trailing`. An unmapped
  field is not a missing control, and the capability declaration says so.
- Invalid control data follows the core validation rules. Where a value is merely out of
  range a builder clamps it and records why: the slider clamps into `[min, max]`, and the
  tab view clamps the index into the page list rather than throwing on a frame where the
  strip and the view briefly disagree.
- Programming errors are not swallowed.
- Diagnostics avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

Four directories, one per concern: `test/adapter/` (the contract and the resolver's verdict), `test/theme/` (§8.1 mapping and the §8.3 re-skin), `test/widgets/` (every control driven through a real `LiveConfigProvider` + `LiveUiResolver`, so the assertions are about the dispatch path and not a builder in isolation — `stub_router.dart` lives there too, a router that goes nowhere so a host can be pumped without the app's `GoRouter`), and `test/integration/` (the whole contract resolved, and a re-theme with the caller's state intact).

### Unit tests

- Stable adapter id `fluent`, display name, language, and `fluentCapabilities` truthfulness. The declared set is asserted to be the whole of `LiveUiControl.values`, so a control added to the contract cannot join the undeclared side silently — the suite has to be told (§17).
- `fluentSurfaces` covers both members of `LiveUiSurface`, and nothing else is claimed.
- Resolution: `LiveUiResolver.resolve` hands back this adapter, `requireControl` passes for all seventeen controls and `requireSurface` for both surfaces, and a language this build did not register raises `LiveUiResolutionException` rather than rendering anything.
- Brightness, accent and global-font mapping: `token.color.primary` becomes the `AccentColor.swatch` the fork reads, with its shade getters falling back to `normal` rather than invented tones (§8.1).
- Theme invalidation: a token change re-skins through `wrap` without a restart.

### Widget tests

- Button callback, disabled and loading gating, filled-vs-plain variant mapping, and `expand`/`tooltip`/`focusNode`/`autofocus` preserved.
- Card tap, long-press, pointer cursor, padding, `dense`, explicit padding, and the selected/bordered mapping.
- Text field controller preservation and change reporting, prefix/suffix, the error caption, an inline `Style` override, and a field that stays disabled.
- Switch value updates; checkbox null-callback disabling; slider range and disable-by-null.
- Progress indeterminate, fraction→percent scaling, `strokeWidth` and the `barColor` tint.
- Select typed items through `fluent.ComboBox<String>`.
- The chrome set at its own widgets: `LiveScaffold` → `fluent.ScaffoldPage`, `LiveAppBar` → `fluent.PageHeader`, `LiveListRow` → `fluent.ListTile` carrying both lines and its tap, `LiveToast` → `fluent.InfoBar`.
- The controls this language composes rather than maps: a segmented track is three `fluent.ToggleButton` with exactly one checked and a tap that reports its index; a tab strip reports its index and draws its tab icons; a destination strip reports its index, and a disabled one keeps its labels while reporting nothing.
- Dialog and tab view: the dialog surface is `fluent.ContentDialog` inside the core's route, with the title, body and action button all reaching the screen; the tab view replaces the page in place and never slides it.
- Host and shell: `LiveApp` builds a `fluent.FluentApp` and no `MaterialApp`, and this package's card and field render under that host — so neither leans on Material for an ink host or a selection toolbar; `LiveAppShell` builds `fluent.NavigationView`, shows the page the shell was handed, reports the destination by id, and reads a `bottom` request back as `PaneDisplayMode.top`.
- A page dense with chrome — frame, header, tab strip, segmented track and two destination strips, all dispatched at once — builds without an exception.
- Fluent controls resolve their own `FluentLocalizations` and need an overlay, which the host app supplies through the appended delegates (§14).

### Integration tests (`test/integration/fluent_style_switching_test.dart`)

- All seventeen controls resolve through this adapter and `requireControl` passes for every one of them; both structural surfaces pass `requireSurface` (§16.3).
- No diagnostic names a control or a surface. That is the load-bearing assertion of this suite: a Fluent run reports no degrade at all, because every member of the contract is served here.
- `fluent.TextBox`, `fluent.ToggleSwitch` and `fluent.ComboBox<String>` stay on the library path across a re-theme — the SDK `TextField` is found nowhere in the tree — and the caller's controller text survives it.
- The composed `segmented` track stays callable and the typed `select` path stays intact on both sides of the re-theme (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum, include Windows desktop, a mobile target, and Android TV in the planned validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_fluent` depends on `live_uikit`.
- `live_uikit_fluent` does not depend on other style adapters.
- The core package does not depend on `fluent_ui`, and no package but this one may depend on or import it.
- Business packages do not import `package:fluent_ui/fluent_ui.dart`.
- All public exports are intentional: the barrel exports `fluent_registration.dart` and nothing else, so the builders, the theme types and the two declaration constants stay internal.
- The adapter's declared capabilities are compared with the control methods it actually overrides, and its declared surfaces with the `appHost`/`shell` methods. Declaring without overriding, and overriding without declaring, both fail.
- Every `package:fluent_ui/` import inside this package uses the `as fluent` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `fluentCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate. The prose uses the
  guard's vocabulary — `button, card, text field, switch, checkbox, slider, segmented,
  progress, select, tab bar, scaffold, app bar, list row, nav bar, toast, dialog, tab
  view` — and all seventeen are declared, so the sentence is the whole contract.
- A package that documents a localization delegate must export one, and one that exports
  a delegate must document it; this adapter is on the documented list (§14).
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_fluent
flutter analyze packages/live_uikit_fluent
flutter test packages/live_uikit_fluent
```

Run these from the workspace root with the repository's normal Flutter SDK and workspace resolution.

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Align the adapter with the finalized core contract.
- Define the stable ID and capability declarations.
- Register Fluent from the application composition root.
- Add a basic registration test.

### Phase 2 — Theme integration ✅

- Implement theme mapping.
- Add the Fluent theme scope.
- Test brightness, accent color, typography, and density.
- Verify runtime theme updates.

### Phase 3 — Core controls ✅

Twenty builders — one per control and one per structural surface — each declared in
`fluentCapabilities` or `fluentSurfaces` and exercised through the real adapter path in
`test/widgets/`:

1. Button (`fluent.FilledButton` / `fluent.Button`)
2. Card (`fluent.Card`)
3. Text field (`fluent.TextBox`)
4. Switch (`fluent.ToggleSwitch`)
5. Checkbox (`fluent.Checkbox`)
6. Slider (`fluent.Slider`)
7. Segmented (composed: a row of `fluent.ToggleButton`)
8. Progress (`fluent.ProgressBar`)
9. Select (`fluent.ComboBox<T>`)
10. Tab bar (composed: `fluent.HoverButton` cells with the accent underline)
11. Scaffold (`fluent.ScaffoldPage`)
12. App bar (composed: `fluent.PageHeader` with the actions in its command slot)
13. List row (`fluent.ListTile`)
14. Nav bar (composed: a row of `fluent.ToggleButton`)
15. Toast (`fluent.InfoBar`)
16. Dialog (`fluent.ContentDialog`)
17. Tab view (composed: an `AnimatedSwitcher` page swap)

Plus the two surfaces: `appHost` on `fluent.FluentApp.router` and `shell` on
`fluent.NavigationView`.

Every control the contract names is therefore answered in this language, and the five
composed ones say so in their builder (§9). Adding a control to `LiveUiControl` means a
builder, an override and a capability entry in the same change — §17's drift gate fails
the build otherwise. There is no "text" or "icon" control in the contract to map: an
earlier draft of this section listed both, and `LiveUiControl` has no such member.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: focus nodes reach the fork button, checkbox, switch, list row and text field where `fluent_ui` accepts them — `fluent.Card` exposes no focus slot at all, and the slider's node is not handed over here (§9) — and a disabled control is wired dead rather than decorative.
- Open, needs hardware: keyboard navigation and focus rings on a real Windows target, Android TV D-pad.
- Verify keyboard navigation and focus behavior.
- Test Android TV D-pad behavior.
- Validate semantics and accessibility.
- Record the spec fields the library has no slot for in §9, rather than inventing an overlay that only looks like one (§15).

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Open: integration tests for style switching — a cross-adapter switch is an application-level concern, since §3.3 forbids adapter-to-adapter dependencies.
- Verify all claimed platforms.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `fluent_ui` only for its core integration.
- [x] It implements the actual core adapter contract — every one of the seventeen controls and both structural surfaces, on the interface itself.
- [x] It uses the stable adapter ID `fluent`.
- [x] It reports accurate control capabilities, and `fluentSurfaces` accurately owns the host and the shell; §17 asserts both declarations against the methods.
- [x] It maps the resolved core theme into Fluent theme values.
- [x] It renders every control with `fluent_ui`'s own widget, or composes it from that library's own parts where the library has none.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell unnecessarily — `wrap` installs a `FluentTheme` scope, and `FluentApp` appears exactly once, as the host (§8.2/§9).
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the button's `focusNode`/`autofocus` are asserted (§16); the visible focus ring, D-pad traversal and Narrator behaviour need Windows hardware.
- [x] A control or surface this language cannot serve is a raised fault rather than a degrade, and only an effect the device cannot afford is reported (§15).
- [x] Diagnostics use the core's contract.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_fluent` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, the public controls, the theme model, the runtime selection, and the resolution faults that surface a mis-wired composition root.
- `live_uikit_fluent` implements that contract end to end: all seventeen controls, both structural surfaces, and the Fluent theme the whole tree reads.
- `fluent_ui` supplies the underlying Fluent widgets and theme facilities — and, where the library has no widget for a control, the parts this adapter composes the answer out of.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls — and guarantees that the library doing the rendering is the one the user selected, from the window frame down to the last strip.
