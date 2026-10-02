/// 当前直播源是否为竖屏画面，供 Core 按方向选择紧凑窗口（画中画 / 应用内悬浮窗）几何。
///
/// 画面方向由 live 域的播放器持有，而小窗几何的读写位于 `windows_pip_driver`
/// （Core），两者之间只能通过这个端口相连：由 App 在 DI 里绑定，见
/// `InitialServices._bindCorePorts`。未绑定时按横屏处理，与只有一套几何时的行为一致。
///
/// 横竖屏各记一套是 2026-08-27（`feat: 增强画中画功能，支持竖屏模式下的窗口几何更新`）
/// 就有的行为，后来在一次合并里连同 `WindowPipGeometry` 的竖屏字段一起丢失；判定阈值
/// 沿用当年那份实现。
abstract final class CompactSourceOrientation {
  /// 读取当前源方向；未绑定时返回 false（横屏）。
  static bool Function()? read;

  /// 画面比例小于该值即按竖屏处理。
  static const double portraitAspectThreshold = 0.95;

  /// 按视频宽高判定；宽高任一非正表示尺寸未知。
  static bool isPortraitSize(double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) return false;
    return width / height < portraitAspectThreshold;
  }

  static bool get isPortrait => read?.call() ?? false;
}
