import 'dart:io';

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:pure_live/app/routing/deep_link.dart' show RoomDeepLink;

/// The desktop single-instance handoff, taken before anything writes.
///
/// A second launch that went straight at the data tree would fight the
/// running instance over its Hive box locks and crash both — the lock is
/// therefore the first thing a desktop launch takes, before the layout is
/// resolved. What the second launch was asking for rides inside the
/// handshake (the forwarded stream carries it) and opens in the instance
/// that is already running; handlers for it join with the room and deep-
/// link waves.
///
/// Returns the acquired channel, or null when this process must exit: on a
/// non-desktop platform there is no instance logic, and a forwarded launch
/// has already handed its request over and must touch nothing on its way
/// out. The concrete channel type comes back because only it owns
/// [SocketInstanceChannel.dispose] — the nonce file must be removed by the
/// process that wrote it.
Future<SocketInstanceChannel?> acquireDesktopInstance({required LiveLog log, required List<String> args}) async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return null;
  }
  final profile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final channel = SocketInstanceChannel(
    appId: 'live.pure.desktop',
    nonceFile: File('$profile/.pure_instance_nonce'),
  );
  final launchLog = log.forCategory('launch');
  // A protocol-handler start carries the raw URI on the command line
  // (`purelive://room?site=...`, what the registry command launches); the
  // handshake only carries encoded intents, so raw URIs are folded into one
  // first. Both directions gain: this process, when it is the primary,
  // delivers its own link; when the instance already runs, the forwarded
  // request keeps the room instead of degrading to "show the window".
  final role = await channel.acquire(arguments: canonicalizeLaunchArguments(args));
  if (role == InstanceRole.forwarded) {
    launchLog.info('handed over to the running instance; exiting');
    return null;
  }
  launchLog.info('primary instance', fields: {'port': channel.listeningPort});
  return channel;
}

/// Folds every raw `purelive:` URI on a command line into the encoded
/// launch intent the single-instance handshake carries.
///
/// The Windows registry value this app writes (`"<exe>" "%1"`) and the Linux
/// desktop entry both hand the link over as a bare argument, which
/// [LaunchIntent.fromArguments] cannot read on its own. An argument that
/// fails to parse as a URI is left alone — the ordinary start path decides
/// what it was — and an argument list without any URI comes back unchanged.
List<String> canonicalizeLaunchArguments(List<String> args) {
  var changed = false;
  final canonical = <String>[];
  for (final arg in args) {
    final trimmed = arg.trim();
    final uri = trimmed.startsWith('${RoomDeepLink.scheme}:') ? Uri.tryParse(trimmed) : null;
    if (uri == null) {
      canonical.add(arg);
      continue;
    }
    canonical.add(OpenRoomLink(uri).toArguments().first);
    changed = true;
  }
  return changed ? canonical : args;
}

/// Claims the `purelive` scheme for this build, best effort.
///
/// Windows writes the per-user classes under `HKCU` (`reg`, no elevation)
/// and Linux a desktop entry claiming `x-scheme-handler/purelive`; macOS
/// declares schemes in the bundle and reports that it cannot register here.
/// Failure is logged, never fatal — the deep link then simply stays
/// unregistered until the machine's handler changes.
Future<void> registerDesktopSchemes({required PlatformKind kind, required LiveLog log}) async {
  final registration = CommandProtocolRegistration(
    platform: kind,
    executablePath: Platform.resolvedExecutable,
    progIdPrefix: 'pure_live',
    displayName: 'Pure Live',
    run: Process.run,
  );
  if (!registration.supportsRuntimeRegistration) {
    return;
  }
  try {
    final ok = await registration.registerScheme(RoomDeepLink.scheme);
    final launchLog = log.forCategory('launch');
    if (ok) {
      launchLog.info('purelive scheme registered');
    } else {
      launchLog.warning('purelive scheme registration failed');
    }
  } on Object catch (error) {
    log.forCategory('launch').warning('purelive scheme registration failed', fields: {'error': '$error'});
  }
}
