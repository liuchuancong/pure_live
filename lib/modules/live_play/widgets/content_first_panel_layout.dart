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
  const ContentFirstPanelLayout({
    required this.size,
    required this.insetPadding,
    required this.splitContent,
  });

  final Size size;
  final EdgeInsets insetPadding;
  final bool splitContent;
}

ContentFirstPanelLayout resolveContentFirstPanelLayout(Size viewport, ContentFirstPanelKind kind) {
  final compactViewport = viewport.width < 720 || viewport.height < 520;
  final horizontalInset = compactViewport ? 8.0 : 20.0;
  final verticalInset = compactViewport ? 8.0 : 20.0;
  final availableWidth = (viewport.width - horizontalInset * 2)
      .clamp(280.0, double.infinity)
      .toDouble();
  final availableHeight = (viewport.height - verticalInset * 2)
      .clamp(240.0, double.infinity)
      .toDouble();

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
class StreamSelectorPanelLayout {
  const StreamSelectorPanelLayout({
    required this.dialogHeight,
    required this.qualityHeight,
    required this.lineHeight,
    required this.gap,
    required this.splitContent,
  });

  final double dialogHeight;
  final double qualityHeight;
  final double lineHeight;
  final double gap;
  final bool splitContent;
}

/// Sizes the complete stream selector from the number of visible choices.
///
/// A short quality/line list produces a short dialog instead of two mostly
/// empty cards. If either list exceeds the viewport, both panes retain a useful
/// minimum and only their button grids scroll.
StreamSelectorPanelLayout resolveStreamSelectorPanelLayout({
  required Size maximumDialogSize,
  required int qualityCount,
  required int lineCount,
  required bool splitContent,
  double gap = 5,
}) {
  const dialogChromeHeight = 36.0; // compact title row + divider
  const bodyPadding = 6.0;
  const minimumPaneHeight = 78.0;

  final innerWidth = math.max(0.0, maximumDialogSize.width - bodyPadding * 2);
  final paneWidth = splitContent ? math.max(0.0, (innerWidth - gap) / 2) : innerWidth;
  final desiredQuality = _streamChoicePaneHeight(paneWidth, qualityCount);
  final desiredLine = _streamChoicePaneHeight(paneWidth, lineCount);
  final maximumBodyHeight = math.max(
    0.0,
    maximumDialogSize.height - dialogChromeHeight - bodyPadding * 2,
  );

  if (splitContent) {
    final paneHeight = math.min(math.max(desiredQuality, desiredLine), maximumBodyHeight);
    final dialogHeight = (dialogChromeHeight + bodyPadding * 2 + paneHeight)
        .clamp(124.0, maximumDialogSize.height)
        .toDouble();
    return StreamSelectorPanelLayout(
      dialogHeight: dialogHeight,
      qualityHeight: paneHeight,
      lineHeight: paneHeight,
      gap: gap,
      splitContent: true,
    );
  }

  final desiredPanesHeight = desiredQuality + gap + desiredLine;
  if (desiredPanesHeight <= maximumBodyHeight) {
    return StreamSelectorPanelLayout(
      dialogHeight: dialogChromeHeight + bodyPadding * 2 + desiredPanesHeight,
      qualityHeight: desiredQuality,
      lineHeight: desiredLine,
      gap: gap,
      splitContent: false,
    );
  }

  final availableForPanes = math.max(minimumPaneHeight * 2, maximumBodyHeight - gap);
  final extraSpace = math.max(0.0, availableForPanes - minimumPaneHeight * 2);
  final desiredExtra = math.max(1.0, desiredQuality + desiredLine - minimumPaneHeight * 2);
  final qualityExtraShare = math.max(0.0, desiredQuality - minimumPaneHeight) / desiredExtra;
  final qualityHeight = minimumPaneHeight + extraSpace * qualityExtraShare;
  final lineHeight = availableForPanes - qualityHeight;
  return StreamSelectorPanelLayout(
    dialogHeight: maximumDialogSize.height,
    qualityHeight: qualityHeight,
    lineHeight: lineHeight,
    gap: gap,
    splitContent: false,
  );
}

double _streamChoicePaneHeight(double paneWidth, int itemCount) {
  // 4 top padding + 23 header + 4 divider + 6 bottom padding.
  const paneChromeHeight = 37.0;
  const itemHeight = 42.0;
  const itemSpacing = 5.0;
  if (itemCount <= 0) return 78;
  final gridWidth = math.max(0.0, paneWidth - 12);
  final columns = resolveStreamChoiceColumns(gridWidth, itemCount: itemCount);
  final rows = math.max(1, (itemCount / columns).ceil());
  return paneChromeHeight + rows * itemHeight + math.max(0, rows - 1) * itemSpacing;
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
  return math
      .max(minimumHeight, math.min(naturalHeight, twoRowHeight))
      .clamp(96.0, 310.0)
      .toDouble();
}

/// Selects the room-history grid from the actual panel content width instead
/// of a desktop-oriented breakpoint.
///
/// The landscape dialog deliberately occupies the right half of a phone. Two
/// compact 168 px cards fit comfortably in the common 360–430 logical-pixel
/// pane; genuinely narrow panes retain one readable column.
int resolveRoomHistoryColumns(
  double contentWidth, {
  double padding = 6,
  double spacing = 5,
  double minimumCardWidth = 168,
}) {
  if (!contentWidth.isFinite || contentWidth <= 0) return 1;
  final usableWidth = math.max(0.0, contentWidth - padding * 2);
  final twoColumnMinimum = minimumCardWidth * 2 + spacing;
  return usableWidth >= twoColumnMinimum ? 2 : 1;
}
