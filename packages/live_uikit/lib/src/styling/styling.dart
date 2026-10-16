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
export '../backgrounds/background_style.dart';
export '../backgrounds/live_background.dart';
export '../scales/radii.dart';
export '../scales/sizing.dart';
export '../scales/spacing.dart';
export 'config/live_config.dart';
export 'config/localizations.dart';
export 'contracts/live_ui_adapter.dart';
export 'contracts/live_ui_capabilities.dart';
export 'contracts/live_ui_surfaces.dart';
export 'diagnostics/diagnostics.dart';
export 'provider/live_config_provider.dart';
export 'resolution/live_ui_fallback_policy.dart';
export 'resolution/live_ui_registry.dart';
export 'resolution/live_ui_resolver.dart';
export 'shared/shared_language_adapter.dart';
export 'style/recipe.dart';
export 'style/style.dart';
export 'tokens/color_engine.dart';
export 'tokens/component_token.dart';
export 'tokens/design_token.dart';
export 'tokens/seed_token.dart';
export 'tokens/theme_algorithm.dart';
export 'widgets/chrome/live_app.dart';
export 'widgets/chrome/live_app_bar.dart';
export 'widgets/chrome/live_app_shell.dart';
export 'widgets/chrome/live_nav_bar.dart';
export 'widgets/chrome/live_scaffold.dart';
export 'widgets/content/live_avatar.dart';
export 'widgets/content/live_badge.dart';
export 'widgets/content/live_card.dart';
export 'widgets/content/live_state_views.dart';
export 'widgets/controls/live_button.dart';
export 'widgets/controls/live_checkbox.dart';
export 'widgets/controls/live_field.dart';
export 'widgets/controls/live_number_stepper.dart';
export 'widgets/controls/live_progress.dart';
export 'widgets/controls/live_segmented.dart';
export 'widgets/controls/live_select.dart';
export 'widgets/controls/live_slider.dart';
export 'widgets/controls/live_switch.dart';
export 'widgets/controls/live_tabs.dart';
export 'widgets/layout/live_box.dart';
export 'widgets/layout/live_environment.dart';
export 'widgets/overlays/live_dialog.dart';
export 'widgets/overlays/live_menu.dart';
export 'widgets/overlays/live_toast.dart';
export 'widgets/overlays/live_tooltip.dart';
