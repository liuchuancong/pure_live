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
export 'src/scales/radii.dart';
export 'src/scales/sizing.dart';
export 'src/scales/spacing.dart';
export 'src/styling/config/live_config.dart';
export 'src/styling/config/localizations.dart';
export 'src/styling/contracts/live_ui_adapter.dart';
export 'src/styling/contracts/live_ui_capabilities.dart';
export 'src/styling/diagnostics/diagnostics.dart';
export 'src/styling/provider/live_config_provider.dart';
export 'src/styling/resolution/live_ui_fallback_policy.dart';
export 'src/styling/resolution/live_ui_registry.dart';
export 'src/styling/resolution/live_ui_resolver.dart';
export 'src/styling/shared/shared_language_adapter.dart';
export 'src/styling/style/recipe.dart';
export 'src/styling/style/style.dart';
export 'src/styling/tokens/color_engine.dart';
export 'src/styling/tokens/component_token.dart';
export 'src/styling/tokens/design_token.dart';
export 'src/styling/tokens/seed_token.dart';
export 'src/styling/tokens/theme_algorithm.dart';
export 'src/styling/widgets/chrome/live_app.dart';
export 'src/styling/widgets/chrome/live_app_bar.dart';
export 'src/styling/widgets/chrome/live_nav_bar.dart';
export 'src/styling/widgets/chrome/live_scaffold.dart';
export 'src/styling/widgets/content/live_avatar.dart';
export 'src/styling/widgets/content/live_badge.dart';
export 'src/styling/widgets/content/live_card.dart';
export 'src/styling/widgets/content/live_state_views.dart';
export 'src/styling/widgets/controls/live_button.dart';
export 'src/styling/widgets/controls/live_checkbox.dart';
export 'src/styling/widgets/controls/live_field.dart';
export 'src/styling/widgets/controls/live_number_stepper.dart';
export 'src/styling/widgets/controls/live_progress.dart';
export 'src/styling/widgets/controls/live_segmented.dart';
export 'src/styling/widgets/controls/live_select.dart';
export 'src/styling/widgets/controls/live_slider.dart';
export 'src/styling/widgets/controls/live_switch.dart';
export 'src/styling/widgets/controls/live_tabs.dart';
export 'src/styling/widgets/layout/live_box.dart';
export 'src/styling/widgets/layout/live_environment.dart';
export 'src/styling/widgets/overlays/live_dialog.dart';
export 'src/styling/widgets/overlays/live_menu.dart';
export 'src/styling/widgets/overlays/live_toast.dart';
export 'src/styling/widgets/overlays/live_tooltip.dart';
