/// The unified UI system of Pure Live.
///
/// Business pages depend on this package — the design tokens, the theme,
/// the backgrounds and the component contract — and never on a design
/// language library directly. Which language renders is a user preference
/// resolved here, not a platform check in a page.
library;

export 'src/components/contracts/live_component_specs.dart';
export 'src/components/contracts/live_design_language_components.dart';
export 'src/core/design_language.dart';
export 'src/core/ui_configuration.dart';
export 'src/core/ui_environment.dart';
export 'src/core/ui_platform.dart';
export 'src/tokens/breakpoints.dart';
export 'src/tokens/colors.dart';
export 'src/tokens/elevation.dart';
export 'src/tokens/focus_tokens.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/radii.dart';
export 'src/tokens/sizing.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/typography.dart';
