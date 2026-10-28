import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The preference the IPTV module's watch history is kept under.
const String kIptvRecentKey = 'iptv.recent';

/// How many channels the history keeps — the reference's 最近观看 is a way
/// back to what was just on, not an archive.
const int kIptvRecentLimit = 100;

/// One channel the viewer played, and when.
@immutable
final class IptvRecentEntry {
  /// A history record.
  const IptvRecentEntry({required this.channelId, required this.watchedAt});

  /// The library's channel id (stable across playlist re-imports).
  final String channelId;

  /// When it was last opened.
  final DateTime watchedAt;
}

/// The channels the viewer played, newest first.
final class IptvRecentController extends Notifier<List<IptvRecentEntry>> {
  @override
  List<IptvRecentEntry> build() {
    try {
      final raw = StoragePrefs.getString(kIptvRecentKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?_parse(entry)];
    } on Object {
      return const [];
    }
  }

  /// Moves [channelId] to the front of the history.
  Future<void> record(String channelId) async {
    final now = DateTime.now();
    state = [
      IptvRecentEntry(channelId: channelId, watchedAt: now),
      for (final entry in state)
        if (entry.channelId != channelId) entry,
    ].take(kIptvRecentLimit).toList();
    await _save();
  }

  /// Drops one channel from the history.
  Future<void> remove(String channelId) async {
    state = [
      for (final entry in state)
        if (entry.channelId != channelId) entry,
    ];
    await _save();
  }

  /// Drops every channel.
  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(
        kIptvRecentKey,
        jsonEncode([
          for (final entry in state) {'id': entry.channelId, 'at': entry.watchedAt.millisecondsSinceEpoch},
        ]),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static IptvRecentEntry? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final at = (json['at'] as num?)?.toInt();
    if (id is! String || id.isEmpty || at == null) return null;
    return IptvRecentEntry(channelId: id, watchedAt: DateTime.fromMillisecondsSinceEpoch(at));
  }
}

/// The IPTV module's watch history.
final iptvRecentProvider = NotifierProvider<IptvRecentController, List<IptvRecentEntry>>(IptvRecentController.new);
