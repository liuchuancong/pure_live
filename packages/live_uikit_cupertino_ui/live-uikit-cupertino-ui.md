# `live_uikit_cupertino_ui` Architecture and Integration Specification

- **Package:** `live_uikit_cupertino_ui`
- **Parent package:** `live_uikit`
- **Implementation library:** `cupertino_ui`
- **Status:** Architecture specification
- **Target:** PureLive 4.x
- **Platforms:** Android, iOS, Android TV, Windows, macOS, Linux

## 1. Purpose

`live_uikit_cupertino_ui` is the Cupertino UI adapter for PureLive's unified UI system.

It translates the contracts defined by `live_uikit` into native `cupertino_ui` controls and Cupertino-specific visual behavior. `cupertino_ui` is a fork of Flutter's Cupertino widgets; it is selected through the dedicated `LiveDesignLanguage.cupertinoUi` value and is deliberately distinct from the core's built-in `cupertino` token base. This adapter must not implement business pages or duplicate the core theme system.

The package follows this dependency direction:

```text
PureLive application
       |
       v
live_uikit
       ^
       |
live_uikit_cupertino_ui
       |
       v
cupertino_ui
```

The application composition root registers this adapter. Business packages depend only on `live_uikit` and must not import `cupertino_ui` directly.

## 2. Design principles

1. **Core owns the contracts.** Public widget APIs, neutral design tokens, configuration models, and adapter registration contracts belong to `live_uikit`. The `LanguageAdapter` interface, the spec types, `LiveUiCapabilities`, and the resolver are all defined there and consumed here as finalized code.
2. **Cupertino owns Cupertino visuals.** Use native `cupertino_ui` controls wherever practical rather than re-drawing Cupertino-style controls from scratch, and let the fork re-skin its own subtree via `cu.CupertinoTheme`.
3. **No business logic.** The adapter must not manage accounts, playback sessions, routing, plugin execution, or application settings persistence.
4. **No hidden state ownership.** Form values, loading state, validation, and business state remain controlled by the calling widget or application; the text field passes the caller's `controller` and `focusNode` straight through and never creates a competing one.
5. **Runtime switching is supported.** Switching from Cupertino UI to another style must not require business pages to import or construct different control classes.
6. **Touch-first, mobile-oriented.** Cupertino's aesthetic is a touch/mobile interaction language; hit targets and control affordances are sized for fingers, and D-pad/TV focus is a secondary consideration verified explicitly rather than assumed.
7. **Declared fallback, not silent degrade.** Only four controls are native here; the other six render through the shared token renderer and are reported by the resolver as a `controlUnsupported` diagnostic. That downgrade is expected and observable, never hidden.

## 3. Responsibilities and boundaries

### 3.1 What this package owns

- Cupertino UI theme mapping (resolved `DesignToken` → `cu.CupertinoThemeData`).
- Cupertino UI widget construction for the four native controls.
- Cupertino-specific control defaults (filled vs ghost button, decoration, clamping).
- Reporting implemented capabilities to the core registry through `cupertinoUiCapabilities`.
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
| `live_uikit_material_ui` | No | Adapters must remain independent |
| `live_uikit_glass` | No | Adapters must remain independent |
| `live_uikit_neumorphic` | No | Adapters must remain independent |
| `live_uikit_wind` | No | Adapters must remain independent |
| Business feature packages | No | Prevents dependency inversion |

Note: `cupertino_ui` is a different package from the core's Cupertino token base. This adapter is the fork-backed `cupertinoUi` language; it must not be conflated with, nor depend on, the core `cupertino` renderer.

## 4. Package directory

Current implemented structure:

```text
packages/
└── live_uikit_cupertino_ui/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_uikit_cupertino_ui.dart
    │   └── src/
    │       ├── adapter/
    │       │   ├── cupertino_ui_adapter.dart
    │       │   ├── cupertino_ui_capabilities.dart
    │       │   └── cupertino_ui_registration.dart
    │       ├── theme/
    │       │   ├── cupertino_ui_theme_builder.dart
    │       │   ├── cupertino_ui_theme_mapper.dart
    │       │   └── cupertino_ui_theme_scope.dart
    │       └── widgets/
    │           ├── cupertino_ui_button_builder.dart
    │           ├── cupertino_ui_text_field_builder.dart
    │           ├── cupertino_ui_switch_builder.dart
    │           └── cupertino_ui_slider_builder.dart
    ├── live-uikit-cupertino-ui.md
    └── test/
        ├── adapter/
        │   └── cupertino_ui_contract_test.dart
        ├── theme/
        │   └── cupertino_ui_theme_test.dart
        ├── widgets/
        │   └── cupertino_ui_native_controls_test.dart
        └── integration/
            └── cupertino_ui_style_switching_test.dart
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
| `adapter/` | `CupertinoUiLanguageAdapter` contract implementation, `cupertinoUiCapabilities` declaration, registration exports |
| `theme/` | Translate the resolved `DesignToken` into `cu.CupertinoThemeData` and install it via the theme scope |
| `widgets/` | Build native `cupertino_ui` controls from the core `Language*Spec` types |
| `test/` | Verify contract compliance, capability set, and resolver behavior |

## 5. Package dependencies

Current `pubspec.yaml`:

```yaml
name: live_uikit_cupertino_ui
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

The adapter must not add `freezed`, `json_serializable`, or `build_runner` unless its own implementation genuinely needs code generation. The `cupertino_ui` version is a caret range; verify the resolved version before relying on fork-specific control constructors.

## 6. Public API

The public barrel exports only the registration API. Current entry point:

```dart
// lib/live_uikit_cupertino_ui.dart
library;

export 'package:live_uikit_cupertino_ui/src/adapter/cupertino_ui_registration.dart';
```

`cupertino_ui_registration.dart` provides the complete public surface:

| Export | Kind | Purpose |
|---|---|---|
| `createCupertinoUiAdapter()` | function | Returns a fresh `CupertinoUiLanguageAdapter` for the composition root |
| `cupertinoUiAdapter` | `const LanguageAdapter` | The const adapter instance to register |
| `cupertinoUiAdapterId` | `const String` | The stable runtime id, `'cupertinoUi'` |
| `cupertinoUiLocalizationsDelegates` | `const List<LocalizationsDelegate<dynamic>>` | `cupertino_ui`'s own `GlobalCupertinoLocalizations.delegate` |

Do not export the internal builders (`CupertinoUiButtonBuilder`, etc.), the theme mapper/scope/builder classes, or `cupertino_ui` types (`cu.CupertinoTheme`, `cu.CupertinoButton`, and friends). Business code reaches this adapter only through the core API and the registry.

## 7. Adapter contract

`CupertinoUiLanguageAdapter` extends `SharedLanguageAdapter` and overrides only the four native controls plus `wrap`. The core contract it satisfies is `LanguageAdapter`, an abstract interface with:

- Getters: `language`, `id`, `displayName`, `capabilities`.
- Methods: `wrap`, `button`, `card`, `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`, `select<T>`, `tabBar`.

`SharedLanguageAdapter` is the token-driven base that implements every method; unoverridden controls therefore keep rendering on-theme through the shared renderer. This adapter's realized mapping:

| Contract member | Implementation here |
|---|---|
| `language` | `LiveDesignLanguage.cupertinoUi` |
| `id` | `'cupertinoUi'` (matches `cupertinoUiAdapterId`) |
| `displayName` | `'Cupertino UI'` |
| `capabilities` | `cupertinoUiCapabilities` |
| `wrap` | Delegates to `CupertinoUiThemeMapper.wrap` (installs `cu.CupertinoTheme`) |
| `button` | `CupertinoUiButtonBuilder.build` — native |
| `textField` | `CupertinoUiTextFieldBuilder.build` — native |
| `switchWidget` | `CupertinoUiSwitchBuilder.build` — native |
| `slider` | `CupertinoUiSliderBuilder.build` — native |
| `card`, `checkbox`, `segmented`, `progress`, `select`, `tabBar` | Inherited from `SharedLanguageAdapter` — shared token renderer |

### Adapter identifier

Use one stable machine-readable identifier everywhere:

```text
cupertinoUi
```

`id` returns `'cupertinoUi'`, `language` is `LiveDesignLanguage.cupertinoUi`, and `cupertinoUiAdapterId` exposes the same string. Do not use `cupertino_ui`, `Cupertino UI`, or `cupertino` (the core token base) as the runtime style id. `displayName` (`'Cupertino UI'`) is the human label for the selector and is never persisted or compared.

### Capability declaration

`cupertinoUiCapabilities` declares exactly the four native controls; it must stay in sync with the methods the adapter actually overrides.

| Control (`LiveUiControl`) | Implementation | Reported via resolver |
|---|---|---|
| `button` | Native `cupertino_ui` button | `adapterNative`, no diagnostic |
| `textField` | Native `cupertino_ui` text field | `adapterNative`, no diagnostic |
| `switchWidget` | Native `cupertino_ui` switch | `adapterNative`, no diagnostic |
| `slider` | Native `cupertino_ui` slider | `adapterNative`, no diagnostic |
| `card` | Shared token renderer | `shared`, `controlUnsupported` |
| `checkbox` | Shared token renderer | `shared`, `controlUnsupported` |
| `segmented` | Shared token renderer | `shared`, `controlUnsupported` |
| `progress` | Shared token renderer | `shared`, `controlUnsupported` |
| `select` | Shared token renderer | `shared`, `controlUnsupported` |
| `tabBar` | Shared token renderer | `shared`, `controlUnsupported` |

The capability model uses the core enums as fact: `LiveUiCapabilities` wraps a `Set<LiveUiControl>` and exposes `supports(control)`; `LiveImplementationKind` values are `adapterNative`, `shared`, and `custom`. Do not add a parallel capability system.

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
CupertinoUiThemeMapper.wrap(context, token, child)
     |
     v
CupertinoUiThemeScope  (StatelessWidget)
     |
     v
CupertinoUiThemeBuilder.build(token)  ->  cu.CupertinoThemeData
     |
     v
cu.CupertinoTheme(data: ..., child: child)
     |
     v
native cupertino_ui controls
```

The adapter's `wrap` calls `_theme.wrap(...)`, where `_theme` is a `const CupertinoUiThemeMapper()`. `CupertinoUiThemeMapper` returns `CupertinoUiThemeScope(token: token, child: child)`; the scope builds `cu.CupertinoTheme(data: CupertinoUiThemeBuilder.build(token), child: child)`. No `cupertino_ui` application shell is introduced just to apply the theme.

### 8.1 Theme properties to map

| Core token property | Cupertino UI mapping | Notes |
|---|---|---|
| Brightness (`token.isDark`) | `cu.CupertinoThemeData.brightness` | `Brightness.dark` when `token.isDark`, else `Brightness.light` |
| Accent / primary (`token.color.primary`) | `cu.CupertinoThemeData.primaryColor` | Brand accent drives tinted controls |
| Text colors (`theme.colors.text`) | Applied per-control in builders | See §9; not part of the theme data draft |
| Container / border / radius | Consumed by the text-field builder from `LiveTheme` | Decoration drawn per control, not forked into theme data |
| Page surface (`token.color.surface`) | `cu.CupertinoThemeData.scaffoldBackgroundColor` | Mapped |
| On-primary (`token.color.onPrimary`) | `cu.CupertinoThemeData.primaryContrastingColor` | Mapped |

The current `CupertinoUiThemeBuilder.build` maps brightness, `primaryColor`, `primaryContrastingColor` and `scaffoldBackgroundColor` — four properties, and the theme test asserts each one moves with the token. Typography and density stay at the fork's defaults: `cupertino_ui` builds its text scale itself, and a token family cannot be folded in without replacing the whole scale, so §8.1 leaves them alone rather than half-mapping them. No second token model is invented; role styles come from `LiveTheme` at builder level.

### 8.2 Theme scope

Prefer the fork's `cu.CupertinoTheme` scope, which is what `CupertinoUiThemeScope` uses. Do not nest a `cupertino_ui` application widget inside an existing app solely to apply the style; a nested app shell introduces competing navigation, localization, and application-level configuration. The scope wraps only the adapter's own subtree.

### 8.3 Runtime updates

When the user changes brightness, accent color, or style:

1. The application updates `LiveConfig`.
2. The core resolves a new `DesignToken`.
3. `wrap` is called again with the new token, rebuilding `CupertinoUiThemeScope`.
4. `CupertinoUiThemeBuilder.build` derives fresh `cu.CupertinoThemeData`.
5. Existing business state remains owned by the business widgets and controllers.

Do not cache a `cu.CupertinoThemeData` object permanently if its source token can change. The mapper is stateless (`const`); the theme data is rebuilt whenever the resolved token changes.

## 9. Control implementation rules

Each native builder converts a core specification into a `cupertino_ui` widget. The four shared-fallback controls (see §7) are handled by the inherited `SharedLanguageAdapter` methods, not by builders in this package.

### Button (`CupertinoUiButtonBuilder.build(context, spec, seam)`)

- `ButtonVariant.ghost` maps to a plain `cu.CupertinoButton`; every other variant maps to `cu.CupertinoButton.filled`.
- Press eligibility comes from the shared seam: `seam.interactive(spec)` (enabled, not loading, has a callback) decides whether `onPressed` is passed or nulled.
- Label/loading/icon composition is reused from the seam via `seam.buttonLabel(spec, theme, foreground: ...)`, with ghost buttons tinted `theme.colors.primary`.
- `focusNode` and `autofocus` are passed through from the spec — the fork's buttons take both.
- `expand` wraps the button in `SizedBox(width: double.infinity)` and `tooltip` wraps it in the core's language-neutral `LiveTooltip`, the same two post-wraps the token renderer applies. `cupertino_ui` has no hint slot, and an SDK Material `Tooltip` does not belong in a Cupertino subtree (§14/§15).
- No business action lives inside the builder; it maps intent, never page type.
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

### Text field (`CupertinoUiTextFieldBuilder.build(context, spec)`)

- Native `cu.CupertinoTextField`, passing the caller's `controller`, `focusNode`, `placeholder`, `enabled`, `readOnly`, `obscureText`, `maxLines`, `keyboardType`, `textInputAction`, `prefix`, `suffix`, `onChanged`, and `onSubmitted` straight through.
- Obscure fields are forced to one line (`maxLines: 1` when `obscure`).
- The field never creates its own competing controller; when `spec.controller` is null the field's own default is used, matching the core ownership rule.
- Text style and decoration come from `LiveTheme.of(context)` (body text, `bgContainer` fill, `input.borderRadius`, border switching to `theme.colors.error` when `errorText != null`), and the spec's inline `Style` layers onto the body text so a caller override wins property by property.
- The fork has no error slot, so `errorText` also draws the caption line under the field, in the same caption style the token renderer uses — an error means the same thing in both paths (§15).

### Switch (`CupertinoUiSwitchBuilder.build(context, spec)`)

- Native `cu.CupertinoSwitch`, fully controlled by `spec.value`.
- `onChanged` is passed only when `spec.enabled`; otherwise null, which is Cupertino's disable mechanism.
- No local or persistent state is introduced.

### Slider (`CupertinoUiSliderBuilder.build(context, spec)`)

- Native `cu.CupertinoSlider` with `spec.min`/`spec.max` and the value clamped to range (`spec.value.clamp(spec.min, spec.max)`).
- Disabled by dropping `onChanged` (null) when `!spec.enabled` **or** when the spec's callback is null. The earlier version supplied a no-op listener so the thumb stayed draggable; that is the §15 defect this rule forbids — a control that looks live and never reports.
- Invalid ranges follow the core validation contract rather than being silently corrected here.

### Card / checkbox / segmented / progress / select / tabBar

- Not overridden. `CupertinoUiLanguageAdapter` inherits `SharedLanguageAdapter`'s implementations, so these render through the token-driven fallback and are reported by the resolver as `controlUnsupported` (§15). This is the documented, expected outcome for a four-control adapter, not a silent degrade.

### Control mapping rule

Builders map semantic intent from the `Language*Spec` types; they must not inspect business page types. A button builder may branch on `spec.variant`; it must not special-case login, playback, or plugin settings screens.

## 10. Runtime registration

The application composition root registers the adapter by supplying it to the core `LanguageRegistry`, keyed by `LiveDesignLanguage`, and resolving through `LiveUiResolver`. Either exported form works — `cupertinoUiAdapter` is a `const` instance, `createCupertinoUiAdapter()` returns a fresh one:

```dart
// Register Cupertino UI under its language key, with the shared base as fallback.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter},
  fallback: SharedLanguageAdapter(),
);
const resolver = LiveUiResolver(registry: registry);
```

This is the exact construction the shipped contract test uses; `createCupertinoUiAdapter()` is the factory form when the root prefers a non-const instance.

The composition root is responsible for:

- Registering the adapters included in the application build.
- Loading the user's style preference.
- Selecting the active language (`UiConfig.language`).
- Providing configuration persistence.
- Coordinating runtime theme changes.
- Appending `cupertinoUiLocalizationsDelegates` to the localization delegates (§14).

`live_uikit_cupertino_ui` must not register itself through global static initialization or require the business layer to import it.

### Registration and resolution failure

`LiveUiResolver` over a `LanguageRegistry` detects and reports, via the diagnostic codes in §15:

- A selected language with no registered adapter → `adapterMissing` (whole subtree falls back to `shared`).
- A missing default adapter that even the shared fallback cannot supply → `defaultAdapterMissing` (startup-level fault, never recovered silently).
- A control the adapter does not declare (card, checkbox, segmented, progress, select, tabBar here) → `controlUnsupported` for just that control.

When Cupertino UI is unavailable, the core fallback policy chooses the shared token renderer or reports a clear error; it does not silently switch styles outside that policy.

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
if (language == 'cupertinoUi') {
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
      +---- Cupertino UI adapter (cupertinoUi)
      +---- Fluent adapter
      +---- Material UI adapter
      +---- Other registered adapters
```

Switching from Cupertino UI to another language changes rendering and interaction presentation only. It must not replace business controllers, reset form values, or recreate unrelated application services. Because four of ten controls resolve to the shared renderer, the visual continuity on those controls is preserved across switches.

## 12. Keyboard, focus, and TV support

Cupertino UI is a touch-first language, so finger interaction is the primary path. Keyboard, focus, and Android TV D-pad behavior are secondary but must still be verified rather than assumed.

Current state: the specs carry `focusNode` and `autofocus`, and the button and text-field builders pass them through to the native controls. Beyond that pass-through, there is no dedicated `interaction/` module yet (see §4). As focus/TV support matures:

- Rely on `cupertino_ui`'s own focus traversal for the four native controls; verify visible focus indication actually appears on desktop and TV.
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
const List<LocalizationsDelegate<dynamic>> cupertinoUiLocalizationsDelegates = [
  cu.GlobalCupertinoLocalizations.delegate,
];
```

The application composition root must append `cupertinoUiLocalizationsDelegates` to the core's localization delegate list on the app's root widget (via the delegate composition point `live_uikit` exposes). Do not add the delegate inside the adapter itself, and never independently override the global `Locale`.

The adapter must:

- Respect the locale and text direction provided by the application.
- Avoid hardcoded user-facing strings; all visible text comes from the specs (`label`, `placeholder`, `errorText`, `itemLabel`).
- Preserve semantic labels, hints, and tooltips (`LanguageButtonSpec.tooltip`, accessibility labels).
- Test long translated labels and right-to-left layouts, especially the text-field decoration and button label ellipsis.
- Verify focus visibility, text contrast, and touch-target sizing.

## 15. Error handling and diagnostics

The adapter reports structured diagnostics through the core contracts, delivered to a host-supplied `LiveUiDiagnosticSink` rather than a concrete logging package. The resolver (`LiveUiResolver` + `LanguageRegistry`) is what emits them; this package's job is to declare accurate capabilities so the resolver decides correctly.

Diagnostic codes (`LiveUiDiagnosticCode`):

| Code | When it fires for this adapter |
|---|---|
| `adapterMissing` | Selected language has no registered adapter (would apply before Cupertino UI is registered) — language-wide, `control` null |
| `defaultAdapterMissing` | The registry cannot supply even the shared fallback for the default language — startup-level fault |
| `controlUnsupported` | One of card, checkbox, segmented, progress, select, tabBar is requested; resolves to `shared` for just that control |
| `unsupportedEffect` | The environment cannot afford a focus/blur/backdrop effect; a verified degraded visual stands in |

Each `LiveUiDiagnostic` carries the `language`, optional `control`, and the resolved `LiveImplementationKind` (`kind`), so a host can assert "this control, in Cupertino UI, fell back to `shared` because it was `controlUnsupported`".

Expected behavior:

- The six shared-fallback controls render on-theme and are reported, not silently swapped.
- Invalid control data follows core validation rules; programming errors are not swallowed.
- Diagnostics must not log user-entered text, credentials, or other sensitive content.
- Do not add a direct dependency on Talker or another logging implementation; use `LiveUiDiagnosticSink`.

## 16. Testing strategy

### Contract / unit tests (current: `test/adapter/cupertino_ui_contract_test.dart`)

- Stable id, display name, and language (`cupertinoUi` / `Cupertino UI` / `LiveDesignLanguage.cupertinoUi`).
- The declared capability set is exactly `{button, textField, switchWidget, slider}` native, and `{card, checkbox, segmented, progress, select, tabBar}` are not supported — asserting declaration matches overrides so drift fails the test (§17).
- Resolution through a `LanguageRegistry` + `LiveUiResolver`: registered language resolves to `adapterNative`; a declared control (button) resolves native with no diagnostic; an undeclared control (card) resolves to `shared` with a `controlUnsupported` diagnostic naming that control.

### Widget tests (`test/widgets/cupertino_ui_native_controls_test.dart`)

Driven through a real `LiveConfigProvider` with this adapter registered, so the assertions are about the dispatch path, not the builder in isolation:

- Button callback, disabled/loading state, and ghost vs filled mapping.
- Text-field controller and focus-node preservation (no second controller created), prefix/suffix pass-through, the error caption, and an inline `Style` overriding the token body text.
- Caller-owned focus: the node a page hands the field is the node that takes focus, and the button takes both the caller's node and its `autofocus` flag (§9/§16).
- Switch value updates and disable-by-null.
- Slider clamping to range, and a null callback reaching the fork as null rather than as a no-op listener.
- `expand` and `tooltip` wrappers on the button.
- The shared fallback still rendering for a control this adapter does not override.

### Theme tests (`test/theme/cupertino_ui_theme_test.dart`)

- `CupertinoUiThemeBuilder.build` maps `token.isDark` → brightness and `token.color.primary` → `primaryColor`.
- Theme rebuilds when the resolved token changes (no stale `CupertinoThemeData`), driven through `LiveConfigProvider` → resolver → `wrap` so the re-skin is proven at runtime (§8.3).

### Integration tests (`test/integration/cupertino_ui_style_switching_test.dart`)

Against the production `LanguageRegistry` + `LiveUiResolver` and a real `LiveConfigProvider` with the diagnostics sink wired:

- Every `LiveUiControl` resolves as declared: four `adapterNative` with no diagnostic, six `shared` with `controlUnsupported` naming the control.
- Cupertino UI → core `material` → Cupertino UI replaces the rendering path each time (`cu.CupertinoTextField`/`Switch`/`Slider` present, then absent, then present again), and the caller-owned `TextEditingController` keeps its text across both switches.
- The core base reports `adapterMissing` for its own language and nothing else; while Cupertino UI is active the only reports are the `controlUnsupported` entries for the six controls this adapter does not declare, each once per language change (§15.5).
- Tabs, a shared-fallback control here, stay callable on both sides of the switch (§16.7).

A cross-adapter switch (this language against Fluent, Glass, …) is deliberately **not** tested from this package: §3.3 forbids depending on another style adapter, so that case belongs to the application integration suite. Brightness/accent re-skin is asserted in `test/theme/`.

### Platform verification

Before declaring support, test on the corresponding runtime. At minimum include iOS/macOS (primary fit), a touch Android target (sizing), and Android TV (focus/D-pad) in the validation matrix.

## 17. CI and architectural enforcement

These rules are enforced by `./tool/check_architecture.ps1`, which runs as a fatal
gate in `.github/workflows/architecture.yml`. The script holds one adapter → widget-library
map for the whole family, so the rules below are asserted once for every adapter rather than
implemented per package:

- `live_uikit_cupertino_ui` depends on `live_uikit` and `cupertino_ui` for its core integration.
- `live_uikit_cupertino_ui` does not depend on any other style adapter (fluent, macos, material_ui, glass, neumorphic, wind).
- The core package does not depend on `cupertino_ui`.
- Business packages do not import `package:cupertino_ui/cupertino_ui.dart`.
- The public barrel exports only `src/adapter/cupertino_ui_registration.dart`.
- The declared `cupertinoUiCapabilities` matches exactly the controls the adapter overrides (the contract-test invariant).
- Every `package:cupertino_ui/` import inside this package uses the `as cu` prefix, in `lib/`
  and `test/`: this fork deliberately shadows well-known Flutter widget names, so an
  unqualified import would resolve to the SDK's widgets and silently defeat the adapter (§3.3).
- The README's list of native controls is checked against `cupertinoUiCapabilities`: a control named in
  prose but not declared, or declared but unmentioned, fails the gate.
- §4's directory tree is checked against the package: every file the current-layout tree
  names must exist, and every `test/**_test.dart` on disk must be named there. The
  optional-modules block is exempt — those names must stay absent until built.
- Formatting, static analysis, and tests pass.

Example verification commands (run from the workspace root with the repository's normal Flutter SDK and workspace resolution):

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_cupertino_ui
flutter analyze packages/live_uikit_cupertino_ui
flutter test packages/live_uikit_cupertino_ui
```

## 18. Implementation phases

### Phase 1 — Contracts and registration ✅

- Align the adapter with the finalized core `LanguageAdapter` contract.
- Lock the stable id (`cupertinoUi`), display name, and `cupertinoUiCapabilities`.
- Expose `createCupertinoUiAdapter()` / `cupertinoUiAdapter` / `cupertinoUiAdapterId` / `cupertinoUiLocalizationsDelegates`.
- Keep the registration/contract test green.

### Phase 2 — Theme integration ✅

- `CupertinoUiThemeMapper` / `CupertinoUiThemeScope` / `CupertinoUiThemeBuilder` wired into `wrap`.
- Map brightness and primary color today; extend typography/density/surface roles as the fork exposes them.
- Test runtime theme rebuild on token change.

### Phase 3 — Core controls ✅ (native four)

Implemented and tested:

1. Button (ghost vs filled)
2. Text field (decoration, controller pass-through)
3. Switch (controlled, null-disable)
4. Slider (clamped, null-disable)

The remaining six controls stay on the shared renderer until native equivalents are added in this package's `widgets/` module.

### Phase 4 — Interaction and accessibility ◐

- Headless half done: focus nodes and callbacks are preserved on the native controls and asserted in `test/widgets/`; disabled controls are wired dead rather than decorative.
- Open, needs hardware: focus traversal on a device, Android TV D-pad, touch-target sizing.
- Add an `interaction/` module for explicit focus traversal and visible-focus verification.
- Test Android TV D-pad behavior and desktop keyboard navigation.
- Validate semantics and touch-target sizing on mobile targets.
- Document D-pad limitations rather than claiming parity.

### Phase 5 — Production readiness ◐

- §17 architectural rules are enforced by `tool/check_architecture.ps1` (library boundary, `cu` import prefix, registration-only barrel, capability/override match).
- Open: style-switching integration tests and per-platform verification.
- Add architectural CI checks (§17).
- Optionally add `icons/` (Cupertino icon mapping), `diagnostics/`, and `example/` as needs appear.
- Document known limitations and `cupertino_ui` upgrade compatibility.

## 19. Acceptance checklist

- [x] The package depends on `live_uikit` and `cupertino_ui` only for its core integration.
- [x] It extends `SharedLanguageAdapter` and implements the actual core `LanguageAdapter` contract.
- [x] It uses the stable adapter id `cupertinoUi` (never `cupertino`, `cupertino_ui`, or `Cupertino UI`).
- [x] `cupertinoUiCapabilities` declares exactly button, textField, switchWidget, slider as native.
- [x] Card, checkbox, segmented, progress, select, and tabBar fall back to the shared renderer and are reported as `controlUnsupported`.
- [x] `wrap` installs the mapped `cu.CupertinoTheme` scope from the resolved `DesignToken`.
- [x] Native controls preserve caller state (controller, focus node, callbacks) and never own business state.
- [x] The barrel exports only `cupertino_ui_registration.dart`.
- [x] No dependency on Riverpod or any other style adapter; business packages do not import `cupertino_ui`.
- [x] `cupertinoUiLocalizationsDelegates` is appended via the composition root; the global locale is never overridden.
- [x] Runtime switching preserves business state (§16 integration suite; the device half stays in the checkbox below).
- [x] Diagnostics flow through the core sink, not a logging package.
- [x] Tests and static analysis pass against `packages/live_uikit_cupertino_ui`.
- [ ] Platform claims (iOS/macOS primary, others functional) are backed by actual tests.

## 20. Final architecture decision

`live_uikit_cupertino_ui` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model (`LiveConfig` → `DesignToken`), runtime selection, and fallback policy.
- `live_uikit_cupertino_ui` maps those contracts to `cupertino_ui`, overriding `wrap` and the four controls it renders natively.
- `cupertino_ui` supplies the underlying Cupertino widgets and theme facilities (its own fork of Flutter's Cupertino).
- The PureLive application composition root registers adapters, appends the `cupertino_ui` localization delegates, and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation lets PureLive offer a Cupertino UI style — with four native controls and a documented, resolver-reported shared fallback for the rest — without forcing business packages to know which library is currently rendering their controls.
