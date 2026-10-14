# live_uikit

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
- **The adapter contract.** `LanguageAdapter`, the ten `Language*Spec` types,
  `LiveUiControl`, `LiveUiCapabilities`, and `SharedLanguageAdapter` — the
  token-driven base renderer that serves every control an adapter does not
  override, including the `interactive()`/`buttonLabel()`/`labelled()` seam
  adapters reuse so press, loading and label semantics cannot diverge.
- **Runtime dispatch and observability.** `LanguageRegistry` (keyed by
  `LiveDesignLanguage`, with the shared fallback), `LiveUiResolver`, the fallback
  policy, and the `LiveUiDiagnostic`/`LiveUiDiagnosticSink` contracts that make
  every downgrade reported rather than silent.
- **Configuration and localization surface.** `LiveConfig`/`UiConfig` persistence
  models, `LiveConfigProvider`, and `liveLocalizationsDelegates`.
- **Backgrounds.** `LiveBackground` with its `LiveBackgroundStyle` model (solid,
  gradient, image, glass, raised) — the language-agnostic surface layer a page draws
  behind its controls. The frosted and blurred variants check `LiveTheme.canBlur` and
  degrade to a flat fill when the user's `reduceTransparency` setting or the device says
  a backdrop filter is not affordable. Video, layer stacks and the player
  seam belong to the separate `live_uikit_background` package, which exports its own
  unrelated `LiveBackground`; the two packages do not depend on each other and the
  name collision is tracked in
  `docs/decisions/0005-two-livebackground-widgets-in-the-uikit-family.md`.

## What this package must not own

- Any concrete widget library. `live_uikit` must not depend on `fluent_ui`,
  `macos_ui`, `material_ui`, `cupertino_ui`, `glass_morphism_plus`,
  `flutter_neumorphic_ui_kit` or `fluttersdk_wind`; each lives in its own
  `live_uikit_<style>` adapter package (§7.1, enforced by
  `tool/check_architecture.ps1`).
- Application state management, navigation, persistence decisions, playback or
  platform windows.
- The style-selector UI or the user's saved preference — the composition root owns
  both and feeds them in here.

## Public entry points

`package:live_uikit/live_uikit.dart` is the barrel applications import; it re-exports
`package:live_uikit/styling.dart`, which is the finer-grained entry the adapter
packages import. Two entry points rather than one on purpose: `live_uikit.dart`
names the whole system for an app, while `styling.dart` keeps the token/contract
surface importable without pulling the re-export layer. Both export only public
API; nothing under `src/` is intended for outside import.

## Installation and usage

A Pub-workspace member (`resolution: workspace`).

```yaml
dependencies:
  flutter:
    sdk: flutter
  live_uikit:
```

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';

// The composition root registers the adapters that ship in this build.
const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.materialUi: materialUiAdapter},
  fallback: SharedLanguageAdapter(),
);

LiveConfigProvider(
  config: const UiConfig(language: LiveDesignLanguage.materialUi),
  registry: registry,
  diagnostics: myDiagnosticSink,
  child: MaterialApp(
    localizationsDelegates: const [
      ...liveLocalizationsDelegates,
      ...materialUiLocalizationsDelegates,
    ],
    home: LiveButton(label: 'Save', onPressed: save),
  ),
);
```

## Dependencies

Flutter SDK (`widgets`, `material` primitives for the token renderer and
`flutter_localizations` for the delegates) and `freezed`/`json_serializable` for
the persisted configuration models. Nothing else; notably no third-party UI
library.

## Testing

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test packages/live_uikit
```

`UiConfig` is `freezed`/`json_serializable` code (`live_config.freezed.dart`,
`live_config.g.dart`, both checked in); regenerate them after editing
`lib/src/styling/live_config.dart`.

`test/styling/live_ui_resolver_test.dart` covers the dispatch contract: a
registered language resolves `adapterNative` with no diagnostic, an unregistered
one downgrades to `shared` and records `adapterMissing`, and a fail-fast policy
throws instead of rendering a silent blank. `test/styling/live_config_provider_test.dart`
covers what a host is told, `test/backgrounds/live_background_test.dart` the blur
affordance, and `token_derivation_test.dart`, `style_merge_test.dart`,
`recipe_test.dart` and `shared_renderer_test.dart` cover the token pipeline, the
`Style` cascade, the button recipe and the `Token*` renderer. Per-adapter contract,
theme, control and switching tests live in the `live_uikit_*` packages.

## Known limitations

- An adapter's own library effect (glass blur, fluent acrylic) does not read
  `LiveTheme.canBlur`, so reduce-transparency is honoured by the core surfaces and not
  by those libraries; no adapter theme scope can overrule it today.
- `LanguageButtonSpec.selected` is painted by the token base only. Each adapter's §9
  records that its library has no equivalent selected affordance, so a toggled button
  drawn by an adapter reads unselected.
- The environment axis (`LiveEnvironmentScope`, `LiveLayoutBuilder`, `LiveContentGrid`)
  resolves layout numbers, not control heights: those come from the seed, so a TV
  composition root has to raise `SeedToken.controlHeight` itself
  (`LiveSizing.controlHeightTv` is the number to use). Nothing in the core reads
  `LiveSizing`; it is the host-facing scale.
- `SharedLanguageAdapter` is the core `material`/`cupertino` renderer; the two fork
  adapters (`material_ui`, `cupertino_ui`) are separate packages, so the visually
  closest pairs are also the ones most sensitive to a stale theme scope
  (see `packages/live_uikit_material_ui/live-uikit-material-ui.md` §11).
