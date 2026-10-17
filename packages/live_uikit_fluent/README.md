# live_uikit_fluent

The Fluent Design language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with `fluent_ui` widgets — a
library widget wherever `fluent_ui` has one for the job, Fluent's own parts
composed wherever it does not — and maps the resolved design token into
`FluentThemeData`.

See `live-uikit-fluent.md` in this directory for the full architecture and
integration specification.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, the tokens, the
runtime dispatch and the adapter interface. This package supplies the **Fluent**
implementation of that contract so an application can select `fluent` at runtime
and have its whole window — controls, host and shell — drawn by `fluent_ui`,
without any business page importing `fluent_ui` directly.

`LanguageAdapter` is an `abstract interface class`, and `FluentLanguageAdapter`
implements it directly. Every control and both structural surfaces are answered
here, in this language.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.fluent` (stable id `fluent`).
- Map the resolved `DesignToken` into a `FluentThemeData` and install it through a
  `FluentTheme` scope (never a nested `FluentApp` inside another host).
- Build native Fluent widgets for all seventeen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Twelve of them are a one-for-one mapping
  onto a widget of the library. Five are composed out of Fluent's own parts instead,
  and each says so in its builder (§9): `segmented` and `nav bar` are
  `ToggleButton` groups, because `fluent_ui` has no segmented track and no bottom
  strip; a `tab bar` is a row of `HoverButton` cells carrying Fluent's accent
  underline, because the library's `TabView` fuses the strip to a body; a `tab view`
  is an `AnimatedSwitcher` page swap, because this version of the library has no
  `Pivot`; and an `app bar` is a `PageHeader` whose actions ride in the command-bar
  slot as a row, because `CommandBar` builds its own items from icons and callbacks
  the spec does not carry. A `dialog` is the opposite case worth naming: it maps
  onto `ContentDialog` used as a plain surface, while the route and the barrier stay
  the core's (`showLiveDialog`).
- Own both structural surfaces: the app host is `FluentApp`, and the app shell is
  `NavigationView` with its `NavigationPane` of `PaneItem`s (§ surfaces).
- Declare the whole contract — all 17 controls, both surfaces — in
  `fluentCapabilities` and `fluentSurfaces`. The architecture guard compares each
  declaration with the methods the adapter actually overrides, and
  `LiveUiResolver.requireControl`/`requireSurface` raise `LiveUiCapabilityException`
  for a claim the adapter cannot serve (§16/§17).
- Expose `fluentLocalizationsDelegates` for the composition root to install.

## What this package must not own

- Global theme preferences or their persistence, and the style-selector UI.
- Shared design-token definitions or global configuration storage.
- Any state management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters, or on `fluent_ui` leaking into
  business packages.

Nothing in the contract is served by another package's rendering: every control a
Fluent page asks for is drawn by this one, either with the library's own widget or
with a composition written here in Fluent's terms. What stays unmapped is a
*spec field* the library has no slot for — `LanguageButtonSpec.selected` and
`.style`, `LanguageCardSpec.focusNode`, `LanguageProgressSpec.showLabel`,
`LanguageTabsSpec.spacing`, `LanguageAppBarSpec.centerTitle` and `.height`,
`LanguageScaffoldSpec.extendBodyBehindAppBar`, `LanguageShellSpec.trailing`,
`LanguageTabViewSpec.onIndexChanged` — and each is recorded as unmapped in §9
rather than faked with a hand-painted substitute.

## Public entry point

`package:live_uikit_fluent/live_uikit_fluent.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

PureLive uses a single Pub workspace; this package is already a workspace member.
Business packages depend only on `live_uikit`. The **application composition root**
registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.fluent: fluentAdapter},
);

// A language this build did not register is not a degrade — it is a fault:
// `LiveUiResolver.resolve` throws `LiveUiResolutionException`. Register every
// language the app claims to support.
```

Selecting the style at runtime is `UiConfig.language = LiveDesignLanguage.fluent`;
a `LiveButton` then draws through this adapter with no change to the page. The
whole app is hosted by `LiveApp`, which dispatches to `FluentApp` for this
language; append Fluent's delegates to the core's:

```dart
LiveApp(
  routerConfig: router,
  localizationsDelegates: [
    ...liveLocalizationsDelegates,
    ...fluentLocalizationsDelegates,
  ],
)
```

## Dependencies

- `live_uikit` (the contracts, tokens and runtime dispatch)
- `fluent_ui` ^4.16.1 (the native Fluent widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_fluent
```

Four suites, one per concern (§16): `test/adapter/` checks the stable id and
display name, that all seventeen controls and both surfaces are declared, and that
the core resolver serves every one of them through this adapter while an
unregistered language raises `LiveUiResolutionException`; `test/theme/` checks the
§8.1 mapping and the §8.3 re-skin; `test/widgets/` drives the controls through the
real dispatch path and asserts the `fluent_ui` widget that came out the other
side; `test/integration/` checks the whole contract resolves native with no
downgrade recorded and that a re-theme leaves the caller's controller intact.

## Known limitations

- `select` keeps the spec's value type because `fluent.ComboBox<T>` hands it back
  unchanged; `errorText` is drawn as a caption because a bare `fluent.TextBox` has
  no error slot; `showLabel`, `spacing`, `centerTitle`, `height`,
  `extendBodyBehindAppBar`, `trailing` and a viewer-driven tab swipe have no
  Fluent counterpart and are documented as unmapped in §9 rather than approximated.
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every control driven through the real dispatch path, mapped and
  composed alike), and `test/integration/` (the whole contract resolved, and a
  re-theme with caller-owned state preserved). What remains untested is the part
  that needs hardware: focus traversal, Android TV D-pad, and the platform claims
  in §13.
- Fluent can be selected on every supported platform, but native Windows chrome
  and system integrations must not be assumed elsewhere (§13).
