# `live_uikit_forui` Architecture and Integration Specification

- **Package:** `live_uikit_forui`
- **Parent package:** `live_uikit`
- **Implementation library:** `forui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_forui` is the ForUI adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `forui` controls
(`FButton`, `FCard`, `FTextField`, `FSwitch`, `FCheckbox`) and forui-specific visual
behavior. It must not implement business pages or duplicate the core theme system.

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
2. **ForUI owns ForUI visuals.** Use native forui controls wherever practical rather
   than drawing shadcn-style controls from scratch.
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
7. **Graceful fallback.** Unsupported controls must follow the fallback policy defined
   by `live_uikit`, not silently change behavior.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- ForUI theme mapping (the palette variant the resolved token can decide, §8.1).
- ForUI widget construction.
- ForUI-specific control defaults (variant kinds, sizes, the fork's own tooltip, label
  and error slots).
- Reporting implemented capabilities to the core registry.
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

The tree below is the package as it exists today: five native builders, three theme
files, and one test directory per §16 concern.

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
    │       │   └── forui_registration.dart
    │       ├── theme/
    │       │   ├── forui_theme_builder.dart
    │       │   ├── forui_theme_mapper.dart
    │       │   └── forui_theme_scope.dart
    │       └── widgets/
    │           ├── forui_button_builder.dart
    │           ├── forui_card_builder.dart
    │           ├── forui_checkbox_builder.dart
    │           ├── forui_switch_builder.dart
    │           └── forui_text_field_builder.dart
    ├── live-uikit-forui.md
    └── test/
        ├── adapter/
        │   └── forui_contract_test.dart
        ├── integration/
        │   └── forui_style_switching_test.dart
        ├── theme/
        │   └── forui_theme_test.dart
        └── widgets/
            └── forui_native_controls_test.dart
```

Do not create empty files just to match this tree. Add modules as their functionality
is implemented.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration |
| `theme/` | Translate the resolved PureLive token into forui's `FThemeData` and install it |
| `widgets/` | Build forui controls from core widget specifications |
| `interaction/` *(optional, not created)* | Keyboard, focus and TV-specific mapping, if forui's own focus treatment proves insufficient on a target |
| `icons/` *(optional, not created)* | Semantic icon remapping to forui's icon set |
| `diagnostics/` *(optional, not created)* | Adapter-local mapping diagnostics; the core contracts already cover control fallbacks |
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

`ForuiLanguageAdapter extends SharedLanguageAdapter`, which already implements the core
`abstract interface class LanguageAdapter` — every control has a working token-driven
default, so the adapter overrides only what `forui` renders natively plus `wrap`. The
contract is exactly:

- Getters: `language`, `id`, `displayName`, `capabilities`.
- Methods: `wrap`, `button`, `card`, `textField`, `switchWidget`, `checkbox`,
  `slider`, `segmented`, `progress`, `select<T>`, `tabBar`.

The realized mapping:

| Contract member | Implementation here |
|---|---|
| `language` | `LiveDesignLanguage.forui` |
| `id` | `'forui'` (matches `foruiAdapterId`) |
| `displayName` | `'ForUI'` |
| `capabilities` | `foruiCapabilities` |
| `wrap` | `ForuiThemeMapper.wrap` — installs the mapped `FTheme` scope |
| `button` | `ForuiButtonBuilder.build` — native `FButton` / `FButton.icon` by `iconOnly` |
| `card` | `ForuiCardBuilder.build` — native `FCard` |
| `textField` | `ForuiTextFieldBuilder.build` — native `FTextField` |
| `switchWidget` | `ForuiSwitchBuilder.build` — native `FSwitch` |
| `checkbox` | `ForuiCheckboxBuilder.build` — native `FCheckbox` |
| `slider`, `segmented`, `progress`, `select<T>`, `tabBar` | Inherited from `SharedLanguageAdapter` — shared token renderer |

### Adapter identifier

Use one stable identifier everywhere:

```text
forui
```

The identifier is a machine-readable value, not a localized label. Do not use `for_ui`,
`ForUI`, or a package-name-derived identifier as the runtime style id; `foruiAdapterId`,
`ForuiLanguageAdapter.id` and `LiveDesignLanguage.forui.name` all resolve to `forui`.

### Capability declaration

`foruiCapabilities` is a *declaration of fact*: it lists precisely the five controls
`ForuiLanguageAdapter` overrides. `LiveUiControl` has exactly ten members — `button,
card, textField, switchWidget, checkbox, slider, segmented, progress, select, tabBar` —
so there is no `text`, `icon`, `dialog` or `menu` entry to declare; those are not part
of the contract.

`slider`, `segmented`, `progress`, `select` and `tabBar` stay on the shared renderer and
the resolver reports `controlUnsupported` for them (§15). Unlike wind's slider or
material's select, this is **not** a library gap — `forui` 0.27.5 ships `FSlider`,
`FProgress`/`FDeterminateProgress`, `FSelect<T>` and `FTabs` — so these five are
genuine promotion candidates (§18), each gated only on a builder being written and the
capability sets moving in the same change.

The two implementation kinds come from the core — `LiveImplementationKind.adapterNative`,
`.shared` — and the contract test asserts that the declared set matches the overrides,
so a declaration that lies about support fails the build (§16/§17).

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
| Density | Per-control `FButtonSizeVariant` | Control-level only; no token-driven global density is wired |
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
resolved brightness. The adapter never nests a `FApp`/`FScaffold` application shell:
the host's `MaterialApp` stays the app.

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
- Press eligibility comes from the shared seam: a null callback, a disabled spec or a
  loading state reach the fork as `onPress: null`, forui's own disabled state — no
  swallowing closure is ever invented to keep the widget looking live.
- `selected` **is mapped** onto `FButton.selected`, forui's own toggled affordance —
  the only adapter in the family that can say that. The core tints a toggled button
  through the token base; here the library's real state carries it instead (ADR 0004's
  remainder closes in this language). It is exercised through `LiveIconButton`, the
  control whose spec carries `selected`.
- `focusNode` and `autofocus` pass to the fork; `expand` becomes `mainAxisSize`.
- The accessible name of a textless button lives on the seam's glyph
  (`Icon.semanticLabel` from `buttonLabel`), not on a second `FButton.semanticsLabel`
  — naming both would announce twice.
- `tooltip` wraps the control in forui's own `FTooltip`.
- `style` is **not mapped by this adapter**. Its button is the library's own widget and
  paints its own surface; applying a caller's `Style` to it would mean hand-painting an
  overlay over that widget. The shared token renderer does honour the field, so a
  language with no native button keeps the override (`live-uikit.md` §11).

### Card

- `FCard` paints the surface and none of the inside space, so the token padding (or the
  caller's explicit one) wraps the content — exactly as the token renderer does it;
  `dense` is the same ×0.66 step everywhere.
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

### Control mapping rule

Builders must map semantic intent, not inspect business page types.

For example, a button builder can receive `variant: primary`; it must not special-case
login pages, playback pages, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter during startup:

```dart
registry: const LanguageRegistry(
  adapters: {LiveDesignLanguage.forui: foruiAdapter},
  fallback: SharedLanguageAdapter(),
),
```

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active style.
- Providing configuration persistence.
- Coordinating runtime theme changes.

`live_uikit_forui` must not register itself through global static initialization or
require the business layer to import it.

### Registration failure

The registry detects duplicate adapter ids, invalid capability declarations, and
unsupported control requests. When ForUI is unavailable, the core fallback policy
chooses an available implementation or reports a clear error. Do not silently switch
styles without following that policy.

## 11. Runtime style switching

A business widget uses the core API (`LiveButton`, `LiveCard`, …) and never branches on
the active style. Switching adapters changes rendering and interaction presentation; it
must not replace business controllers, reset form values, or recreate unrelated
application services. The integration test swaps ForUI ↔ the `token` base and asserts
the caller's controller text survives both directions (§16).

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
accepts them, and the widget tests assert caller ownership. What remains open needs
hardware: focus traversal on a real Windows target, the fork's focus ring visibility,
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
not exist here to degrade.

## 14. Localization and accessibility

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing English strings.
- Preserve semantic labels and hints.
- Avoid introducing a second, conflicting locale source.
- Test long translated labels and right-to-left layouts.

### The forui delegate is required, not optional

forui resolves its own `FLocalizations` type and labels several controls through
`LocalizedText` (supporting Material's 115 languages), which a host `MaterialApp` never
supplies — the core localizer covers Flutter's global delegates only. Left out, a forui
control throws the library's localization assertion the first time it builds. The
package therefore exports the delegate and the composition root appends it:

```dart
const List<LocalizationsDelegate<dynamic>> foruiLocalizationsDelegates = [
  forui.FLocalizations.delegate,
];

MaterialApp(
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...foruiLocalizationsDelegates,
  ],
  supportedLocales: /* the app's locale policy */,
)
```

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

The adapter reports structured diagnostics through the core contracts; it introduces no
direct dependency on Talker or another application logging implementation.

Expected behavior:

- The five controls this adapter does not override resolve `shared` and the resolver
  reports `controlUnsupported` for each, exactly once per language change (§16).
- `adapterMissing` fires only for a language with no adapter at all — never while
  ForUI is active, which declares no gap beyond the five above.
- Invalid control data follows core validation rules (clamped slider values, disabled
  semantics from a null callback).
- Programming errors are not swallowed; diagnostics never log user-entered text,
  credentials, or other sensitive content.

## 16. Testing strategy

Three directories plus the switching pass, one per concern: `test/adapter/` (contract),
`test/theme/` (§8.1 mapping and the §8.3 re-skin), `test/widgets/` (§9 controls driven
through a real `LiveConfigProvider` + `LiveUiResolver`, so the assertions are about the
dispatch path and not a builder in isolation), `test/integration/` (§11).

### Contract tests (`test/adapter/forui_contract_test.dart`)

- Stable adapter id `forui`, display name, language, and `foruiCapabilities`
  truthfulness (the declared set *is* the native set).
- Dispatch through the core resolver: a declared control resolves `adapterNative` with
  no diagnostic; an undeclared one resolves `shared` with `controlUnsupported`.
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
- A control this adapter does not override still renders through the shared renderer.

### Integration tests (`test/integration/forui_style_switching_test.dart`)

- Every `LiveUiControl` resolves as declared: five `adapterNative`, five `shared` with
  `controlUnsupported`, each reported exactly once per language change.
- ForUI ↔ the `token` base swaps `FButton`/`FCard`/`FTextField`/`FSwitch` for the SDK
  and token equivalents and back, with the caller's controller text intact; progress
  stays a shared-fallback control and keeps rendering on both sides; `adapterMissing`
  fires for the core base only.
- A shared-fallback control stays on-theme inside the forui scope.

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not**
tested from this package: §3.3 forbids depending on another style adapter, so that case
belongs to the application integration suite.

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
- The adapter's declared capabilities match the overrides.
- Every `package:forui/` import inside this package uses the `as forui` prefix, in
  `lib/` and `test/`.
- The README's list of native controls is checked against `foruiCapabilities`.
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

### Phase 3 — Core controls ✅ (native five)

1. Button (`FButton` / `FButton.icon`, with the family's only native `selected`)
2. Card (`FCard`)
3. Text field (`FTextField`, with the family's only native error slot)
4. Switch (`FSwitch`)
5. Checkbox (`FCheckbox`)

### Phase 4 — Remaining controls ◐

The five shared controls are **not** library-gated — `forui` 0.27.5 ships real
candidates — so promotion is a pure adapter decision, one lockstep change each
(builder + override + capability entry + contract-test sets + README + this tree):

- `slider` → `FSlider`: genuine candidate; the fork is form-field oriented
  (`FFormFieldProperties<FSliderValue>`) and the spec carries min/max/value/onChanged
  only, so map the continuous value and record whatever form semantics stay unmapped.
- `progress` → `FProgress` (indeterminate) / `FDeterminateProgress`: genuine candidate;
  evaluate `strokeWidth`/`barColor`/`showLabel` against the fork's slots before
  declaring them unmappable.
- `select<T>` → `FSelect<T>`: genuine candidate; typed single-select matches
  `LanguageSelectSpec<T>`.
- `tabBar` → `FTabs`: **evaluate first** — `FTabs` couples each `FTabEntry` to a content
  panel, which `LanguageTabsSpec` (labels + index + callback) does not carry, the same
  shape that keeps material's and wind's tab strips shared. Promote only if the fork
  can serve a bar-only use without the adapter owning page content.
- `segmented` → no forui control exists; stays shared like material's, and the reason
  lives here rather than in a silent gap.

### Phase 5 — Interaction and accessibility ◐

- Headless half done: focus nodes reach the fork buttons, switch, checkbox and text
  field; a disabled control is wired dead rather than decorative.
- Open, needs hardware: keyboard navigation and the fork's focus ring on a real Windows
  target, Android TV D-pad.
- Add an `interaction/` module only if that testing finds a forui-specific gap.

### Phase 6 — Production readiness ◐

- Architectural CI checks (§17) are enforced by `tool/check_architecture.ps1`.
- Style switching against the core base is covered in `test/integration/`; a
  cross-adapter switch belongs to the application suite (§3.3).
- Verify all claimed platforms (§13); document known limitations and `forui` upgrade
  compatibility: today the theme recolor ceiling (§8.1), the inline `style` remainder
  on the button (§9) and the field spec's missing `autofocus` (§9).

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `forui` only for its core integration.
- [x] It extends `SharedLanguageAdapter` and implements the actual core adapter contract.
- [x] It uses the stable adapter ID `forui`.
- [x] It reports accurate control capabilities (five native, five shared, asserted).
- [x] It maps the resolved core theme into forui's theme as far as the library allows,
  and pins the ceiling instead of faking a recolor (§8.1).
- [x] It uses native forui controls where supported.
- [x] It does not duplicate the core theme configuration.
- [x] It does not own business state or persistence.
- [x] It does not create a nested application shell.
- [x] Runtime switching preserves business state (controller text across the swap, §16).
- [x] Unsupported features follow the core fallback policy, reported once per language
  change.
- [x] Diagnostics use the shared core contract.
- [x] `button.selected` is carried by the fork's own affordance, not a hand-painted
  overlay (ADR 0004's remainder closes in this language).
- [ ] Keyboard, accessibility, and TV focus behavior are tested — the headless half is
  (§16); the fork's focus ring, D-pad traversal and screen-reader behaviour need
  hardware (§12).
- [x] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests (§13/§16).

## 20. Final architecture decision

`live_uikit_forui` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection,
  and fallback policy.
- `live_uikit_forui` maps those contracts to ForUI.
- `forui` supplies the underlying shadcn-style widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user
  preferences.
- Business packages depend only on the unified `live_uikit` API.
