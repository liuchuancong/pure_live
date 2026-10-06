import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/danmaku_settings_source.dart';
import 'package:pure_live/core/index.dart';

class MultiviewDanmakuSettingsSource implements DanmakuSettingsSource {
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
  RxBool get danmakuMassMode => _s.danmakuMassMode;

  @override
  RxDouble get danmakuLetterSpacing => _s.danmakuLetterSpacing;

  @override
  RxDouble get danmakuOpacity => _s.danmakuOpacity;

  @override
  RxBool get pipDanmakuScaleAuto => _s.pipDanmakuScaleAuto;

  @override
  RxDouble get pipDanmakuScaleValue => _s.pipDanmakuScaleValue;

  @override
  RxInt get danmakuMaxVisibleCount => _s.danmakuMaxVisibleCount;

  @override
  @override
  RxBool get enableDanmakuStroke => _s.enableDanmakuStroke;

  @override
  RxInt get danmakuFps => _s.danmakuFps;
}
