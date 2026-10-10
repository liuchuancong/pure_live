// Module: lib/src/domain/zap_channel.dart
// Purpose: One channel of an IPTV playlist, with the honesty about whether it can actually be opened.
// Author: liuchuancong
// Created: 2026-10-10
//
// An m3u playlist is user-supplied and routinely contains entries with no url at all - a group header that
// parsed as a channel, an entry whose stream line was cut off, a subscription the owner deleted. The previous
// model exposed `primaryUrl` as `urls.first`, which threw StateError on the first such entry, so the very
// first remote press on a real playlist could crash the surface rather than show a greyed-out row.

import 'package:pure_live_utils/pure_live_utils.dart';

/// One zappable channel.
final class ZapChannel with ValueEquality {
  const ZapChannel({
    required this.name,
    required this.group,
    required this.urls,
    this.headers = const <String, String>{},
    this.logo,
  });

  /// The channel name as the playlist spelled it. Not unique: the same name appears in several groups, and
  /// this package's playlists are exactly the input where that shows up.
  final String name;

  /// The playlist group the entry belongs to, '' when the file said none.
  final String group;

  /// The stream urls in declaration order, the source's own priority list. May legitimately be empty.
  final List<Uri> urls;

  /// Headers the stream requires (a referer and user-agent are both common in IPTV).
  ///
  /// Values here can carry credentials, so a channel is never printed with its headers: diagnostics go
  /// through [toString], which drops them (platform-models §16).
  final Map<String, String> headers;

  final String? logo;

  /// The url to open first, or null when the entry declares none.
  Uri? get primaryUrl => urls.isEmpty ? null : urls.first;

  /// True when the entry names a url that could be attempted at all.
  ///
  /// A scheme-less value is what a truncated playlist line parses as, and handing it to the player produces a
  /// black screen with no error, which is the failure a viewer cannot distinguish from a dead station.
  bool get isPlayable {
    final uri = primaryUrl;
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// The header names this channel needs, without their values.
  List<String> get headerNames => headers.keys.toList(growable: false);

  @override
  List<Object?> get equalityFields => <Object?>[name, group, urls];

  @override
  String toString() => 'ZapChannel($group/$name${isPlayable ? '' : ' (no stream)'})';
}
