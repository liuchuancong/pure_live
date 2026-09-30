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

/// 竖屏流适配的 pure_live 门面。
///
/// 通用几何与呈现策略（证据快照、方向判定、内容裁剪、显示比例、PiP 比例、
/// 法线高度）已下沉为 media_core_presentation 的 [VideoPresentationPolicy] /
/// [PortraitStreamDetector] / [VideoGeometrySnapshot] 等通用实现；本文件只保留
/// 绑定设置页与 Hive 存储的 pure_live 枚举，并对下沉模型做同值别名——
/// 设置存储（枚举 name 持久化）与全部调用方签名保持不变。
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

/// 同值别名：设置持久化沿用原枚举 name。
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

/// [VideoPresentationPolicy.resolveNormalVideoHeight] 的 pure 侧适配：
/// 设置枚举映射为包内密度模式，其余参数透传。
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
