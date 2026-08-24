import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_settings_binding.dart';
import 'package:pure_live/common/index.dart';

/// multiview 的弹幕设置面板状态适配器。
///
/// live_play 的 DanmakuSettingsContent 面板要求传入 [DanmakuSettingsBinding]
/// 实现（唯一既有实现是 live_play 的 VideoController，其 Rx 是全局设置的
/// 镜像缓存）。multiview 没有每格 VideoController 包装，因此把接口直接
/// 透传到全局设置 [SettingsService.to.danmaku]：读写即全局生效，并按
/// 设置服务既有的 Hive 机制持久化——弹幕位置预设/显示区域与直播间
/// 体验完全一致（预设为全局语义，非每房间独立）。
class MultiviewDanmakuSettingsBinding implements DanmakuSettingsBinding {
  DanmakuSettingsController get _s => SettingsService.to.danmaku;

  @override
  RxBool get noEmojiMode => _s.noEmojiMode;

  @override
  RxDouble get danmakuArea => _s.danmakuArea;

  @override
  RxDouble get danmakuTopArea => _s.danmakuTopArea;

  @override
  RxDouble get danmakuBottomArea => _s.danmakuBottomArea;

  @override
  RxDouble get danmakuSpeed => _s.danmakuSpeed;

  @override
  RxDouble get danmakuFontSize => _s.danmakuFontSize;

  @override
  RxInt get danmakuFontWeight => _s.danmakuFontWeight;

  @override
  RxDouble get danmakuFontBorder => _s.danmakuFontBorder;

  @override
  RxDouble get danmakuOpacity => _s.danmakuOpacity;

  @override
  RxBool get enableDanmakuStroke => _s.enableDanmakuStroke;

  @override
  RxInt get danmakuFps => _s.danmakuFps;
}
