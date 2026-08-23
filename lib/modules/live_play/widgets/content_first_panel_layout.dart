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

  final (widthFactor, maxWidth, maxHeight, splitThreshold) = switch (kind) {
    ContentFirstPanelKind.roomHistory => (0.96, 1080.0, 720.0, 620.0),
    ContentFirstPanelKind.streamSelector => (0.78, 760.0, 620.0, 580.0),
    ContentFirstPanelKind.localDanmakuStyle => (0.88, 960.0, 680.0, 640.0),
  };

  final targetWidth = (viewport.width * widthFactor).clamp(280.0, maxWidth).toDouble();
  final width = targetWidth.clamp(280.0, availableWidth).toDouble();
  final height = availableHeight.clamp(240.0, maxHeight).toDouble();
  return ContentFirstPanelLayout(
    size: Size(width, height),
    insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset, vertical: verticalInset),
    splitContent: viewport.width > viewport.height && width >= splitThreshold,
  );
}
