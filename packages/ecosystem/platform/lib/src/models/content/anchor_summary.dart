// Module: lib/src/models/content/anchor_summary.dart
// Purpose: A person a source can be searched for, as opposed to a room or a video.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (anchor search). Existence evidence for the shape is in
// docs/sources/live/*.md: searching for a streamer is a separate query from searching their room on every
// platform that has both, because the endpoint, the paging and the result row all differ.

import '../../support/json.dart';
import 'content_ref.dart';

/// One anchor as search results and follow rows describe them.
final class AnchorSummary {
  const AnchorSummary({
    required this.ref,
    required this.name,
    this.avatar,
    this.fans,
    this.currentRoom,
    this.description,
    this.extra = const <String, Object?>{},
  });

  factory AnchorSummary.fromJson(Map<String, Object?> json) => AnchorSummary(
    ref: ContentRef.fromJson(asObjectMap(json['ref'])),
    name: requireString(json, 'name', 'anchor_summary'),
    avatar: json['avatar'] is String ? json['avatar']! as String : null,
    fans: _intOrNull(json['fans']),
    currentRoom: json['currentRoom'] == null ? null : ContentRef.fromJson(asObjectMap(json['currentRoom'])),
    description: json['description'] is String ? json['description']! as String : null,
    extra: asObjectMap(json['extra']),
  );

  /// The anchor as content: following someone is a ref, and every other column here is display.
  final ContentRef ref;
  final String name;
  final String? avatar;

  /// Follower count as the platform wrote it; null means it did not say, which is not zero.
  final int? fans;

  /// The room they are in right now, when the platform knows. This is what makes the row tappable: an anchor
  /// without a live room opens a profile, not a player.
  final ContentRef? currentRoom;
  final String? description;

  final Map<String, Object?> extra;

  bool get isLiveNow => currentRoom != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref.toJson(),
    'name': name,
    if (avatar != null) 'avatar': avatar,
    if (fans != null) 'fans': fans,
    if (currentRoom != null) 'currentRoom': currentRoom!.toJson(),
    if (description != null) 'description': description,
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'AnchorSummary($name${fans == null ? '' : ' $fans fans'})';
}

int? _intOrNull(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};
