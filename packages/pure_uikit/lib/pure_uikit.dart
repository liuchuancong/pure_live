/// pure_uikit — the design-language-dispatched widget kit for Pure Live.
///
/// One public surface, six modules, each with its own barrel: `adaptive`
/// (theme-agnostic layout and navigation surfaces), `app` (PureApp and the
/// host contract), `bootstrap` (the startup-frozen configuration, design
/// language included), `icons` (the semantic icon registry — rules only,
/// no icon fonts), `scales` (pure numbers and painters) and `styling` (the
/// token pipeline, providers and the language-dispatched controls).
///
/// Consumers import this file and nothing deeper; `src/` layout is the
/// package's own business.
library;

export 'src/adaptive/adaptive.dart';
export 'src/app/app.dart';
export 'src/bootstrap/bootstrap.dart';
export 'src/icons/icons.dart';
export 'src/scales/scales.dart';
export 'src/styling/styling.dart';
