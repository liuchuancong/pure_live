/// pure_uikit's styling module: the token system, modelled on Ant Design
/// v5's three-layer design token pipeline — a hand-authored `SeedToken`,
/// derived into a full `DesignToken` (colour ramps, neutral text/fill/
/// background scales, type, space, radius, motion, shadows) by a composable
/// `ThemeAlgorithm` (default / dark / compact), surfaced to components
/// through a `PureConfigProvider` and read as a resolved `PureTheme`.
///
/// Components are language-agnostic `Style`-driven groups: a `PureBox` plus
/// a variant `Recipe`, painting whatever tokens the active theme resolves.
/// One `UiConfig` (brightness, accent, density, global font family and
/// scale, transparency) re-skins the entire application without the
/// business tree rebuilding.
///
/// Each subdirectory owns its exports in a barrel of the directory's name;
/// this file only aggregates them. The one exception is `style/`, whose
/// two core files (`Style`, `Recipe`) are the module's namesakes and are
/// exported directly rather than hiding behind a same-named barrel.
library;

export 'adapters/adapters.dart';
export 'config/config.dart';
export 'provider/provider.dart';
export 'style/recipe.dart';
export 'style/style.dart';
export 'tokens/tokens.dart';
export 'widgets/widgets.dart';
