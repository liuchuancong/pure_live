# `live_uikit_fluent` Architecture and Integration Specification

- **Package:** `live_uikit_fluent`
- **Parent package:** `live_uikit`
- **Implementation library:** `fluent_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_fluent` is the Fluent Design adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `fluent_ui` controls and Fluent-specific visual behavior. It must not implement business pages or duplicate the core theme system.

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
7. **Graceful fallback.** Unsupported controls must follow the fallback policy defined by `live_uikit`, not silently change behavior.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Fluent theme mapping.
- Fluent widget construction.
- Fluent-specific control defaults.
- Fluent-specific icon mapping where supported.
- Fluent focus and keyboard interaction integration.
- Mapping shared control specifications to Fluent controls.
- Reporting implemented capabilities to the core registry.
- Adapter-level tests and compatibility checks.

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

The tree below is the package as it exists today: eight native builders, three theme
files, and one test directory per §16 concern. The modules after it are expansion
points that have not been created.

```text
packages/
└── live_uikit_fluent/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_fluent.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── fluent_adapter.dart
    │       │   ├── fluent_capabilities.dart
    │       │   └── fluent_registration.dart
    │       ├── theme/
    │       │   ├── fluent_theme_mapper.dart
    │       │   ├── fluent_theme_builder.dart
    │       │   └── fluent_theme_scope.dart
    │       └── widgets/
    │           ├── fluent_button_builder.dart
    │           ├── fluent_card_builder.dart
    │           ├── fluent_checkbox_builder.dart
    │           ├── fluent_progress_builder.dart
    │           ├── fluent_select_builder.dart
    │           ├── fluent_slider_builder.dart
    │           ├── fluent_switch_builder.dart
    │           └── fluent_text_field_builder.dart
    ├── live-uikit-fluent.md
    └── test/
        ├── adapter/
        │   └── fluent_capabilities_test.dart
        ├── theme/
        │   └── fluent_theme_test.dart
        ├── widgets/
        │   └── fluent_native_controls_test.dart
        └── integration/
            └── fluent_style_switching_test.dart
```

Do not create empty files just to match this tree. Add modules as their functionality is implemented.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration |
| `theme/` | Translate resolved PureLive theme into Fluent theme values |
| `widgets/` | Build Fluent controls from core widget specifications |
| `interaction/` *(optional, not created)* | Keyboard, focus and TV-specific mapping, if Fluent's own focus treatment proves insufficient on a target |
| `icons/` *(optional, not created)* | Semantic icon remapping to Fluent icons |
| `diagnostics/` *(optional, not created)* | Adapter-local mapping diagnostics; the core contracts already cover control fallbacks |
| `example/` *(optional, not created)* | Runnable demo with no business dependencies |
| `test/` | Contract, theme-mapping, control and switching tests, one directory per §16 concern |

## 5. Package dependencies

Initial `pubspec.yaml`:

```yaml
name: live_uikit_fluent
description: Fluent UI adapter for the PureLive unified UI system.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  fluent_ui: ^4.16.1
  live_uikit:
    path: ../live_uikit

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

The version shown for `fluent_ui` matches the intended dependency in this architecture draft. Verify it against the resolved workspace dependency before merging.

Because PureLive uses a Pub workspace, keep the `live_uikit` dependency aligned with the repository's workspace conventions. If all internal packages are workspace members, use the repository's chosen path or workspace dependency policy consistently.

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

`FluentLanguageAdapter extends SharedLanguageAdapter`, which already implements the
core `abstract interface class LanguageAdapter` — every control has a working
token-driven default, so the adapter overrides only what `fluent_ui` renders
natively plus `wrap`. The contract is exactly:

- Getters: `language`, `id`, `displayName`, `capabilities`.
- Methods: `wrap`, `button`, `card`, `textField`, `switchWidget`, `checkbox`,
  `slider`, `segmented`, `progress`, `select<T>`, `tabBar`.

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
| `capabilities` | `fluentCapabilities` |
| `wrap` | `FluentThemeMapper.wrap` — installs the mapped `FluentTheme` scope |
| `button` | `FluentButtonBuilder.build` — native (`FilledButton` vs `Button` by variant) |
| `card` | `FluentCardBuilder.build` — native `fluent.Card` |
| `textField` | `FluentTextFieldBuilder.build` — native `fluent.TextBox` |
| `switchWidget` | `FluentSwitchBuilder.build` — native `fluent.ToggleSwitch` |
| `checkbox` | `FluentCheckboxBuilder.build` — native `fluent.Checkbox` |
| `slider` | `FluentSliderBuilder.build` — native `fluent.Slider` |
| `progress` | `FluentProgressBuilder.build` — native `fluent.ProgressBar` |
| `select<T>` | `FluentSelectBuilder.build<T>` — native `fluent.ComboBox<T>` |
| `segmented`, `tabBar` | Inherited from `SharedLanguageAdapter` — shared token renderer |

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

`fluentCapabilities` is a *declaration of fact*: it lists precisely the eight
controls `FluentLanguageAdapter` overrides. `LiveUiControl` has exactly ten members
— `button, card, textField, switchWidget, checkbox, slider, segmented, progress,
select, tabBar` — so there is no `text`, `icon`, `dialog`, `menu` or "complex
navigation" entry to declare; those are not part of the contract.

Fluent is the only adapter in this family to render `select` natively:
`fluent.ComboBox<T>` absorbs the spec's generic item list, item-label function,
placeholder and disabled state without the adapter owning caller state. `segmented`
and `tabBar` stay on the shared renderer and the resolver reports
`controlUnsupported` for them (§15).

The three implementation kinds come from the core —
`LiveImplementationKind.adapterNative`, `.shared`, `.custom` — and the contract test
asserts that the declared set matches the overrides, so a declaration that lies about
support fails the build (§16/§17).


## 8. Theme mapping

The core owns user preferences and resolves them into a normalized theme. The Fluent adapter translates that resolved theme into `FluentThemeData`.

The data flow is:

```text
LiveUiConfig
     |
     v
LiveUiThemeResolver
     |
     v
ResolvedLiveUiTheme
     |
     v
FluentThemeMapper
     |
     v
FluentThemeData
     |
     v
FluentTheme scope
     |
     v
Fluent controls
```

### 8.1 Theme properties to map

`FluentThemeBuilder.build` maps three properties today, and each unmapped row below
records why it is left alone rather than half-wired:

| Core theme property | Fluent mapping | Status |
|---|---|---|
| Brightness | `FluentThemeData.brightness` from `token.isDark` | Mapped |
| Accent / primary color | `FluentThemeData.accentColor` — `AccentColor.swatch({'normal': token.color.primary})` | Mapped |
| Font family | `FluentThemeData.fontFamily`, which flows into `typography.body.fontFamily` | Mapped |
| Text styles | Fluent `Typography` roles | Library default; the fork's type scale is not built from the token's roles |
| Density | `VisualDensity` and per-control `ControlSize` | Control-level only (`FluentButtonBuilder` maps `ControlSize`); no token-driven global density is wired |
| Focus appearance | `FocusThemeData` | Library default — verify against the resolved `fluent_ui` version before claiming token control |
| Surface / background | `scaffoldBackgroundColor`, `cardColor`, `acrylicBackgroundColor`, `micaBackgroundColor`, `menuColor`, `resources` | Not token-mapped today; map a surface only when the token has an authoritative role for it |
| Transparency | Acrylic / Mica surfaces | Effect-budget concern (§15), not a token mapping |
| Motion | `AnimationDuration`/`AnimationCurve` on `AnimationFocusChangedBehavior`-style resources | Library defaults |

The accent mapping deserves a note: Fluent's accent is a swatch of named shades, and
its `dark`/`darker`/`light`/`lighter` getters fall back to `normal` when a shade is
missing. Supplying only `normal` is therefore the faithful mapping — inventing tonal
steps the token never declared is exactly the half-mapping §8.1 forbids.

Avoid forcing all seven style libraries to use identical widget dimensions. The core tokens define shared design intent; the Fluent adapter translates that intent into the closest appropriate Fluent presentation.

### 8.2 Theme scope

The adapter must provide a Fluent theme scope around the widgets it builds when needed.

Do not automatically nest a `FluentApp` inside an existing application solely to apply the Fluent style. A nested application widget can introduce competing navigation, localization, and application-level configuration.

Prefer the theme-scope mechanism supported by the installed `fluent_ui` version. Use `FluentApp` only when the application composition root deliberately chooses it as the application shell.

### 8.3 Runtime updates

When the user changes brightness, accent color, font, density, or style:

1. The application updates `LiveUiConfig`.
2. The core resolves a new theme.
3. The active adapter maps the new theme.
4. The relevant theme scope rebuilds.
5. Existing business state remains owned by the business widgets and controllers.

Do not cache a `FluentThemeData` object permanently if its source configuration can change. Rebuild or invalidate the mapped theme when the resolved theme changes.

## 9. Control implementation rules

Each control builder converts a core specification into a Fluent widget.

### Button

- Map primary, secondary, subtle, and destructive intent to supported Fluent variants (primary/danger → `fluent.FilledButton`, the rest → `fluent.Button`).
- Press eligibility, loading spinner and label layout come from the shared seam, so a Fluent button cannot disagree with a token-rendered one (§2.3).
- Preserve `onPressed`, enabled state, loading state, and accessibility labels, plus `focusNode`, `autofocus`, `expand` (a full-width wrap) and `tooltip` (the core's language-neutral `LiveTooltip`, since Fluent's own `TooltipButton` exists only on `Button` and choosing it would drop the filled variant).
- Do not place business actions inside the adapter.
- Use a shared fallback if a requested variant has no direct Fluent equivalent.
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

### Card

- Prefer Fluent card visuals where they match the intended role: `fluent.Card` with the token padding, the `dense` step, and an explicit `padding` override.
- `selected` maps to the token primary background and `bordered` (or a selection) to the token border colour — the fork exposes both slots, so they are real, not approximations.
- Preserve content, padding, and click behavior; an interactive card also gets the pointer cursor. `focusNode`/`autofocus` belong to controls, not to a surface, so the card has no slot for them (§15).
- Do not assume every card is interactive.

### Text field

- Use the native Fluent text input (`fluent.TextBox`).
- Preserve the supplied controller, focus node, callbacks, enabled/read-only/obscure state, `maxLines`, keyboard type and action, prefix/suffix, and the inline `Style`.
- `errorText` has no Fluent slot on a bare `TextBox`: it draws the caption under the field in the token error colour, the same signal the token renderer sends (§15).
- Do not create a second controller or silently own its lifecycle.
- Respect text direction, keyboard type, and accessibility labels.

### Switch

- Use the native Fluent toggle switch.
- Preserve controlled value and change callback.
- Do not introduce local persistent state.

### Checkbox

- Use the native Fluent checkbox, with the trailing label through the shared seam.
- Preserve checked/unchecked; the core contract has no indeterminate state, so none is advertised.
- Preserve disabled state and callback semantics: Fluent's callback is `bool?`, so the bridge closure exists only when the caller can be called back, and `focusNode`/`autofocus` pass to the fork.

### Slider

- Use the native Fluent slider.
- Preserve minimum, maximum, current value, and callbacks; a null callback or `enabled: false` disables.
- The spec has no `divisions` field, so stepped behaviour is not invented here.
- Handle invalid ranges according to the core validation contract.

### Control mapping rule

Builders must map semantic intent, not inspect business page types.

For example, a button builder can receive `variant: primary`; it must not special-case login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup.

Conceptually:

```dart
void registerUiAdapters(
  LiveUiRegistry registry,
) {
  registry.register(
    createFluentAdapter(),
  );
}
```

The function and constructor names above are illustrative. Adapt them to the actual `LiveUiRegistry` and adapter constructor defined by the core.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active style.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_fluent` must not register itself through global static initialization or require the business layer to import it.

### Registration failure

The registry should detect:

- Duplicate adapter IDs.
- Invalid capability declarations.
- Missing required builders.
- Unsupported control requests.
- Missing selected adapters.

When Fluent is unavailable, the core fallback policy should choose an available implementation or report a clear error. Do not silently switch styles without following that policy.

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

Acrylic or transparency effects must degrade gracefully where unavailable or inappropriate. Do not make native window APIs a required dependency of the basic adapter.

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

`fluent_ui` resolves its own `FluentLocalizations` type, which a host `MaterialApp`
never supplies — the core localizer covers Flutter's global delegates only. Left out,
a Fluent control throws "No FluentLocalizations found" the first time it builds, which
is exactly what the §16 suites hit before this was wired. The package therefore exports
the delegate and the composition root appends it:

```dart
const List<LocalizationsDelegate<dynamic>> fluentLocalizationsDelegates = [
  fluent.FluentLocalizations.delegate,
];

MaterialApp(
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...fluentLocalizationsDelegates,
  ],
  supportedLocales: /* the app's locale policy */,
)
```

Rules:

- Order matters: the core delegates come first so app-level strings keep priority and
  Fluent supplies only its own internal strings; a test that swaps the order and still
  resolves a core string is the check that holds this.
- `live_uikit_fluent` must not install a delegate itself, wrap the app in a localization
  widget, or override the global locale — that is the composition root's job.
- `supportedLocales` must include a locale every active delegate covers; English is the
  safe common denominator.
- The adapter adds no `flutter_localizations` dependency of its own; the app supplies the
  localizer and this package contributes only the delegate list.

## 15. Error handling and diagnostics

The adapter should report structured diagnostics for meaningful failures, such as:

- An unsupported control or variant.
- An invalid specification.
- A theme property that cannot be mapped directly.
- A missing icon mapping.
- A failed fallback.
- An adapter initialization or registration error.

Use the diagnostics contracts from `live_uikit`. Do not introduce a direct dependency on Talker or another application logging implementation.

Expected behavior:

- Unsupported visual variants may use a documented fallback.
- Invalid control data should follow core validation rules.
- Programming errors should not be swallowed.
- Diagnostics should avoid logging user-entered text, credentials, or other sensitive content.

## 16. Testing strategy

Three directories, one per concern: `test/adapter/` (contract), `test/theme/` (§8.1 mapping and the §8.3 re-skin), `test/widgets/` (§9 controls driven through a real `LiveConfigProvider` + `LiveUiResolver`, so the assertions are about the dispatch path and not a builder in isolation).

### Unit tests

- Stable adapter id `fluent`, display name, language, and `fluentCapabilities` truthfulness.
- Brightness, accent and global-font mapping: `token.color.primary` becomes the `AccentColor.swatch` the fork reads, with its shade getters falling back to `normal` rather than invented tones (§8.1).
- Theme invalidation: a token change re-skins through `wrap` without a restart.
- Fallback behavior for every control this adapter does not override.

### Widget tests

- Button callback, disabled and loading gating, filled-vs-plain variant mapping, and `expand`/`tooltip`/`focusNode`/`autofocus` preserved.
- Card tap, long-press, pointer cursor, padding, `dense`, explicit padding, and the selected/bordered mapping.
- Text field controller and focus-node preservation, prefix/suffix, the error caption, and an inline `Style` override.
- Switch value updates; checkbox null-callback disabling; slider range and disable-by-null.
- Progress indeterminate, fraction→percent scaling, `strokeWidth` and the `barColor` tint.
- Select typed items, and the shared fallback still rendering an unoverridden control.
- Host shell: Fluent controls resolve their own `FluentLocalizations` and need an overlay, which the host app supplies through the appended delegates (§14).

### Integration tests (`test/integration/fluent_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: eight `adapterNative` — including `select`, which Fluent is the only adapter here to render natively — and `segmented`/`tabBar` `shared` with `controlUnsupported`.
- Fluent → the `token` base → Fluent swaps `fluent.TextBox`/`ToggleSwitch`/`ComboBox<String>` for the SDK and token equivalents and back, with the caller's controller text intact.
- `adapterMissing` fires for the core base only; while Fluent is active the only reports are `controlUnsupported` for `segmented` and `tabBar` — eight native controls declare no gap (§15.5).
- Segmented stays callable on both sides of the switch, and the typed select path survives the swap (§16.7).

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
- The core package does not depend on `fluent_ui`.
- Business packages do not import `package:fluent_ui/fluent_ui.dart`.
- All public exports are intentional.
- The adapter's declared capabilities match tested implementations.
- Every `package:fluent_ui/` import inside this package uses the `as fluent` prefix, in `lib/` and `test/`. The prefix is a package-wide rule (§3.3):
  it keeps this library's types distinguishable from Flutter's own and from a sibling
  adapter's, and it is what lets the architecture guard assert the convention.
- The README's list of native controls is checked against `fluentCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
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

Eight native builders, each declared in `fluentCapabilities` and exercised through
the real adapter path in `test/widgets/`:

1. Button (`fluent.FilledButton` / `fluent.Button`)
2. Card (`fluent.Card`)
3. Text field (`fluent.TextBox`)
4. Switch (`fluent.ToggleSwitch`)
5. Checkbox (`fluent.Checkbox`)
6. Slider (`fluent.Slider`)
7. Progress (`fluent.ProgressBar`)
8. Select (`fluent.ComboBox<T>`)

`segmented` and `tabBar` remain shared-renderer controls; promoting one means a
builder, an override and a capability entry in the same change (§17 drift gate).
There is no "text" or "icon" control in the contract to map — an earlier draft of this
section listed both, and `LiveUiControl` has no such member.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: focus nodes reach the fork buttons, checkbox and text field where `fluent_ui` accepts them, and a disabled control is wired dead rather than decorative.
- Open, needs hardware: keyboard navigation and focus rings on a real Windows target, Android TV D-pad.
- Verify keyboard navigation and focus behavior.
- Test Android TV D-pad behavior.
- Validate semantics and accessibility.
- Add documented fallbacks for unsupported variants.

### Phase 5 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Open: integration tests for style switching — a cross-adapter switch is an application-level concern, since §3.3 forbids adapter-to-adapter dependencies.
- Verify all claimed platforms.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `fluent_ui` only for its core integration.
- [x] It implements the actual core adapter contract.
- [x] It uses the stable adapter ID `fluent`.
- [x] It reports accurate control capabilities.
- [x] It maps the resolved core theme into Fluent theme values.
- [x] It uses native Fluent controls where supported.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell unnecessarily.
- [x] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the button's `focusNode`/`autofocus` and the field's node preservation are asserted (§16); the visible focus ring, D-pad traversal and Narrator behaviour need Windows hardware.
- [x] Unsupported features follow the core fallback policy.
- [x] Diagnostics use the shared core contract.
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_fluent` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection, and fallback policy.
- `live_uikit_fluent` maps those contracts to Fluent UI.
- `fluent_ui` supplies the underlying Fluent widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls.
