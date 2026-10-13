import 'dart:async';

import 'package:live_shell/src/instance/launch_intent.dart';

/// Which of the two processes a launch turned out to be.
enum InstanceRole {
  /// Nothing has been decided yet: [InstanceChannel.acquire] has not run.
  ///
  /// Present as a state rather than a nullable role because the difference
  /// between "not the primary" and "not yet asked" matters: a handler that runs
  /// before the lock is taken must not assume it is safe to write files, and
  /// must not assume it is forbidden either.
  none,

  /// This process holds the lock and is the app.
  primary,

  /// Another instance already holds it; this one forwarded its request and must
  /// now exit, without touching files, the tray, or a window.
  forwarded,
}

/// The single-instance handoff, with the request carried across.
///
/// Claiming the URL scheme and the file types is a separate concern, on
/// [ProtocolRegistration]: that work happens once at install or first run and
/// writes into the user's shell, while this is a socket handshake on every
/// launch. Keeping them apart is what lets a build register handlers without
/// pretending it owns the lock.
///
/// Two failure modes this shape is built to avoid:
///
/// * **The request is thrown away.** A lock whose "someone else started" branch
///   only raises the window loses every deep link, shared room, and file
///   double-click. The `forwarded` stream is therefore the point of the
///   interface, not an extra.
/// * **The losing process acts like the app.** Exiting is asynchronous, and
///   handlers registered during start-up have already run, so a listener
///   installed before the lock is known good will fire in the dying process
///   too: writing settings, opening the tray icon, or stealing the recording
///   directory mid-cleanup. Every side-effecting handler therefore has to ask
///   [role] first, which is why the role is a property of the channel rather
///   than a value passed around from `main`.
abstract interface class InstanceChannel {
  /// Takes the lock, or hands [arguments] to whoever holds it.
  ///
  /// Called before the storage paths are finalised and before anything is
  /// registered: portable and installed builds pick different data
  /// directories, and a lock taken while the other build still holds it is a
  /// different app instance fighting over the same files.
  Future<InstanceRole> acquire({required List<String> arguments});

  /// Which role this process ended up with.
  InstanceRole get role;

  /// Requests the already-running instance received.
  ///
  /// Completed requests are delivered even if they arrive before anyone
  /// subscribes: the second instance can start a fraction after the primary's
  /// window is ready but long before the settings screen exists, and a dropped
  /// intent here is a silently ignored click.
  Stream<LaunchIntent> get forwarded;

  /// Publishes a request into the running instance from inside it — the path a
  /// "open in a new window" menu item or a protocol handler takes.
  Future<void> publish(LaunchIntent intent);
}
