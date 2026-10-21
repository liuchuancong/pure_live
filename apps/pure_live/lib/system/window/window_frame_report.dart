import 'dart:io' show Platform;

import 'package:live_shell_desktop/live_shell_desktop.dart' show kWindowsRoundedFrameBuild, windowsBuildNumber;
import 'package:window_frame_kit/window_frame_kit.dart';

/// What the window's frame actually is, as the operating system reports it
/// rather than as the chrome plan intended it.
///
/// The plan is a statement of who *should* own the caption; this is the answer
/// to who owns it now. The two are only equal if the plugin applied the option,
/// and a border complaint — no edge, a double line, one resize corner that does
/// not grab — is a question about the applied state, not the intended one.
///
/// The sweep numbers are the part that makes an argument out of it. A stretched
/// or stale frame during a drag is the failure mode of a self-drawn border, and
/// until the plugin counted them the only evidence was someone saying "it
/// flickered". `steps` resizes are issued natively, back to back, at all four
/// edges, and the count of compositions that showed a size-mismatched view is
/// what comes back.
final class WindowFrameReport {
  /// The state as read, with the sweep answers [withoutPreSync] and
  /// [withPreSync] when a sweep ran.
  const new({required this.takesFrameOver, required this.buildNumber, this.withoutPreSync, this.withPreSync});

  /// Whether the plugin's frame takeover is armed on the live window — the
  /// caption is gone and the edges answer the window's own hit-test.
  final bool takesFrameOver;

  /// The Windows build number, or 0 where there is no such number to read
  /// (another platform, or `RtlGetVersion` refused).
  final int buildNumber;

  /// The sweep run with the view pre-sync turned off, null when no sweep ran.
  final ResizeSyncStats? withoutPreSync;

  /// The same sweep with it on.
  final ResizeSyncStats? withPreSync;

  /// Whether this Windows composes a custom frame's own edge.
  ///
  /// Build 22000 is where the compositor began drawing the rounded corners and
  /// the one-pixel border, and the frame takeover asks for both. Below it a
  /// taken-over window has no line at all on any side — which is why the default
  /// title-bar mode is picked from this, and why the app stopped painting the
  /// edge itself once the takeover was the one drawing the frame.
  bool get systemDrawsEdge => buildNumber >= kWindowsRoundedFrameBuild;

  /// Whether a sweep is in here.
  bool get hasSweep => withPreSync != null;
}

/// Reads the live frame state, and runs the resize sweep when asked.
///
/// [runSweep] is opt-in because it is not a passive read: the window is resized
/// [steps] times per pass, twice, and put back where it was. Nothing else on the
/// settings screen moves the viewer's window, so the row that does says so before
/// it does it.
///
/// The sweep answers are null off Windows and while the takeover is off; the
/// state lines are still worth reading there, which is why the two are not one
/// call.
Future<WindowFrameReport> readWindowFrameReport({bool runSweep = false, int steps = 120}) async {
  final takesFrameOver = await windowManager.isCustomFrame();
  final buildNumber = Platform.isWindows ? windowsBuildNumber() : 0;
  if (!runSweep) {
    return WindowFrameReport(takesFrameOver: takesFrameOver, buildNumber: buildNumber);
  }
  // The second pass leaves `preSync` at the plugin's own default, which is the
  // behaviour the frame ships with; the first turns it off to show what it buys.
  final preSyncOff = await windowManager.debugResizeSweep(steps: steps, preSync: false);
  final preSyncOn = await windowManager.debugResizeSweep(steps: steps);
  return WindowFrameReport(
    takesFrameOver: takesFrameOver,
    buildNumber: buildNumber,
    withoutPreSync: preSyncOff,
    withPreSync: preSyncOn,
  );
}
