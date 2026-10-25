import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;

/// One local follow group: a name the viewer made and the id rooms carry in
/// their `RoomLocal.tagIds`.
typedef FollowTag = ({String id, String name});

const String _tagsKey = 'follow.tags';

/// The viewer's follow tags, stored as one JSON list under `follow.tags`.
///
/// Tags are local (never a platform's own): a room joins them through its
/// stored `RoomLocal.tagIds`, and removing a tag strips its id from every
/// follow, so no room keeps pointing at a tag the picker no longer offers.
final class FollowTagsController extends Notifier<List<FollowTag>> {
  @override
  List<FollowTag> build() {
    try {
      final raw = StoragePrefs.getString(_tagsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map && entry['id'] is String && entry['name'] is String)
            (id: entry['id'] as String, name: (entry['name'] as String).trim()),
      ].where((tag) => tag.name.isNotEmpty).toList(growable: false);
    } on Object {
      return const [];
    }
  }

  /// Adds [raw] as a tag; null when it is blank or already present (names
  /// compare without case, since two "游戏" tags would only confuse).
  Future<FollowTag?> add(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return null;
    if (state.any((tag) => tag.name.toLowerCase() == name.toLowerCase())) return null;
    final tag = (id: 'tag-${DateTime.now().microsecondsSinceEpoch}', name: name);
    state = [...state, tag];
    _write();
    return tag;
  }

  /// Removes the tag behind [id] from the list and from every follow's
  /// `tagIds`.
  Future<void> remove(String id) async {
    if (!state.any((tag) => tag.id == id)) return;
    state = [
      for (final tag in state)
        if (tag.id != id) tag,
    ];
    _write();
    await ref.read(followsProvider.notifier).stripTag(id);
  }

  /// The tag [id] names, when it still exists.
  FollowTag? byId(String id) {
    for (final tag in state) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  /// The names of [ids], in the tag list's order, with unknown ids left out.
  List<String> namesOf(Iterable<String> ids) {
    final wanted = ids.toSet();
    return [
      for (final tag in state)
        if (wanted.contains(tag.id)) tag.name,
    ];
  }

  void _write() {
    try {
      final encoded = jsonEncode([
        for (final tag in state) {'id': tag.id, 'name': tag.name},
      ]);
      unawaited(StoragePrefs.setString(_tagsKey, encoded));
    } on Object {
      // The tags are a preference; a closed store loses them.
    }
  }
}

/// The viewer's follow tags.
final followTagsProvider = NotifierProvider<FollowTagsController, List<FollowTag>>(FollowTagsController.new);
