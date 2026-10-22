import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Everything the barrage draws with, on the video and in the list: size, opacity, area, speed, weight, stroke, gifts, gestures and the template — the reference's `danmaku` section.
// ignore_for_file: unnecessary_type_name_in_constructor
@immutable
final class DanmakuPreferences extends Equatable {
  /// The shipping defaults.
  const new({
    this.danmakuVisible = true,
    this.barrageFontSize = 15,
    this.barrageOpacity = 1,
    this.barrageArea = 1,
    this.barrageTopArea = 0,
    this.barrageBottomArea = 0,
    this.barrageSpeed = 120,
    this.barrageFontWeight = 600,
    this.barrageStroke = true,
    this.barrageStrokeWidth = 3,
    this.barrageShowSender = true,
    this.barrageMaxVisible = 48,
    this.barrageFps = 30,
    this.barrageNoEmoji = false,
    this.barrageCollapse = false,
    this.barrageCollapseWindow = 5,
    this.barragePausedBehavior = 'pause',
    this.barrageAutoFps = true,
    this.barrageFpsMode = 'powerSaving',
    this.barrageShowGifts = false,
    this.chatShowGifts = true,
    this.chatValuableGiftsOnly = false,
    this.chatGiftValueYuan = false,
    this.superChatIncludesMembership = false,
    this.youtubeAllChat = false,
    this.barrageTapAction = true,
    this.barrageLongPressAction = true,
    this.barrageFontFamily = '',
    this.barrageHoldOnPress = false,
    this.barrageListFontSize = 13,
    this.barrageListLineSpacing = 4,
    this.barrageListStyle = 'compact',
    this.barrageTemplate = '',
  });

  /// Reads the domain's keys from the flat document; unknown shapes decode
  /// to the defaults.
  factory DanmakuPreferences.fromJson(Map<String, Object?> json) {
    return DanmakuPreferences(
      danmakuVisible: json['danmakuVisible'] as bool? ?? true,
      barrageFontSize: (json['barrageFontSize'] as num?)?.toDouble() ?? 15,
      barrageOpacity: (json['barrageOpacity'] as num?)?.toDouble() ?? 1,
      barrageArea: (json['barrageArea'] as num?)?.toDouble() ?? 1,
      barrageTopArea: (json['barrageTopArea'] as num?)?.toDouble() ?? 0,
      barrageBottomArea: (json['barrageBottomArea'] as num?)?.toDouble() ?? 0,
      barrageSpeed: (json['barrageSpeed'] as num?)?.toDouble() ?? 120,
      barrageFontWeight: (json['barrageFontWeight'] as num?)?.toInt() ?? 600,
      barrageStroke: json['barrageStroke'] as bool? ?? true,
      barrageStrokeWidth: (json['barrageStrokeWidth'] as num?)?.toDouble() ?? 3,
      barrageShowSender: json['barrageShowSender'] as bool? ?? true,
      barrageMaxVisible: (json['barrageMaxVisible'] as num?)?.toInt() ?? 48,
      barrageFps: (json['barrageFps'] as num?)?.toInt() ?? 30,
      barrageNoEmoji: json['barrageNoEmoji'] as bool? ?? false,
      barrageCollapse: json['barrageCollapse'] as bool? ?? false,
      barrageCollapseWindow: (json['barrageCollapseWindow'] as num?)?.toInt() ?? 5,
      barragePausedBehavior: json['barragePausedBehavior'] as String? ?? 'pause',
      barrageAutoFps: json['barrageAutoFps'] as bool? ?? true,
      barrageFpsMode: json['barrageFpsMode'] as String? ?? 'powerSaving',
      barrageShowGifts: json['barrageShowGifts'] as bool? ?? false,
      chatShowGifts: json['chatShowGifts'] as bool? ?? true,
      chatValuableGiftsOnly: json['chatValuableGiftsOnly'] as bool? ?? false,
      chatGiftValueYuan: json['chatGiftValueYuan'] as bool? ?? false,
      superChatIncludesMembership: json['superChatIncludesMembership'] as bool? ?? false,
      youtubeAllChat: json['youtubeAllChat'] as bool? ?? false,
      barrageTapAction: json['barrageTapAction'] as bool? ?? true,
      barrageLongPressAction: json['barrageLongPressAction'] as bool? ?? true,
      barrageFontFamily: json['barrageFontFamily'] as String? ?? '',
      barrageHoldOnPress: json['barrageHoldOnPress'] as bool? ?? false,
      barrageListFontSize: (json['barrageListFontSize'] as num?)?.toDouble() ?? 13,
      barrageListLineSpacing: (json['barrageListLineSpacing'] as num?)?.toDouble() ?? 4,
      barrageListStyle: json['barrageListStyle'] as String? ?? 'compact',
      barrageTemplate: json['barrageTemplate'] as String? ?? '',
    );
  }

  /// Whether a room draws the barrage over its video. The reference's
  /// `danmaku.hideDanmaku`, inverted: the switch says what is on.
  final bool danmakuVisible;

  /// The barrage text size, in logical pixels.
  final double barrageFontSize;

  /// The barrage text opacity, 0..1.
  final double barrageOpacity;

  /// The share of the video the flying barrage may use, 0..1 — the
  /// reference's `danmakuArea`.
  final double barrageArea;

  /// The blank band kept under the top edge, in logical pixels
  /// (`danmakuTopArea`).
  final double barrageTopArea;

  /// The blank band kept above the bottom edge, in logical pixels
  /// (`danmakuBottomArea`).
  final double barrageBottomArea;

  /// How fast a line crosses, in pixels per second (`danmakuSpeed`).
  final double barrageSpeed;

  /// The barrage text weight, a CSS weight (100..900, `danmakuFontWeight`).
  final int barrageFontWeight;

  /// Whether the barrage text carries its dark outline (`enableDanmakuStroke`).
  final bool barrageStroke;

  /// The outline's blur radius, the stroke width (`danmakuFontBorder`).
  final double barrageStrokeWidth;

  /// Whether the sender's name rides in front of the line (`showChatNames`).
  final bool barrageShowSender;

  /// How many lines may fly at once (`danmakuMaxVisibleCount`).
  final int barrageMaxVisible;

  /// The repaint rate of the flying barrage, 25..240 FPS
  /// (`danmakuFps`; the automatic variant follows the display in the
  /// reference — this build drives the manual answer).
  final int barrageFps;

  /// Whether emote-only chats are dropped (`noEmojiMode`).
  final bool barrageNoEmoji;

  /// Whether an identical chat seen again inside [barrageCollapseWindow]
  /// keeps only its first copy (`collapseRepeatedDanmaku`).
  final bool barrageCollapse;

  /// The collapse window in seconds, 1..30 (`repeatedDanmakuWindowSeconds`).
  final int barrageCollapseWindow;

  /// What the barrage does while the video is paused: `pause` holds every
  /// line in place, `fly` lets it cross on (`danmakuPausedBehavior`).
  final String barragePausedBehavior;

  /// Whether the repaint clock follows the display instead of the manual
  /// number (the reference's danmakuAutoFps; true ships it there).
  final bool barrageAutoFps;

  /// What the automatic clock may reach: `powerSaving`/`balanced` cap at 60,
  /// `performance` lets the display's own maximum through (the reference's
  /// refreshRateMode trio).
  final String barrageFpsMode;

  /// Whether the platform's gift messages fly over the picture beside the
  /// chat (A08.12; off keeps the surface chat-only).
  final bool barrageShowGifts;

  /// Whether the platform's gifts show as lines in the chat list (the
  /// reference's `showChatGifts`); the flying gifts keep their own switch.
  final bool chatShowGifts;

  /// Whether the chat list hides the free and cheap gifts (the reference's
  /// 只显示值钱的礼物): a gift line needs its value to reach the valuable tier.
  final bool chatValuableGiftsOnly;

  /// Whether a gift line writes its value in yuan (the reference's
  /// 礼物价值换算成元) instead of the platform's own currency.
  final bool chatGiftValueYuan;

  /// Whether memberships (a Bilibili guard, a YouTube membership, a
  /// subscription) also get a card among the super chats; the chat list keeps
  /// its own line either way.
  final bool superChatIncludesMembership;

  /// Whether YouTube's chat reads the "Live chat" view (every message)
  /// instead of the default "Top chat".
  final bool youtubeAllChat;

  /// Whether tapping a flying line opens its sender's card (画面弹幕交互).
  final bool barrageTapAction;

  /// Whether long-pressing a flying line offers to block its sender.
  final bool barrageLongPressAction;

  /// The danmaku font family registered from the font library; '' is the
  /// system default.
  final String barrageFontFamily;

  /// Whether pressing the picture holds the lines under the finger
  /// (`holdDanmakuOnPress`).
  final bool barrageHoldOnPress;

  /// The chat list's text size (`danmakuListFontSize`).
  final double barrageListFontSize;

  /// The chat list's line spacing (`danmakuListLineSpacing`).
  final double barrageListLineSpacing;

  /// The chat list's look: `compact` rows or `card` bubbles
  /// (`danmakuListStyle`).
  final String barrageListStyle;

  /// The viewer's own saved barrage look, a `key=value;` string; empty when
  /// nothing was saved yet (`savedDanmakuTemplate`).
  final String barrageTemplate;

  /// The domain's keys as stored, flat.
  Map<String, Object?> toJson() => {
    'danmakuVisible': danmakuVisible,
    'barrageFontSize': barrageFontSize,
    'barrageOpacity': barrageOpacity,
    'barrageArea': barrageArea,
    'barrageTopArea': barrageTopArea,
    'barrageBottomArea': barrageBottomArea,
    'barrageSpeed': barrageSpeed,
    'barrageFontWeight': barrageFontWeight,
    'barrageStroke': barrageStroke,
    'barrageStrokeWidth': barrageStrokeWidth,
    'barrageShowSender': barrageShowSender,
    'barrageMaxVisible': barrageMaxVisible,
    'barrageFps': barrageFps,
    'barrageNoEmoji': barrageNoEmoji,
    'barrageCollapse': barrageCollapse,
    'barrageCollapseWindow': barrageCollapseWindow,
    'barragePausedBehavior': barragePausedBehavior,
    'barrageAutoFps': barrageAutoFps,
    'barrageFpsMode': barrageFpsMode,
    'barrageShowGifts': barrageShowGifts,
    'chatShowGifts': chatShowGifts,
    'chatValuableGiftsOnly': chatValuableGiftsOnly,
    'chatGiftValueYuan': chatGiftValueYuan,
    'superChatIncludesMembership': superChatIncludesMembership,
    'youtubeAllChat': youtubeAllChat,
    'barrageTapAction': barrageTapAction,
    'barrageLongPressAction': barrageLongPressAction,
    'barrageFontFamily': barrageFontFamily,
    'barrageHoldOnPress': barrageHoldOnPress,
    'barrageListFontSize': barrageListFontSize,
    'barrageListLineSpacing': barrageListLineSpacing,
    'barrageListStyle': barrageListStyle,
    'barrageTemplate': barrageTemplate,
  };

  /// Returns a copy with the given fields replaced.
  DanmakuPreferences copyWith({
    bool? danmakuVisible,
    double? barrageFontSize,
    double? barrageOpacity,
    double? barrageArea,
    double? barrageTopArea,
    double? barrageBottomArea,
    double? barrageSpeed,
    int? barrageFontWeight,
    bool? barrageStroke,
    double? barrageStrokeWidth,
    bool? barrageShowSender,
    int? barrageMaxVisible,
    int? barrageFps,
    bool? barrageNoEmoji,
    bool? barrageCollapse,
    int? barrageCollapseWindow,
    String? barragePausedBehavior,
    bool? barrageAutoFps,
    String? barrageFpsMode,
    bool? barrageShowGifts,
    bool? chatShowGifts,
    bool? chatValuableGiftsOnly,
    bool? chatGiftValueYuan,
    bool? superChatIncludesMembership,
    bool? youtubeAllChat,
    bool? barrageTapAction,
    bool? barrageLongPressAction,
    String? barrageFontFamily,
    bool? barrageHoldOnPress,
    double? barrageListFontSize,
    double? barrageListLineSpacing,
    String? barrageListStyle,
    String? barrageTemplate,
  }) => DanmakuPreferences(
    danmakuVisible: danmakuVisible ?? this.danmakuVisible,
    barrageFontSize: barrageFontSize ?? this.barrageFontSize,
    barrageOpacity: barrageOpacity ?? this.barrageOpacity,
    barrageArea: barrageArea ?? this.barrageArea,
    barrageTopArea: barrageTopArea ?? this.barrageTopArea,
    barrageBottomArea: barrageBottomArea ?? this.barrageBottomArea,
    barrageSpeed: barrageSpeed ?? this.barrageSpeed,
    barrageFontWeight: barrageFontWeight ?? this.barrageFontWeight,
    barrageStroke: barrageStroke ?? this.barrageStroke,
    barrageStrokeWidth: barrageStrokeWidth ?? this.barrageStrokeWidth,
    barrageShowSender: barrageShowSender ?? this.barrageShowSender,
    barrageMaxVisible: barrageMaxVisible ?? this.barrageMaxVisible,
    barrageFps: barrageFps ?? this.barrageFps,
    barrageNoEmoji: barrageNoEmoji ?? this.barrageNoEmoji,
    barrageCollapse: barrageCollapse ?? this.barrageCollapse,
    barrageCollapseWindow: barrageCollapseWindow ?? this.barrageCollapseWindow,
    barragePausedBehavior: barragePausedBehavior ?? this.barragePausedBehavior,
    barrageAutoFps: barrageAutoFps ?? this.barrageAutoFps,
    barrageFpsMode: barrageFpsMode ?? this.barrageFpsMode,
    barrageShowGifts: barrageShowGifts ?? this.barrageShowGifts,
    chatShowGifts: chatShowGifts ?? this.chatShowGifts,
    chatValuableGiftsOnly: chatValuableGiftsOnly ?? this.chatValuableGiftsOnly,
    chatGiftValueYuan: chatGiftValueYuan ?? this.chatGiftValueYuan,
    superChatIncludesMembership: superChatIncludesMembership ?? this.superChatIncludesMembership,
    youtubeAllChat: youtubeAllChat ?? this.youtubeAllChat,
    barrageTapAction: barrageTapAction ?? this.barrageTapAction,
    barrageLongPressAction: barrageLongPressAction ?? this.barrageLongPressAction,
    barrageFontFamily: barrageFontFamily ?? this.barrageFontFamily,
    barrageHoldOnPress: barrageHoldOnPress ?? this.barrageHoldOnPress,
    barrageListFontSize: barrageListFontSize ?? this.barrageListFontSize,
    barrageListLineSpacing: barrageListLineSpacing ?? this.barrageListLineSpacing,
    barrageListStyle: barrageListStyle ?? this.barrageListStyle,
    barrageTemplate: barrageTemplate ?? this.barrageTemplate,
  );

  @override
  /// Every field, in declaration order.
  List<Object?> get props => [
    danmakuVisible,
    barrageFontSize,
    barrageOpacity,
    barrageArea,
    barrageTopArea,
    barrageBottomArea,
    barrageSpeed,
    barrageFontWeight,
    barrageStroke,
    barrageStrokeWidth,
    barrageShowSender,
    barrageMaxVisible,
    barrageFps,
    barrageNoEmoji,
    barrageCollapse,
    barrageCollapseWindow,
    barragePausedBehavior,
    barrageAutoFps,
    barrageFpsMode,
    barrageShowGifts,
    chatShowGifts,
    chatValuableGiftsOnly,
    chatGiftValueYuan,
    superChatIncludesMembership,
    youtubeAllChat,
    barrageTapAction,
    barrageLongPressAction,
    barrageFontFamily,
    barrageHoldOnPress,
    barrageListFontSize,
    barrageListLineSpacing,
    barrageListStyle,
    barrageTemplate,
  ];
}
