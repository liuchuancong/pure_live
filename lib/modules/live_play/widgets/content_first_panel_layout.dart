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
  final horizontalInset = compactViewport ? 10.0 : 20.0;
  final verticalInset = compactViewport ? 10.0 : 20.0;
  final availableWidth = (viewport.width - horizontalInset * 2).clamp(280.0, double.infinity).toDouble();
  final availableHeight = (viewport.height - verticalInset * 2).clamp(240.0, double.infinity).toDouble();

  final (widthFactor, heightFactor, maxHeight, splitThreshold) = switch (kind) {
    // Half of the available width plus center-right alignment makes the left
    // edge land exactly on the viewport midpoint, independent of phone size.
    ContentFirstPanelKind.roomHistory => (0.5, 1.0, 720.0, 420.0),
    ContentFirstPanelKind.streamSelector => (0.5, 1.0, 620.0, 620.0),
    ContentFirstPanelKind.localDanmakuStyle => (0.48, 0.86, 680.0, 680.0),
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
