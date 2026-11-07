/// Binds a page's playback to the LAN remote: a snapshot the phone shows and
/// a fixed set of commands the page can honestly serve. Callbacks must read
/// the current controller, rather than capturing one which may have been
/// replaced by a room switch.
library;

import 'dart:convert';
import 'dart:math';

/// Releases an interruption owned by one still-registered playback page.
typedef PlaybackResume = Future<void> Function();

String _nonce() => base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256))).replaceAll('=', '');

/// A page-owned playback target.
final class RemotePlaybackTarget {
  /// Registers a snapshot and a fixed set of commands.
  RemotePlaybackTarget({
    required this.available,
    required this.snapshot,
    required this.execute,
    this.identity,
    this.scope,
  }) : _id = _nonce();

  /// Identifies this page instance; a command for a removed page cannot spill
  /// over to the next page that happens to use the same route.
  final String _id;

  /// Optional dynamic identity of the current control scope.
  final String Function()? identity;

  /// Identity of the current control scope.
  String get id => identity?.call() ?? _id;

  /// Page-specific content identity, independent of the unique page nonce.
  final String Function()? scope;

  /// Whether this page can currently receive remote input.
  final bool Function() available;

  /// Public display fields only, never a platform response or cookie.
  final Map<String, Object?> Function() snapshot;

  /// Runs one advertised command, returning false when it cannot apply.
  final Future<bool> Function(String command, double? value) execute;
}
