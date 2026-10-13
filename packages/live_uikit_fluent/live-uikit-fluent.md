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

Recommended initial structure:

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
    │       │   ├── fluent_ui_adapter.dart
    │       │   ├── fluent_ui_capabilities.dart
    │       │   └── fluent_ui_registration.dart
    │       ├── theme/
    │       │   ├── fluent_theme_mapper.dart
    │       │   ├── fluent_theme_builder.dart
    │       │   └── fluent_theme_scope.dart
    │       ├── widgets/
    │       │   ├── fluent_button_builder.dart
    │       │   ├── fluent_card_builder.dart
    │       │   ├── fluent_text_field_builder.dart
    │       │   ├── fluent_switch_builder.dart
    │       │   ├── fluent_checkbox_builder.dart
    │       │   └── fluent_slider_builder.dart
    │       ├── interaction/
    │       │   ├── fluent_focus_mapper.dart
    │       │   └── fluent_keyboard_mapper.dart
    │       ├── icons/
    │       │   └── fluent_icon_mapper.dart
    │       └── diagnostics/
    │           └── fluent_adapter_diagnostics.dart
    ├── test/
    │   ├── adapter/
    │   ├── theme/
    │   ├── widgets/
    │   ├── interaction/
    │   └── integration/
    └── example/
        └── lib/
            └── main.dart
```

Do not create empty files just to match this tree. Add modules as their functionality is implemented.

### Module responsibilities

| Module | Responsibility |
|---|---|
| `adapter/` | Adapter contract implementation, capability declaration, registration |
| `theme/` | Translate resolved PureLive theme into Fluent theme values |
| `widgets/` | Build Fluent controls from core widget specifications |
| `interaction/` | Map keyboard, focus, and TV-specific behavior |
| `icons/` | Map supported semantic icons to Fluent icons |
| `diagnostics/` | Report unsupported mappings and adapter errors |
| `test/` | Verify contract compliance and Fluent rendering |
| `example/` | Demonstrate integration without business dependencies |

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

The public entry point should expose only the adapter's supported registration API and any intentionally public Fluent integration utilities.

Example:

```dart
// lib/live_uikit_fluent.dart

library live_uikit_fluent;

export 'src/adapter/fluent_ui_registration.dart';
```

Do not export internal widget builders, mappers, diagnostics implementation classes, or third-party types unnecessarily.

The exact registration class and method names must match the finalized `live_uikit` core contracts. The following sections describe the required behavior, not a claim that these APIs already exist in the core package.

## 7. Adapter contract

The adapter implements the shared contract defined by `live_uikit`.

Conceptually, the contract should provide:

- A stable adapter identifier, such as `fluent`.
- A display name, such as `Fluent`.
- A capability declaration.
- Theme application or theme mapping.
- Control construction from shared specifications.
- Explicit handling of unsupported controls.

Conceptual example:

```dart
abstract interface class LiveUiAdapter {
  String get id;

  LiveUiCapabilities get capabilities;

  Widget buildControl(
    BuildContext context,
    LiveControl control,
  );
}
```

**Important:** Use the actual interface and types from `live_uikit` when implementing the package. Do not create a second competing `LiveUiAdapter` contract inside `live_uikit_fluent`.

### Adapter identifier

Use one stable identifier everywhere:

```text
fluent
```

The identifier is a machine-readable value, not a localized label. Do not use `fluent_ui`, `Fluent UI`, or a platform-dependent identifier as the runtime style ID.

### Capability declaration

The adapter should report actual supported controls, not simply claim support for every control in the core system.

Initial capability target:

| Control | Implementation | Initial status |
|---|---|---|
| Button | Native Fluent button | Required |
| Card | Native Fluent card or Fluent-themed container | Required |
| Text field | Native Fluent text input | Required |
| Switch | Native Fluent toggle switch | Required |
| Checkbox | Native Fluent checkbox | Required |
| Slider | Native Fluent slider | Required |
| Text | Flutter text with Fluent theme | Required |
| Icon | Fluent icons where mappings exist | Required |
| Dialog | Native Fluent dialog conventions | Later phase |
| Menu | Fluent menu controls | Later phase |
| Complex navigation | Fluent navigation controls | Separate capability |

The capability model should distinguish between:

- **Native:** A control is implemented using a suitable native Fluent widget.
- **Shared:** The core shared implementation is used.
- **Unsupported:** No implementation is available.

Use the core's actual enum names rather than adding a parallel capability system.

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

| Core theme property | Fluent mapping | Notes |
|---|---|---|
| Brightness | `brightness` | Light or dark |
| Accent color | `accentColor` | Brand accent |
| Font family | `fontFamily` | Respect configured font |
| Text styles | Fluent typography and text styles | Map supported roles |
| Density | `visualDensity` or control-specific sizing | Do not assume every widget responds identically |
| Focus appearance | `focusTheme` | Include TV and keyboard considerations |
| Surface/background | Relevant Fluent theme and container colors | Map only supported surfaces |
| Transparency | Acrylic or other supported surface effects where appropriate | Must have a fallback |
| Motion | Supported Fluent transitions | Do not imply all animations are globally configurable |

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

- Map primary, secondary, subtle, and destructive intent to supported Fluent variants.
- Preserve `onPressed`, enabled state, loading state, and accessibility labels.
- Do not place business actions inside the adapter.
- Use a shared fallback if a requested variant has no direct Fluent equivalent.

### Card

- Prefer Fluent card visuals where they match the intended role.
- Preserve content, padding, constraints, semantics, and click behavior.
- Do not assume every card is interactive.

### Text field

- Use the native Fluent text input.
- Preserve the supplied controller, focus node, callbacks, validation, enabled state, and text configuration.
- Do not create a second controller or silently own its lifecycle.
- Respect text direction, keyboard type, and accessibility labels.

### Switch

- Use the native Fluent toggle switch.
- Preserve controlled value and change callback.
- Do not introduce local persistent state.

### Checkbox

- Use the native Fluent checkbox.
- Preserve checked, unchecked, and indeterminate states if supported by the core contract.
- Preserve disabled state and callback semantics.

### Slider

- Use the native Fluent slider.
- Preserve minimum, maximum, divisions, current value, and callbacks.
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
    createFluentUiAdapter(),
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

If a Fluent control requires additional localization delegates, document that requirement and coordinate it through the application composition root. Do not independently override the global locale.

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

### Unit tests

Test:

- Stable adapter ID.
- Capability declarations.
- Brightness and accent-color mapping.
- Font and density mapping.
- Unsupported variant behavior.
- Fallback behavior.
- Theme invalidation when the resolved theme changes.

### Widget tests

Test:

- Button callback and disabled state.
- Text field controller and focus-node preservation.
- Switch value updates.
- Checkbox state transitions.
- Slider range and callbacks.
- Correct Fluent theme scope.
- Accessibility semantics.
- Layout under narrow and wide constraints.

### Integration tests

Test:

1. Register Fluent alongside at least one other adapter.
2. Select Fluent at runtime.
3. Render shared controls using the Fluent implementation.
4. Change brightness and accent color without restarting the app.
5. Switch from Fluent to another style and back.
6. Confirm form values and business controllers remain intact.
7. Confirm fallback behavior for a deliberately unsupported capability.

### Platform verification

Before declaring support for a platform, test on the corresponding runtime. At minimum, include Windows desktop, a mobile target, and Android TV in the planned validation matrix.

## 17. CI and architectural enforcement

Add checks to ensure that:

- `live_uikit_fluent` depends on `live_uikit`.
- `live_uikit_fluent` does not depend on other style adapters.
- The core package does not depend on `fluent_ui`.
- Business packages do not import `package:fluent_ui/fluent_ui.dart`.
- All public exports are intentional.
- The adapter's declared capabilities match tested implementations.
- Formatting, static analysis, and tests pass.

Example verification commands:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_fluent
flutter analyze packages/live_uikit_fluent
flutter test packages/live_uikit_fluent
```

Run these from the workspace root with the repository's normal Flutter SDK and workspace resolution.

## 18. Implementation phases

### Phase 1 — Contracts and registration

- Align the adapter with the finalized core contract.
- Define the stable ID and capability declarations.
- Register Fluent from the application composition root.
- Add a basic registration test.

### Phase 2 — Theme integration

- Implement theme mapping.
- Add the Fluent theme scope.
- Test brightness, accent color, typography, and density.
- Verify runtime theme updates.

### Phase 3 — Core controls

Implement and test:

1. Button
2. Card
3. Text field
4. Switch
5. Checkbox
6. Slider
7. Text and icon mappings

### Phase 4 — Interaction and accessibility

- Verify keyboard navigation and focus behavior.
- Test Android TV D-pad behavior.
- Validate semantics and accessibility.
- Add documented fallbacks for unsupported variants.

### Phase 5 — Production readiness

- Add integration tests for style switching.
- Add architectural CI checks.
- Verify all claimed platforms.
- Document known limitations and upgrade compatibility.

## 19. Acceptance checklist

- [ ] The package depends on `live_uikit` and `fluent_ui` only for its core integration.
- [ ] It implements the actual core adapter contract.
- [ ] It uses the stable adapter ID `fluent`.
- [ ] It reports accurate control capabilities.
- [ ] It maps the resolved core theme into Fluent theme values.
- [ ] It uses native Fluent controls where supported.
- [ ] It does not duplicate the core theme configuration.
- [ ] It does not own business state or persistence.
- [ ] It does not create a nested application shell unnecessarily.
- [ ] Runtime switching preserves business state.
- [ ] Keyboard, accessibility, and TV focus behavior are tested.
- [ ] Unsupported features follow the core fallback policy.
- [ ] Diagnostics use the shared core contract.
- [ ] Tests and static analysis pass.
- [ ] Platform support claims are backed by actual tests.

## 20. Final architecture decision

`live_uikit_fluent` is an adapter package, not a second UI framework.

- `live_uikit` defines the contracts, public controls, theme model, runtime selection, and fallback policy.
- `live_uikit_fluent` maps those contracts to Fluent UI.
- `fluent_ui` supplies the underlying Fluent widgets and theme facilities.
- The PureLive application composition root registers adapters and manages user preferences.
- Business packages depend only on the unified `live_uikit` API.

This separation allows PureLive to add or replace UI styles without forcing business packages to know which UI library is currently rendering their controls.
