import 'dart:ui' show Color;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// Sets the desktop window up before the first frame: size, minimum size,
/// title and the native caption.
///
/// The chrome stage is [ChromeStage.nativeFirst] on purpose — the OS caption
/// keeps the snap layouts, the edge resize, `Win`+arrow keys, the shadow and
/// the per-monitor DPI that a self-drawn bar would have to buy back one bug
/// at a time (live_shell's own warning). A later stage remains a decision
/// the settings screen can offer, not an accident.
Future<void> setUpDesktopWindow({required PlatformKind kind, required String title}) => configureMainWindow(
  role: WindowRole.main,
  plan: ChromePlan.select(platform: kind, stage: ChromeStage.nativeFirst),
  fallbacks: const RenderFallbacks(),
  title: title,
  background: const Color(0xFF141414),
);
