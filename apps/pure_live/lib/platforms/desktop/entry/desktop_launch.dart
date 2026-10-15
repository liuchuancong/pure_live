import 'dart:io';

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_shell/live_shell.dart';

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
    nonceFile: File('$profile/.pure_live_instance_nonce'),
  );
  final launchLog = log.forCategory('launch');
  final role = await channel.acquire(arguments: args);
  if (role == InstanceRole.forwarded) {
    launchLog.info('handed over to the running instance; exiting');
    return null;
  }
  launchLog.info('primary instance', fields: {'port': channel.listeningPort});
  return channel;
}
