import 'package:media_core_presentation/media_core_presentation.dart';

export 'package:media_core_presentation/media_core_presentation.dart'
    show
        VideoGeometryEvidence,
        NormalizedVideoInsets,
        ActiveVideoContentObservation,
        VideoGeometrySnapshot,
        PortraitStreamDetector,
        shouldInspectActiveVideoContent,
        PipAspectRatio,
        VideoPresentationGeometry,
        VideoPresentationPolicy,
        resolveConsistentVideoContentInsets,
        PresentationDensityMode,
        VideoOrientationKind,
        SourceOrientationOverride;

///

enum PortraitLayoutMode { balanced, immersive, compatibility }

enum PortraitFullscreenPolicy { followSource, followSystem, landscape }

/// How a confirmed portrait programme uses a tall phone while the dedicated
/// portrait-fullscreen route is active.
///
/// This is intentionally independent from the shared player fit setting. The
/// latter still controls ordinary rooms and landscape fullscreen, while these
/// modes only decide how the unavoidable aspect-ratio gap is presented.
enum PortraitFullscreenDisplayMode { complete, ambient, balanced, cover }

enum PortraitDanmakuMode { followGlobal, upperQuarter, reduced, hidden }

typedef VideoSourceOrientation = VideoOrientationKind;
typedef PortraitOrientationOverride = SourceOrientationOverride;
typedef PortraitPresentationPolicy = VideoPresentationPolicy;

extension PortraitLayoutModeMapping on PortraitLayoutMode {
  PresentationDensityMode get density => switch (this) {
    PortraitLayoutMode.balanced => PresentationDensityMode.balanced,
    PortraitLayoutMode.immersive => PresentationDensityMode.immersive,
    PortraitLayoutMode.compatibility => PresentationDensityMode.compatibility,
  };
}

double resolvePortraitNormalVideoHeight({
  required double availableWidth,
  required double availableHeight,
  required bool isPortraitSource,
  required double sourceAspectRatio,
  required bool adaptiveHeightEnabled,
  required PortraitLayoutMode mode,
  double resolutionHeight = 45,
  double minimumDanmakuHeight = 200,
}) {
  return VideoPresentationPolicy.resolveNormalVideoHeight(
    availableWidth: availableWidth,
    availableHeight: availableHeight,
    isPortraitSource: isPortraitSource,
    sourceAspectRatio: sourceAspectRatio,
    adaptiveHeightEnabled: adaptiveHeightEnabled,
    mode: mode.density,
    resolutionHeight: resolutionHeight,
    minimumDanmakuHeight: minimumDanmakuHeight,
  );
}
