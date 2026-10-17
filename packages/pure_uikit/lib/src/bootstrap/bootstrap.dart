/// The startup configuration layer: what a process is born with, as distinct
/// from what the user can edit afterwards.
///
/// The design language belongs here. It decides which app host gets mounted,
/// and a host is not swappable inside a running process — the route stack, the
/// overlay a dialog opens into, the scroll physics and the selection toolbar
/// all belong to it. So the language is resolved once at boot
/// (`PureUiStartupResolver`), frozen into `PureUiStartupConfig` for the life of
/// the process, and a later edit to the stored preference waits for the next
/// launch. Everything else the appearance holds — brightness, accent, font,
/// density, transparency — stays live, and is not routed through this layer.
library;

export 'pure_ui_startup_config.dart';
export 'pure_ui_startup_resolver.dart';
