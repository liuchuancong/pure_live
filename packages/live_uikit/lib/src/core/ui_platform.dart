import 'package:flutter/foundation.dart';

/// The platform the UI runs on.
///
/// Separate from the design language on purpose: this axis answers *where*
/// the app runs and drives platform capability decisions (safe areas,
/// window controls, input defaults), while the design language answers
/// *how* it looks.
enum LiveUiPlatform {
  /// Android phones and tablets.
  android,

  /// iPhone and iPad.
  ios,

  /// Android TV and other Android remote-control builds.
  androidTv,

  /// Windows desktop.
  windows,

  /// macOS.
  macos,

  /// Linux desktop.
  linux,

  /// Flutter web.
  web;

  /// Whether the platform is a remote-control TV build.
  bool get isTv => this == LiveUiPlatform.androidTv;

  /// Whether the platform is a desktop one (mouse and keyboard first).
  bool get isDesktop => this == LiveUiPlatform.windows || this == LiveUiPlatform.macos || this == LiveUiPlatform.linux;

  /// Whether the platform is a touch-first mobile one.
  bool get isMobile => this == LiveUiPlatform.android || this == LiveUiPlatform.ios;

  /// Resolves the platform from Flutter's [TargetPlatform] and [isWeb].
  ///
  /// [isTvBuild] is never guessed: a TV build is declared by the
  /// composition root (it reads the form factor from `live_platform`),
  /// because Flutter itself cannot distinguish Android TV from Android —
  /// and a phone misdetected as a TV would open a remote-control UI nobody
  /// can operate.
  static LiveUiPlatform resolve({TargetPlatform? targetPlatform, bool isWeb = kIsWeb, bool isTvBuild = false}) {
    if (isWeb) {
      return LiveUiPlatform.web;
    }
    final target = targetPlatform ?? defaultTargetPlatform;
    return switch (target) {
      TargetPlatform.android => isTvBuild ? LiveUiPlatform.androidTv : LiveUiPlatform.android,
      TargetPlatform.iOS => LiveUiPlatform.ios,
      TargetPlatform.windows => LiveUiPlatform.windows,
      TargetPlatform.macOS => LiveUiPlatform.macos,
      TargetPlatform.linux => LiveUiPlatform.linux,
      TargetPlatform.fuchsia => LiveUiPlatform.android,
    };
  }
}
