# pure_uikit

PureLive's unified UI system: the design-token core, the language-agnostic
component set, and the runtime that decides which widget library actually draws a
control.

## Purpose

One `UiConfig` (language, brightness, accent, density, font family, text scale,
transparency, motion) resolves through a seed → derived token pipeline into a
`DesignToken`, is installed by `LiveConfigProvider`, and is read as `LiveTheme`.
Every `Live*` component builds a neutral `Language*Spec` and hands it to the
active `LanguageAdapter`. Business pages therefore depend on this package only and
never on a concrete UI library: switching the design language re-skins the subtree
without a page changing a line.

## Responsibilities

- **Token model.** `SeedToken` → `DesignToken` via a composable `ThemeAlgorithm`
  (light/dark/compact), plus the component tokens (`ButtonRecipe`,
  `CardComponentToken`, `InputComponentToken`, …) and the `Style` merge model that
  paints them.
- **Public components.** Controls: `LiveBox`, `LiveButton`, `LiveIconButton`,
  `LiveCard`, `LiveTextField`, `LiveSwitch`, `LiveCheckbox`, `LiveSlider`,
  `LiveSegmented`, `LiveSelect`, `LiveTabs`/`LiveTab`, `LiveProgress`, `LiveSpinner`,
  `LiveTooltip`, `LiveMenu`/`LiveMenuItem`, `LiveAvatar`, `LiveBadge`,
  `LiveNumberStepper`, `LiveListRow`, plus the state views `LiveEmpty`, `LiveError`,
  `LiveLoading`. Overlays are functions, not widgets: `showLiveDialog(...)` and
  `styledToast(...)`. Layout helpers: `LiveBreakpoints`, `LiveLayoutBuilder`,
  `LiveContentGrid`, and `LiveEnvironment`/`LiveEnvironmentScope` for the
  platform/TV context. Every control is a dispatcher to the active adapter, never a
  branch on a language.
- **The adapter contract.** `LanguageAdapter` — an `abstract interface class` with
  seventeen control builders plus `appHost()` and `shell()` — the seventeen
  `Language*Spec` types, `LiveUiControl`/`LiveUiCapabilities` and
  `LiveUiSurface`/`LiveUiSurfaceCapabilities`. The core ships no renderer: each
  adapter package draws every control from its own library, so press, loading and
  label semantics are the contract's job, not a base class's.
- **Runtime dispatch and observability.** `LanguageRegistry` (keyed by
  `LiveDesignLanguage`, with no fallback slot), `LiveUiResolver`, and the
  `LiveUiDiagnostic`/`LiveUiDiagnosticSink` contracts, which report the one thing
  still worth reporting — an effect the device cannot afford.
- **Configuration and localization surface.** `LiveConfig`/`UiConfig` persistence
  models, `LiveConfigProvider`, and `liveLocalizationsDelegates`.
- **Backgrounds.** `LiveBackground` with its `LiveBackgroundStyle` model (solid,
  gradient, image, glass, raised) — the language-agnostic surface layer a page draws
  behind its controls. The frosted and blurred variants check `LiveTheme.canBlur` and
  degrade to a flat fill when the user's `reduceTransparency` setting or the device says
  a backdrop filter is not affordable. Video, layer stacks and the player
  seam belong to the separate `pure_uikit_background` package, which exports its own
  unrelated `LiveBackground`; the two packages do not depend on each other and the
  name collision is tracked in
  `docs/decisions/0005-two-livebackground-widgets-in-the-uikit-family.md`.

## What this package must not own

- Any concrete widget library. `pure_uikit` must not depend on `fluent_ui`,
  `macos_ui`, `material_ui`, `cupertino_ui`, `glass_morphism_plus`,
  `flutter_neumorphic_ui_kit` or `fluttersdk_wind`; each lives in its own
  `pure_uikit_<style>` adapter package (§7.1, enforced by
  `tool/check_architecture.ps1`).
- Application state management, navigation, persistence decisions, playback or
  platform windows.
- The style-selector UI or the user's saved preference — the composition root owns
  both and feeds them in here.

## Public entry points

`package:pure_uikit/pure_uikit.dart` is the only public barrel: applications and
adapter packages both import it. The surface it exposes is assembled in
`src/styling/styling.dart`, which is internal — there used to be a second
`styling.dart` entry point for adapters, and it bought nothing except the chance
of importing the layer you did not mean. Nothing under `src/` is intended for
outside import.

## Installation and usage

A Pub-workspace member (`resolution: workspace`).

```yaml
dependencies:
  flutter:
    sdk: flutter
  pure_uikit:
```

```dart
import 'package:pure_uikit/pure_uikit.dart';
import 'package:pure_uikit_material/pure_uikit_material.dart';

// The composition root registers the adapters that ship in this build.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.material: materialAdapter},
);

LiveConfigProvider(
  config: const UiConfig(language: LiveDesignLanguage.material),
  registry: registry,
  diagnostics: myDiagnosticSink,
  // `LiveApp` asks the active adapter for the host, so the window itself — the
  // route transition, the overlay, the chrome's strings — changes with the language.
  child: LiveApp(
    routerConfig: myRouter,
    localizationsDelegates: const [
      ...liveLocalizationsDelegates,
      ...materialLocalizationsDelegates,
    ],
  ),
);
```

## Dependencies

Flutter SDK (`widgets` primitives and `material`'s `RouterConfig`/localization
types, plus `flutter_localizations` for the delegates) and
`freezed`/`json_serializable` for the persisted configuration models. Nothing
else; notably no third-party UI library.

## Testing

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test packages/pure_uikit
```

`UiConfig` is `freezed`/`json_serializable` code (`live_config.freezed.dart`,
`live_config.g.dart`, both checked in); regenerate them after editing
`lib/src/styling/config/live_config.dart`.

`test/styling/live_ui_resolver_test.dart` covers the dispatch contract: a registered
language hands back its own adapter, an unregistered one throws
`LiveUiResolutionException`, and `requireControl`/`requireSurface` throw
`LiveUiCapabilityException` against a declaration with no method behind it.
`test/styling/live_config_provider_test.dart` covers what a host is told,
`test/backgrounds/live_background_test.dart` the blur affordance, and
`token_derivation_test.dart`, `style_merge_test.dart` and `recipe_test.dart` cover
the token pipeline, the `Style` cascade and the button recipe. Per-adapter
contract, theme, control and switching tests live in the `pure_uikit_*` packages.

## Known limitations

- An adapter's own library effect (glass blur, fluent acrylic) does not read
  `LiveTheme.canBlur`, so reduce-transparency is honoured by the core surfaces and not
  by those libraries; no adapter theme scope can overrule it today.
- `LanguageButtonSpec.selected` has a library affordance to map onto in only one
  language (forui's `FButton.selected`). Each adapter's §9 records what it does
  instead — a tint it composes, or a button that reads unselected.
- The environment axis (`LiveEnvironmentScope`, `LiveLayoutBuilder`, `LiveContentGrid`)
  resolves layout numbers, not control heights: those come from the seed, so a TV
  composition root has to raise `SeedToken.controlHeight` itself
  (`LiveSizing.controlHeightTv` is the number to use). Nothing in the core reads
  `LiveSizing`; it is the host-facing scale.
- The core ships no renderer, so a language with no adapter in this build is a
  startup fault rather than a look the app can settle for. The two Material- and
  iOS-shaped adapters (`material_ui`, `cupertino_ui`) are separate packages from
  the SDK's own libraries, so the visually closest pairs are also the ones most
  sensitive to a stale theme scope
  (see `packages/pure_uikit_material/pure-uikit-material.md` §11).
