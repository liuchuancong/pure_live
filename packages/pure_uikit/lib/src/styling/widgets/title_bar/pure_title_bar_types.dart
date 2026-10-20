import 'package:flutter/foundation.dart';

/// Defines the dimensions used by a title bar presentation.
///
/// Each presentation can provide its own defaults while callers can override
/// individual dimensions when necessary.
@immutable
class PureCaptionMetrics {
  /// Creates a set of title bar dimensions.
  const new({required this.titleBarHeight, required this.buttonWidth, required this.buttonHeight});

  /// Creates dimensions for compact desktop caption controls.
  ///
  /// These values are intended for token-based title bars.
  const new desktop() : titleBarHeight = 32, buttonWidth = 46, buttonHeight = 32;

  /// Creates dimensions for macOS traffic-light controls.
  ///
  /// [buttonWidth] and [buttonHeight] represent the visible dot size,
  /// not the full pointer hit target.
  const new macos() : titleBarHeight = 28, buttonWidth = 12, buttonHeight = 12;

  /// The total height of the title bar.
  final double titleBarHeight;

  /// The width of an individual caption control.
  final double buttonWidth;

  /// The height of an individual caption control.
  final double buttonHeight;

  /// Returns a copy with the provided dimensions replaced.
  PureCaptionMetrics copyWith({double? titleBarHeight, double? buttonWidth, double? buttonHeight}) {
    return PureCaptionMetrics(
      titleBarHeight: titleBarHeight ?? this.titleBarHeight,
      buttonWidth: buttonWidth ?? this.buttonWidth,
      buttonHeight: buttonHeight ?? this.buttonHeight,
    );
  }
}

/// Contains localized strings displayed by a title bar.
///
/// Pass translated values from the application localization layer rather than
/// hard-coding user-facing strings in presentation widgets.
@immutable
class PureTitleBarLabels {
  /// Creates the labels displayed by a title bar.
  const new({
    required this.title,
    this.minimize = 'Minimize',
    this.maximize = 'Maximize',
    this.restore = 'Restore',
    this.close = 'Close',
  });

  /// The application or window title.
  final String title;

  /// Tooltip for the minimize action.
  final String minimize;

  /// Tooltip for the maximize action.
  final String maximize;

  /// Tooltip for the restore action.
  final String restore;

  /// Tooltip for the close action.
  final String close;

  /// Returns a copy with the provided labels replaced.
  PureTitleBarLabels copyWith({String? title, String? minimize, String? maximize, String? restore, String? close}) {
    return PureTitleBarLabels(
      title: title ?? this.title,
      minimize: minimize ?? this.minimize,
      maximize: maximize ?? this.maximize,
      restore: restore ?? this.restore,
      close: close ?? this.close,
    );
  }
}
