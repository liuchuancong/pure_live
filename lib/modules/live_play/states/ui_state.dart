import 'package:flutter/foundation.dart';

enum VideoMode { normal, widescreen, fullscreen }

bool requiresSystemFullscreenExit(VideoMode mode) {
  return mode == VideoMode.fullscreen;
}

@immutable
class UIState {
  final VideoMode screenMode;
  final int refreshKey;
  final bool isMenuOpen;
  final int closeTimes;
  final bool closeTimeFlag;
  final bool displayVideoLayer;
  const UIState({
    this.screenMode = VideoMode.normal,
    this.refreshKey = 0,
    this.isMenuOpen = false,
    this.closeTimes = 240,
    this.closeTimeFlag = false,
    this.displayVideoLayer = true,
  });
  UIState copyWith({
    VideoMode? screenMode,
    int? refreshKey,
    bool? isMenuOpen,
    int? closeTimes,
    bool? closeTimeFlag,
    bool? displayVideoLayer,
  }) {
    return UIState(
      screenMode: screenMode ?? this.screenMode,
      refreshKey: refreshKey ?? this.refreshKey,
      isMenuOpen: isMenuOpen ?? this.isMenuOpen,
      closeTimes: closeTimes ?? this.closeTimes,
      closeTimeFlag: closeTimeFlag ?? this.closeTimeFlag,
      displayVideoLayer: displayVideoLayer ?? this.displayVideoLayer,
    );
  }

  @override
  String toString() {
    return 'UIState(\n'
        '  screenMode: $screenMode,\n'
        '  refreshKey: $refreshKey,\n'
        '  isMenuOpen: $isMenuOpen,\n'
        '  closeTimes: $closeTimes,\n'
        '  closeTimeFlag: $closeTimeFlag,\n'
        'displayVideoLayer: $displayVideoLayer,\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIState &&
        other.screenMode == screenMode &&
        other.refreshKey == refreshKey &&
        other.isMenuOpen == isMenuOpen &&
        other.closeTimes == closeTimes &&
        other.closeTimeFlag == closeTimeFlag &&
        other.displayVideoLayer == displayVideoLayer;
  }

  @override
  int get hashCode =>
      Object.hash(screenMode, refreshKey, isMenuOpen, closeTimes, closeTimeFlag, displayVideoLayer);
}
