/// The unified UI system of Pure Live.
///
/// Business pages depend on this package — the design tokens, the theme,
/// the backgrounds and the component contract — and never on a design
/// language library directly. Which language renders is a user preference
/// resolved here, not a platform check in a page.
library;

export 'src/backgrounds/background_presets.dart';
export 'src/backgrounds/background_style.dart';
export 'src/backgrounds/live_background.dart';
export 'src/components/buttons/live_button.dart';
export 'src/components/cards/live_card.dart';
export 'src/components/contracts/live_component_specs.dart';
export 'src/components/contracts/live_design_language_components.dart';
export 'src/components/dialogs/live_dialog.dart';
export 'src/components/indicators/live_state_views.dart';
export 'src/components/inputs/live_text_field.dart';
export 'src/components/menus/live_menu.dart';
export 'src/core/design_language.dart';
export 'src/core/ui_component_registry.dart';
export 'src/core/ui_configuration.dart';
export 'src/core/ui_environment.dart';
export 'src/core/ui_platform.dart';
export 'src/design_languages/cupertino/cupertino_components.dart';
export 'src/design_languages/cupertino/cupertino_language.dart';
export 'src/design_languages/fluent/fluent_components.dart';
export 'src/design_languages/fluent/fluent_language.dart';
export 'src/design_languages/macos/macos_components.dart';
export 'src/design_languages/macos/macos_language.dart';
export 'src/design_languages/material/material_components.dart';
export 'src/design_languages/material/material_language.dart';
export 'src/design_languages/neumorphic/neumorphic_components.dart';
export 'src/design_languages/neumorphic/neumorphic_language.dart';
export 'src/design_languages/yaru/yaru_components.dart';
export 'src/design_languages/yaru/yaru_language.dart';
export 'src/focus/live_focus_highlight.dart';
export 'src/integration/wind_integration.dart';
export 'src/theme/live_color_scheme.dart';
export 'src/theme/live_component_theme.dart';
export 'src/theme/live_theme.dart';
export 'src/theme/live_theme_data.dart';
export 'src/theme/live_theme_parts.dart';
export 'src/theme/theme_resolver.dart';
export 'src/tokens/breakpoints.dart';
export 'src/tokens/colors.dart';
export 'src/tokens/elevation.dart';
export 'src/tokens/focus_tokens.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/sizing.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/typography.dart';
