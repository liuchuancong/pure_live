import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart' show PortraitDanmakuMode;
import 'package:pure_live/core/storage/hive_rx.dart' show HiveRxExtension;
import 'package:pure_live/get/get.dart';

/// The danmaku configuration a player surface renders with.
///
/// Both surfaces that draw a barrage — a live room and a replayed recording —
/// take their numbers from the same settings page, so the shared renderer talks
/// to this instead of to a room. A room may override individual values (its own
/// font, its own stroke), which is why this is an interface rather than a
/// straight read of [SettingsService].
///
/// Responsibilities:
///
/// - expose the values the shared renderer needs
///
/// It does not:
///
/// - store them (the settings page does)
/// - render anything
abstract interface class DanmakuSettingsSource {
  RxBool get noEmojiMode;

  RxDouble get danmakuArea;

  RxDouble get danmakuTopArea;

  RxDouble get danmakuBottomArea;

  RxDouble get danmakuSpeed;

  RxDouble get danmakuFontSize;

  RxInt get danmakuFontWeight;

  RxDouble get danmakuFontBorder;

  RxBool get danmakuMassMode;

  RxDouble get danmakuLetterSpacing;

  RxInt get danmakuMaxVisibleCount;

  RxDouble get danmakuOpacity;

  RxBool get pipDanmakuScaleAuto;

  RxDouble get pipDanmakuScaleValue;

  RxBool get enableDanmakuStroke;

  RxInt get danmakuFps;

  /// The font a barrage is drawn in, or null to use the platform default.
  String? get danmakuFontFamilyName;
}

/// [DanmakuSettingsSource] over the global danmaku settings.
///
/// A player with nothing of its own to say about danmaku — a replayed recording,
/// which has no room and therefore no room overrides — binds to this and gets
/// exactly what the settings page shows. A room keeps its own source so its
/// per-room font and stroke still win.
class SettingsDanmakuSource implements DanmakuSettingsSource {
  const SettingsDanmakuSource();

  DanmakuSettingsController get _settings => SettingsService.to.danmaku;

  @override
  RxBool get noEmojiMode => _settings.noEmojiMode;

  @override
  RxDouble get danmakuArea => _settings.danmakuArea;

  @override
  RxDouble get danmakuTopArea => _settings.danmakuTopArea;

  @override
  RxDouble get danmakuBottomArea => _settings.danmakuBottomArea;

  @override
  RxDouble get danmakuSpeed => _settings.danmakuSpeed;

  @override
  RxDouble get danmakuFontSize => _settings.danmakuFontSize;

  @override
  RxInt get danmakuFontWeight => _settings.danmakuFontWeight;

  @override
  RxDouble get danmakuFontBorder => _settings.danmakuFontBorder;

  @override
  RxBool get danmakuMassMode => _settings.danmakuMassMode;

  @override
  RxDouble get danmakuLetterSpacing => _settings.danmakuLetterSpacing;

  @override
  RxInt get danmakuMaxVisibleCount => _settings.danmakuMaxVisibleCount;

  @override
  RxDouble get danmakuOpacity => _settings.danmakuOpacity;

  @override
  RxBool get pipDanmakuScaleAuto => _settings.pipDanmakuScaleAuto;

  @override
  RxDouble get pipDanmakuScaleValue => _settings.pipDanmakuScaleValue;

  @override
  RxBool get enableDanmakuStroke => _settings.enableDanmakuStroke;

  @override
  RxInt get danmakuFps => _settings.danmakuFps;

  @override
  String? get danmakuFontFamilyName => _settings.danmakuFontFamilyName.v;
}

/// What a portrait picture does to the barrage over it.
///
/// A tall stream leaves very little width for a scrolling message to travel
/// through, so the viewer picks how much of the picture danmaku may cover — or
/// hides it there entirely. The panel-height rules belong to the layout; this is
/// only the arithmetic the renderer and its settings page must agree on.
abstract final class PortraitDanmakuPolicy {
  static bool hidesDanmaku({required bool isVerticalVideo, required PortraitDanmakuMode mode}) =>
      isVerticalVideo && mode == PortraitDanmakuMode.hidden;

  static double effectiveArea({
    required double configuredArea,
    required bool isVerticalVideo,
    required PortraitDanmakuMode mode,
  }) {
    if (!isVerticalVideo) return configuredArea;
    return switch (mode) {
      PortraitDanmakuMode.upperQuarter => configuredArea.clamp(0.0, 0.25).toDouble(),
      PortraitDanmakuMode.reduced => configuredArea.clamp(0.0, 0.50).toDouble(),
      _ => configuredArea,
    };
  }
}
