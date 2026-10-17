/// Cross-cutting background subsystem for Pure Live.
///
/// Exposes the sealed `BackgroundConfig` union and the single
/// `PureBackground` dispatcher every page and adapter consumes. Video
/// playback is reached through `BackgroundVideoSource` — the app
/// composition root binds that seam to media_core; this package stays
/// kernel-agnostic and never pulls a player dependency in.
///
/// The package holds **no policy of its own**: every "what to paint
/// when..." decision (fallback surface, letterbox fill sigma, blur,
/// pause signal, provider choice) is expressed as a field on the
/// config and interpreted by the caller. Nothing has a baked-in
/// default colour, sigma or auto-detected behaviour.
///
/// Only the primary library files are exported here. The `part of`
/// variants (SolidBackground, GradientBackground, ...) are visible
/// through the parent library because Dart forbids exporting a part
/// file independently.
library;

export 'src/contracts/background_video_source.dart' show BackgroundVideoSource;
export 'src/lifecycle/app_visible_scope.dart' show AppVisibilityObserver, AppVisibleScope;
export 'src/models/background_config/background_config.dart'
    show
        AssetImageSource,
        BackgroundConfig,
        BackgroundLayer,
        BackgroundLayerStack,
        BackgroundOverlay,
        GradientBackground,
        ImageBackground,
        ImageSource,
        NetworkImageSource,
        ProviderImageSource,
        SolidBackground,
        VideoBackground;
export 'src/rendering/live_background.dart' show PureBackground;
