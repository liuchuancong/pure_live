/// pure_uikit's token system, modelled on Ant Design v5's three-layer design
/// token pipeline: a hand-authored `SeedToken`, derived into a full
/// `DesignToken` (colour ramps, neutral text/fill/background scales, type,
/// space, radius, motion, shadows) by a composable `ThemeAlgorithm`
/// (default / dark / compact), surfaced to components through a
/// `PureConfigProvider` and read as a resolved `PureTheme`.
///
/// Components are language-agnostic `Style`-driven groups: a `PureBox` plus a
/// variant `Recipe`, painting whatever tokens the active theme resolves. One
/// `UiConfig` (brightness, accent, density, global font family and scale,
/// transparency) re-skins the entire application without the business tree
/// rebuilding.
library;

export '../app/pure_app.dart';
// Pure, non-design-language utilities the token components and pages reuse: the
// background painter + its style, and the static radius / spacing / size scales.
export '../scales/radii.dart';
export '../scales/sizing.dart';
export '../scales/spacing.dart';
export 'config/localizations.dart';
export 'config/pure_config.dart';
export 'config/pure_design_language.dart';
export 'provider/pure_config_provider.dart';
export 'style/recipe.dart';
export 'style/style.dart';
export 'tokens/color_engine.dart';
export 'tokens/component_token.dart';
export 'tokens/design_token.dart';
export 'tokens/seed_token.dart';
export 'tokens/theme_algorithm.dart';
export 'widgets/chrome/pure_app_bar.dart';
export 'widgets/chrome/pure_app_shell.dart';
export 'widgets/chrome/pure_canvas_scope.dart';
export 'widgets/chrome/pure_nav_bar.dart';
export 'widgets/chrome/pure_scaffold.dart';
export 'widgets/chrome/pure_shell_types.dart';
export 'widgets/chrome/pure_title_bar.dart';
export 'widgets/content/pure_avatar.dart';
export 'widgets/content/pure_badge.dart';
export 'widgets/content/pure_card.dart';
export 'widgets/content/pure_state_views.dart';
export 'widgets/controls/pure_button.dart';
export 'widgets/controls/pure_checkbox.dart';
export 'widgets/controls/pure_field.dart';
export 'widgets/controls/pure_number_stepper.dart';
export 'widgets/controls/pure_progress.dart';
export 'widgets/controls/pure_segmented.dart';
export 'widgets/controls/pure_select.dart';
export 'widgets/controls/pure_slider.dart';
export 'widgets/controls/pure_switch.dart';
export 'widgets/controls/pure_tabs.dart';
export 'widgets/layout/pure_box.dart';
export 'widgets/layout/pure_environment.dart';
export 'widgets/overlays/pure_dialog.dart';
export 'widgets/overlays/pure_menu.dart';
export 'widgets/overlays/pure_toast.dart';
export 'widgets/overlays/pure_tooltip.dart';
