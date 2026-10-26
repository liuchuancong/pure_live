/// Cross-platform runtime layer for Pure Live: it *distinguishes* platforms,
/// nothing more.
///
/// Run `PlatformBootstrap.init` once, then read facts from
/// `PlatformEnvironment`: the OS family (`PlatformKind`), the presentation
/// form factor (`FormFactor` — phone/tablet/desktop/TV, overridable by the
/// user's own setting through the bootstrap), the desktop deployment style
/// (`DesktopDistribution` — installed / MSIX / portable, declarable and
/// marker-detectable) and the conservative `PlatformCapabilities` that follow
/// from them.
///
/// Where data lives is a different concern: `live_platform_path_provider`
/// consumes the runtime snapshot produced here and owns directories, write
/// probes, privacy and conflict decisions.
library;

export 'src/bootstrap/platform_bootstrap.dart';
export 'src/contracts/platform_environment.dart';
export 'src/lifecycle/shutdown_coordinator.dart';
export 'src/runtime/runtime.dart';
