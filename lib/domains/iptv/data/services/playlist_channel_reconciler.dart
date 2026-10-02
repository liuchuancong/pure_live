import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:pure_live/domains/iptv/data/local/database.dart' as db;
import 'package:pure_live/domains/iptv/domain/channel.dart' as model;
import 'package:pure_live/core/network/http_header_policy.dart';

/// Preserve durable IDs by unambiguous feed identity, never String.hashCode.
/// Combined stream/name matches precede URL-independent matches for rotating
/// tokens; a unique unchanged URL is the last resort for corrected feed names.
List<db.ChannelsCompanion> reconcilePlaylistChannels({
  required String providerId,
  required List<db.Channel> previous,
  required List<model.Channel> incoming,
}) {
  final unique = <String, model.Channel>{};
  for (final channel in incoming) {
    unique.putIfAbsent(
      jsonEncode([
        channel.name,
        channel.tvgId,
        channel.tvgName,
        channel.tvgLogo,
        channel.groupTitle,
        channel.channelNumber,
        channel.streamUrl,
        channel.streamType.name,
        channel.catchupMode,
        channel.catchupSource,
        channel.catchupDays,
        channel.catchupCorrectionHours,
        HttpHeaderPolicy.encode(channel.httpHeaders),
      ]),
      () => channel,
    );
  }
  final channels = unique.values.toList();
  final matched = <int, db.Channel>{};
  final used = <String>{};
  for (var phase = 0; phase < 8; phase++) {
    final oldKeys = <String, List<db.Channel>>{};
    final newKeys = <String, List<int>>{};
    for (final old in previous) {
      if (used.contains(old.id)) continue;
      final key = _key(phase, old.name, old.tvgId, old.streamUrl, old.groupTitle);
      if (key != null) (oldKeys[key] ??= []).add(old);
    }
    for (var i = 0; i < channels.length; i++) {
      if (matched.containsKey(i)) continue;
      final channel = channels[i];
      final key = _key(phase, channel.name, channel.tvgId, channel.streamUrl, channel.groupTitle);
      if (key != null) (newKeys[key] ??= []).add(i);
    }
    for (final entry in newKeys.entries) {
      final old = oldKeys[entry.key];
      if (entry.value.length != 1 || old == null || old.length != 1) continue;
      final i = entry.value.single;
      final oldTvg = _normalize(old.single.tvgId);
      final newTvg = _normalize(channels[i].tvgId);
      if (oldTvg.isNotEmpty && newTvg.isNotEmpty && oldTvg != newTvg) continue;
      matched[i] = old.single;
      used.add(old.single.id);
    }
  }
  // A rotating multi-line feed can leave several equally plausible old IDs.
  // Index remaining candidates rather than doing another quadratic scan.
  final remainingTvg = <String>{};
  final remainingNames = <String, Set<String>>{};
  final remainingUrls = <String, Set<String>>{};
  for (final old in previous) {
    if (used.contains(old.id)) continue;
    final tvg = _normalize(old.tvgId);
    if (tvg.isNotEmpty) remainingTvg.add(tvg);
    (remainingNames[_normalize(old.name)] ??= {}).add(tvg);
    (remainingUrls[old.streamUrl.trim()] ??= {}).add(tvg);
  }
  for (var i = 0; i < channels.length; i++) {
    if (matched.containsKey(i)) continue;
    final t = _normalize(channels[i].tvgId);
    final names = remainingNames[_normalize(channels[i].name)];
    final urls = remainingUrls[channels[i].streamUrl.trim()];
    bool plausible(Set<String>? values) => values != null && (t.isEmpty || values.contains('') || values.contains(t));
    if ((t.isNotEmpty && remainingTvg.contains(t)) || plausible(names) || plausible(urls)) {
      throw StateError('Ambiguous playlist channel identities; previous playlist preserved');
    }
  }
  return [for (var i = 0; i < channels.length; i++) _entry(providerId, channels[i], matched[i])];
}

String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
String? _key(int phase, String name, String? tvgId, String url, String? group) {
  final n = _normalize(name), t = _normalize(tvgId), g = _normalize(group);
  final u = url.trim();
  return switch (phase) {
    0 => t.isEmpty ? null : jsonEncode([t, u, g]),
    1 => n.isEmpty ? null : jsonEncode([n, u, g]),
    2 => t.isEmpty ? null : jsonEncode([t, u]),
    3 => n.isEmpty ? null : jsonEncode([n, u]),
    4 => t.isEmpty ? null : t,
    5 => n.isEmpty ? null : jsonEncode([n, g]),
    6 => n.isEmpty ? null : n,
    _ => u.isEmpty ? null : u,
  };
}

db.ChannelsCompanion _entry(String providerId, model.Channel channel, db.Channel? old) {
  if (old != null && !old.isAutoUpdate) return old.toCompanion(false);
  return db.ChannelsCompanion.insert(
    id: old?.id ?? const Uuid().v4(),
    providerId: providerId,
    name: channel.name,
    streamUrl: channel.streamUrl,
    groupTitle: Value(channel.groupTitle),
    tvgId: Value(channel.tvgId),
    tvgName: Value(channel.tvgName),
    tvgLogo: Value(channel.tvgLogo),
    channelNumber: Value(channel.channelNumber),
    streamType: Value(channel.streamType.name),
    catchupMode: Value(channel.catchupMode),
    catchupSource: Value(channel.catchupSource),
    catchupDays: Value(channel.catchupDays),
    catchupCorrectionHours: Value(channel.catchupCorrectionHours),
    httpHeadersJson: Value(HttpHeaderPolicy.encode(channel.httpHeaders)),
    favorite: Value(old?.favorite ?? false),
    hidden: Value(old?.hidden ?? false),
    sortOrder: Value(old?.sortOrder ?? 0),
    isAutoUpdate: Value(old?.isAutoUpdate ?? true),
  );
}
