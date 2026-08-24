import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum ContentFirstPanelKind { roomHistory, streamSelector, localDanmakuStyle }

/// Shared sizing policy for landscape playback overlays.
///
/// These panels are opened while video is already occupying a short landscape
/// viewport. Keeping small fixed dialogs here leaves only a few rows for the
/// actual room, stream or style content, so each panel deliberately consumes
/// most of the safe viewport and caps itself only on large desktop windows.
@immutable
class ContentFirstPanelLayout {
  const ContentFirstPanelLayout({required this.size, required this.insetPadding, required this.splitContent});

  final Size size;
  final EdgeInsets insetPadding;
  final bool splitContent;
}

ContentFirstPanelLayout resolveContentFirstPanelLayout(Size viewport, ContentFirstPanelKind kind) {
  final compactViewport = viewport.width < 720 || viewport.height < 520;
  final horizontalInset = compactViewport ? 8.0 : 20.0;
  final verticalInset = compactViewport ? 8.0 : 20.0;
  final availableWidth = (viewport.width - horizontalInset * 2).clamp(280.0, double.infinity).toDouble();
  final availableHeight = (viewport.height - verticalInset * 2).clamp(240.0, double.infinity).toDouble();

  final (widthFactor, heightFactor, maxHeight, splitThreshold) = switch (kind) {
    // Half of the available width plus center-right alignment makes the left
    // edge land exactly on the viewport midpoint, independent of phone size.
    ContentFirstPanelKind.roomHistory => (0.5, 1.0, 720.0, 420.0),
    ContentFirstPanelKind.streamSelector => (0.5, 1.0, 620.0, 620.0),
    // The local-style panel intentionally splits on a landscape phone too:
    // preview stays visible on the left while the controls scroll on the
    // right. A 340 px half-panel still leaves both columns usable.
    ContentFirstPanelKind.localDanmakuStyle => (0.5, 1.0, 680.0, 340.0),
  };

  final targetWidth = (availableWidth * widthFactor).clamp(280.0, double.infinity).toDouble();
  final width = targetWidth.clamp(280.0, availableWidth).toDouble();
  final targetHeight = (viewport.height * heightFactor).clamp(240.0, maxHeight).toDouble();
  final height = targetHeight.clamp(240.0, availableHeight).toDouble();
  return ContentFirstPanelLayout(
    size: Size(width, height),
    insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset, vertical: verticalInset),
    splitContent: viewport.width > viewport.height && width >= splitThreshold,
  );
}

/// Number of compact choice columns that fit inside a stream selector pane.
///
/// Three columns let common quality sets (for example 蓝光/超清/高清) and CDN
/// lines remain visible without turning the right-half panel into a tall list.
int resolveStreamChoiceColumns(double paneWidth) {
  if (paneWidth >= 340) return 3;
  if (paneWidth >= 210) return 2;
  return 1;
}

/// Keeps two rows of two room cards inside the visible history viewport.
///
/// Cards retain a natural 16:9 cover whenever space permits, then give a small
/// amount of cover height back before allowing the fourth card to be clipped.
double resolveRoomHistoryCardHeight({
  required Size contentSize,
  required int columns,
  double padding = 6,
  double spacing = 5,
  double footerHeight = 36,
}) {
  final usableWidth = math.max(0.0, contentSize.width - padding * 2 - spacing * (columns - 1));
  final cardWidth = usableWidth / math.max(1, columns);
  final naturalHeight = cardWidth * 9 / 16 + footerHeight;
  if (columns < 2) return naturalHeight.clamp(118.0, 310.0).toDouble();

  final twoRowHeight = (contentSize.height - padding * 2 - spacing) / 2;
  final minimumHeight = math.min(112.0, naturalHeight);
  return math.max(minimumHeight, math.min(naturalHeight, twoRowHeight)).clamp(96.0, 310.0).toDouble();
}
