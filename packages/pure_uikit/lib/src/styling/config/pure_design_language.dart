/// The design language the app draws with. Every value names the widget
/// library the app draws for it; the Pure widgets are built from that
/// library's real components — there is no adapter or spec in between.
library;

/// The design language the app renders with.
enum PureDesignLanguage {
  /// Windows `fluent_ui`.
  fluent,
}
