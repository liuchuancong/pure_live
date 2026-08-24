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
int resolveStreamChoiceColumns(double paneWidth, {int? itemCount}) {
  final availableColumns = switch (paneWidth) {
    >= 340 => 3,
    >= 210 => 2,
    _ => 1,
  };
  if (itemCount == null) return availableColumns;
  if (itemCount <= 1) return 1;
  // Four quality choices look unbalanced as 3 + 1. A 2 x 2 arrangement uses
  // the same two rows while leaving substantially more room for long labels.
  if (itemCount == 4 && availableColumns == 3) return 2;
  return math.min(availableColumns, itemCount);
}

@immutable
class StreamSelectorStackLayout {
  const StreamSelectorStackLayout({required this.qualityHeight, required this.lineHeight, required this.gap});

  final double qualityHeight;
  final double lineHeight;
  final double gap;
}

/// Allocates a compact, content-sized quality section above a flexible line
/// section on a landscape phone.
///
/// The former fixed 4:3 flex split left most of the quality card empty when a
/// platform exposed only four qualities, while a longer CDN list was clipped.
/// This calculation measures the actual number of quality rows, caps it at
/// three visible rows, and reserves a useful minimum for playback lines.
StreamSelectorStackLayout resolveStreamSelectorStackLayout({
  required Size contentSize,
  required int qualityCount,
  double gap = 5,
}) {
  const paneHorizontalPadding = 12.0;
  const paneChromeHeight = 36.0; // vertical padding + title + divider
  const itemHeight = 34.0;
  const itemSpacing = 4.0;

  final gridWidth = math.max(0.0, contentSize.width - paneHorizontalPadding);
  final columns = resolveStreamChoiceColumns(gridWidth, itemCount: qualityCount);
  final rowCount = math.max(1, (qualityCount / columns).ceil());
  final visibleRows = math.min(3, rowCount);
  final desiredQualityHeight = paneChromeHeight + visibleRows * itemHeight + math.max(0, visibleRows - 1) * itemSpacing;

  final minimumLineHeight = math.min(112.0, math.max(84.0, contentSize.height * .36));
  final maximumQualityHeight = math.max(70.0, contentSize.height - gap - minimumLineHeight);
  final qualityHeight = math.min(desiredQualityHeight, maximumQualityHeight).clamp(70.0, 146.0).toDouble();
  final lineHeight = math.max(0.0, contentSize.height - gap - qualityHeight);
  return StreamSelectorStackLayout(qualityHeight: qualityHeight, lineHeight: lineHeight, gap: gap);
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
