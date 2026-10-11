// Module: lib/src/model/huya_room_profile.dart
// Purpose: The profileRoom answer for one huya room, read once and used by every huya capability.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. One parse of this response serves four questions (is it live, what is it
// called, which CDNs serve it, what ticket can be signed), so they are read together here rather than four
// places re-walking the same JSON with four different tolerance rules.

import 'huya_stream_entry.dart';

/// A room as profileRoom described it.
final class HuyaRoomProfile {
  const HuyaRoomProfile({
    required this.roomId,
    required this.liveStatusCode,
    this.roomName = '',
    this.introduction = '',
    this.anchorName = '',
    this.screenshot,
    this.viewers,
    this.entries = const <HuyaStreamEntry>[],
  });

  /// Reads one profileRoom payload. [raw] is the `data` object; a room that does not exist answers without one,
  /// and the caller decides what that means for its capability.
  factory HuyaRoomProfile.fromJson(String roomId, Map<String, Object?> raw) {
    final liveData = _map(raw['liveData']);
    final stream = _map(raw['stream']);
    final baseList = raw['baseSteamInfoList'] is List ? raw['baseSteamInfoList']! as List : const <Object?>[];
    return HuyaRoomProfile(
      roomId: roomId,
      liveStatusCode: _int(liveData['liveStatus']) ?? _int(raw['liveStatus']) ?? -1,
      roomName: '${liveData['sRoomName'] ?? raw['sRoomName'] ?? ''}',
      introduction: '${liveData['introduction'] ?? raw['introduction'] ?? ''}',
      anchorName: '${liveData['nick'] ?? raw['nick'] ?? ''}',
      screenshot: _text(liveData['screenshot'] ?? raw['screenshot']),
      viewers: _int(liveData['userCount'] ?? raw['userCount']),
      entries: <HuyaStreamEntry>[
        for (final entry in stream['baseSteamInfoList'] is List ? stream['baseSteamInfoList']! as List : baseList)
          if (entry is Map) HuyaStreamEntry.fromJson(Map<String, Object?>.from(entry)),
      ],
    );
  }

  final String roomId;

  /// The raw flag the endpoint sends. `1` is on air; anything else - including a response that omitted it,
  /// which reads as -1 - is "not live or unknown", and the two are told apart by [isLiveKnown].
  final int liveStatusCode;

  final String roomName;
  final String introduction;
  final String anchorName;
  final String? screenshot;

  /// Viewer count as the platform reported it; null means it did not say, which is not zero.
  final int? viewers;

  /// The CDN entries, in the source's own priority order. Empty means the room is not streaming.
  final List<HuyaStreamEntry> entries;

  bool get isLive => liveStatusCode == 1;

  bool get isLiveKnown => liveStatusCode >= 0;

  bool get hasStream => entries.any((entry) => entry.isUsable);

  static Map<String, Object?> _map(Object? value) => value is Map ? Map<String, Object?>.from(value) : const {};

  static int? _int(Object? value) => switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  static String? _text(Object? value) {
    final text = '${value ?? ''}';
    return text.isEmpty ? null : text;
  }
}
