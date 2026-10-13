/// The unified UI system of Pure Live.
///
/// A design-token core (Ant Design v5 style: seed → derived tokens → theme
/// algorithms) drives a `LiveConfigProvider` that re-skins the whole tree from
/// one `UiConfig`. The core defines the contracts, tokens, runtime dispatch and
/// the shared token renderer; each design language is rendered by an adapter in
/// its own `live_uikit_*` package (fluent, macos, neumorphic, glass, wind,
/// cupertino_ui, material_ui), while Material and Cupertino fall back to the
/// shared token base. Every `Live*` component reads the resolved [LiveTheme] and
/// delegates to the active [LanguageAdapter], so the core never depends on a
/// third-party UI library. Business pages depend on this package and never on a
/// design language directly.
library;

import 'package:live_uikit/styling.dart' show LanguageAdapter, LiveTheme;

export 'styling.dart';
