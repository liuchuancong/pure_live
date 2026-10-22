/// The adaptive layout module: breakpoints, the responsive shell, its
/// navigation surfaces, and the content primitives the pages tile with.
///
/// Everything here is theme-agnostic — the surfaces read their colours from
/// the `PureTheme` tokens through `AdaptiveSurfaceColors`, so the one
/// structure draws the fluent shell wherever the package mounts it.
library;

export 'adaptive_breakpoints.dart';
export 'adaptive_content_layout.dart';
export 'adaptive_navigation.dart';
export 'adaptive_scaffold.dart';
export 'adaptive_shell_sizes.dart';
export 'adaptive_surface_tokens.dart';
export 'navigation/adaptive_brand_mark.dart';
export 'navigation/bottom_navigation.dart';
export 'navigation/drawer_navigation.dart';
export 'navigation/navigation_item.dart';
export 'navigation/rail_navigation.dart';
export 'navigation/sidebar_navigation.dart';
export 'navigation/tv_navigation.dart';
export 'responsive_content.dart';
export 'responsive_grid.dart';
