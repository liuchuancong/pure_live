import 'dart:async';

import 'package:media_core/media_core.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/player/presentation/fullscreen_window.dart' show WindowService;
import 'package:pure_live/core/player/presentation/windows_pip_driver.dart';

/// Entering and leaving the two presentations that leave the page behind:
/// picture-in-picture and fullscreen.
///
/// Both are driver work, and both were driven from the live room only. A
/// recording player needs exactly the same two transitions, and a second
/// implementation would be a second set of platform quirks — the mobile PiP
/// implementation that has to be initialised before any request, the video size
/// the window is shaped from, the fullscreen restore bounds. So they live here,
/// once, and each player only supplies its own player id and video shape.
///
/// Responsibilities:
///
/// - initialise the PiP implementation and request the mode
/// - request/leave fullscreen through the kernel presentation chain
///
/// It does not:
///
/// - own the window or the driver (the kernel does)
/// - know which media is playing
/// - decide *whether* the viewer may enter (the calling page does)

/// Requests the system picture-in-picture window for [playerId].
///
/// [videoWidth] and [videoHeight] are what the small window is shaped from; a
/// platform that cannot report a size yet gets 16:9, which is the shape the
/// overwhelming majority of sources have. Neither may be zero: the mobile
/// implementation refuses to enter PiP at all without a positive size.
Future<void> enterSystemPip(
  PlayerKernel kernel, {
  required PlayerId playerId,
  int videoWidth = 0,
  int videoHeight = 0,
}) async {
  // The kernel chain forwards requests without lifecycle calls. The mobile path
  // only installs its system-pip implementation and starts observing the
  // platform status stream during initialize(); without it every pip request
  // throws "no system pip implementation" and the Android back gesture silently
  // falls back to leaving the page.
  await windowsPipDriver.initialize();
  final width = videoWidth > 0 ? videoWidth : 16;
  final height = videoHeight > 0 ? videoHeight : 9;
  windowsPipDriver.onVideoSize(width, height);
  final driver = kernel.presentationDriver;
  if (driver == null) {
    throw StateError('No presentation driver is attached; picture-in-picture is unavailable.');
  }
  await driver.apply(playerId, PresentationRequest.pip());
}

/// Leaves picture-in-picture and restores the window.
Future<void> exitSystemPip(PlayerKernel kernel, {required PlayerId playerId}) async {
  final driver = kernel.presentationDriver;
  if (driver == null) return;
  await driver.apply(playerId, PresentationRequest.normal());
}

/// Enters fullscreen through the kernel presentation chain.
///
/// The chain is the only owner of "the previous mode leaves first"
/// (`PresentationDriverChain._active`), so a player must not drive the
/// fullscreen driver directly: doing that left the chain's bookkeeping empty and
/// a later PiP request failed to release fullscreen, which cropped the picture
/// inside the small window.
Future<void> enterPlayerFullscreen() async {
  await WindowService().doEnterFullScreen();
}

/// Leaves fullscreen and restores the window.
Future<void> exitPlayerFullscreen() async {
  await WindowService().doExitFullScreen();
}

/// Whether [error] means "this platform has no working picture-in-picture".
///
/// Callers show the same message either way, so the only job here is to keep the
/// diagnostic out of the message and in the log.
bool isPipUnavailableError(Object error) {
  CoreLog.w('pip: request failed: $error');
  return true;
}
