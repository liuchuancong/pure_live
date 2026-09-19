import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';

/// Shared geometry for `RoomCard` and fixed-extent room grids.
///
/// Compact cards deliberately omit the 16:9 cover. Keeping their height in a
/// single helper prevents a grid delegate from reserving the old cover-card
/// extent and making the compact preset look ineffective.
abstract final class RoomCardLayoutMetrics {
  static double compactHeight({
    required RoomCardAppearance appearance,
    required bool dense,
    bool hasAction = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final verticalPadding = dense ? 8.0 : 10.0;
    final avatarHeight = appearance.showAvatar ? (dense ? 34.0 : 40.0) : 0.0;
    final minimumInteractiveContent = hasAction || !dense ? 48.0 : 40.0;
    final contentHeight = _textHeight(appearance: appearance, dense: dense, textScaler: textScaler);
    return math.max(minimumInteractiveContent, math.max(avatarHeight, contentHeight)) + verticalPadding * 2;
  }

  static double gridMainAxisExtent({
    required double itemWidth,
    required RoomCardAppearance appearance,
    required bool dense,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (appearance.layout == RoomCardLayout.compact) {
      return compactHeight(appearance: appearance, dense: dense, textScaler: textScaler);
    }

    final baseCaptionHeight = dense ? 72.0 : 84.0;
    final scaledCaptionHeight =
        _textHeight(appearance: appearance, dense: dense, textScaler: textScaler) + (dense ? 16.0 : 20.0);
    final captionHeight = math.max(baseCaptionHeight, scaledCaptionHeight);
    return math.max(0, itemWidth) * 9 / 16 + captionHeight;
  }

  static double _textHeight({
    required RoomCardAppearance appearance,
    required bool dense,
    required TextScaler textScaler,
  }) {
    final titleHeight = textScaler.scale(dense ? 13 : 15) * 1.2;
    if (!appearance.showAnchorName) return titleHeight;
    final subtitleHeight = textScaler.scale(dense ? 12 : 13) * 1.2;
    return titleHeight + (dense ? 2 : 3) + subtitleHeight;
  }
}
