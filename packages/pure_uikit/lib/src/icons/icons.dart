/// The kit's icon subsystem: rules, not resources.
///
/// `api/` is what business code touches (the PureIcon widget, the key
/// interface, the one registry class); `theme/` owns size/colour/state
/// rules; `registry/`
/// owns the four-tier lookup and the conspicuous fallback; `rendering/`
/// types the custom-source contract. The kit depends on no icon-font
/// package — every resource arrives through the app's registration.
library;

export 'api/pure_icon.dart';
export 'api/pure_icon_key.dart';
export 'api/pure_icon_registry.dart';
export 'api/pure_icon_style.dart';
export 'registry/icon_fallback.dart';
export 'registry/icon_mapping.dart';
export 'registry/icon_resolver.dart';
export 'rendering/icon_builder.dart';
export 'rendering/icon_render_context.dart';
export 'theme/pure_icon_theme.dart';
export 'theme/pure_icon_tokens.dart';
