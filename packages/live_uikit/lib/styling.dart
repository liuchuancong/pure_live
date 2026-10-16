/// live_uikit's token system, modelled on Ant Design v5's three-layer design
/// token pipeline: a hand-authored `SeedToken`, derived into a full
/// `DesignToken` (colour ramps, neutral text/fill/background scales, type,
/// space, radius, motion, shadows) by a composable `ThemeAlgorithm`
/// (default / dark / compact), surfaced to components through a
/// `LiveConfigProvider` and read as a resolved `LiveTheme`.
///
/// Components are language-agnostic `Style`-driven groups: a `LiveBox` plus a
/// variant `Recipe`, painting whatever tokens the active theme resolves. One
/// `UiConfig` (brightness, accent, density, global font family and scale,
/// transparency) re-skins the entire application without the business tree
/// rebuilding.
library;

// Pure, non-design-language utilities the token components and pages reuse: the
// background painter + its style, and the static radius / spacing / size scales.
export 'src/backgrounds/background_style.dart';
export 'src/backgrounds/live_background.dart';
export 'src/styling/color_engine.dart';
export 'src/styling/component_token.dart';
export 'src/styling/contracts/live_ui_adapter.dart';
export 'src/styling/contracts/live_ui_capabilities.dart';
export 'src/styling/design_token.dart';
export 'src/styling/diagnostics.dart';
export 'src/styling/live_config.dart';
export 'src/styling/localizations.dart';
export 'src/styling/recipe.dart';
export 'src/styling/root/live_config_provider.dart';
export 'src/styling/runtime/live_ui_fallback_policy.dart';
export 'src/styling/runtime/live_ui_registry.dart';
export 'src/styling/runtime/live_ui_resolver.dart';
export 'src/styling/seed_token.dart';
export 'src/styling/shared/shared_language_adapter.dart';
export 'src/styling/style.dart';
export 'src/styling/theme_algorithm.dart';
export 'src/styling/widgets/live_app.dart';
export 'src/styling/widgets/live_app_bar.dart';
export 'src/styling/widgets/live_avatar.dart';
export 'src/styling/widgets/live_badge.dart';
export 'src/styling/widgets/live_box.dart';
export 'src/styling/widgets/live_button.dart';
export 'src/styling/widgets/live_card.dart';
export 'src/styling/widgets/live_checkbox.dart';
export 'src/styling/widgets/live_dialog.dart';
export 'src/styling/widgets/live_environment.dart';
export 'src/styling/widgets/live_field.dart';
export 'src/styling/widgets/live_menu.dart';
export 'src/styling/widgets/live_nav_bar.dart';
export 'src/styling/widgets/live_number_stepper.dart';
export 'src/styling/widgets/live_progress.dart';
export 'src/styling/widgets/live_scaffold.dart';
export 'src/styling/widgets/live_segmented.dart';
export 'src/styling/widgets/live_select.dart';
export 'src/styling/widgets/live_slider.dart';
export 'src/styling/widgets/live_state_views.dart';
export 'src/styling/widgets/live_switch.dart';
export 'src/styling/widgets/live_tabs.dart';
export 'src/styling/widgets/live_toast.dart';
export 'src/styling/widgets/live_tooltip.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/sizing.dart';
export 'src/tokens/spacing.dart';
