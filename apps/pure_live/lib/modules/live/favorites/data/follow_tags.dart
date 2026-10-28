import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;

/// The longest tag name the editor takes (the reference's `TagStore.maxNameLength`).
const int kFollowTagNameMaxLength = 15;

/// The longest tag note the editor takes (the reference's `maxDescriptionLength`).
const int kFollowTagDescriptionMaxLength = 40;

/// One local follow group: a name (and an optional note) the viewer made and
/// the id rooms carry in their `RoomLocal.tagIds`.
typedef FollowTag = ({String id, String name, String description});

const String _tagsKey = 'follow.tags';

/// The viewer's follow tags, stored as one JSON list under `follow.tags`.
///
/// Tags are local (never a platform's own): a room joins them through its
/// stored `RoomLocal.tagIds`, and removing a tag strips its id from every
/// follow, so no room keeps pointing at a tag the picker no longer offers.
/// The list's own order is the order the favorites' tag strip shows.
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
            (
              id: entry['id'] as String,
              name: (entry['name'] as String).trim(),
              description: (entry['description'] as String?)?.trim() ?? '',
            ),
      ].where((tag) => tag.name.isNotEmpty).toList(growable: false);
    } on Object {
      return const [];
    }
  }

  /// Whether [name] is usable: not blank, and not another tag's name
  /// (names compare without case — two “游戏” tags would only confuse).
  bool nameUsable(String name, {String? excludingId}) {
    final folded = name.trim().toLowerCase();
    if (folded.isEmpty) return false;
    return !state.any((tag) => tag.id != excludingId && tag.name.toLowerCase() == folded);
  }

  /// Adds [raw] with an optional note as a tag; null when the name is blank
  /// or already present.
  Future<FollowTag?> add(String raw, {String description = ''}) async {
    final name = _clip(raw.trim(), kFollowTagNameMaxLength);
    if (name.isEmpty || !nameUsable(name)) return null;
    final tag = (
      id: 'tag-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      description: _clip(description.trim(), kFollowTagDescriptionMaxLength),
    );
    state = [...state, tag];
    _write();
    return tag;
  }

  /// Renames the tag behind [id], replacing its note; false when the tag is
  /// gone or the name is refused (blank, or another tag's).
  Future<bool> rename(String id, {required String name, String description = ''}) async {
    final clean = _clip(name.trim(), kFollowTagNameMaxLength);
    if (clean.isEmpty || !nameUsable(clean, excludingId: id)) return false;
    if (!state.any((tag) => tag.id == id)) return false;
    state = [
      for (final tag in state)
        if (tag.id == id)
          (id: id, name: clean, description: _clip(description.trim(), kFollowTagDescriptionMaxLength))
        else
          tag,
    ];
    _write();
    return true;
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

  /// Moves the item at [from] to [to] in the list's order (the favorites'
  /// tag strip follows it).
  Future<void> move(int from, int to) async {
    if (from == to || from < 0 || to < 0 || from >= state.length || to >= state.length) return;
    final next = [...state];
    next.insert(to, next.removeAt(from));
    state = next;
    _write();
  }

  /// Puts the tag behind [id] first (the reference's `pinToTop`).
  Future<void> pinToTop(String id) async {
    final index = state.indexWhere((tag) => tag.id == id);
    if (index <= 0) return;
    await move(index, 0);
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

  /// Drops a tag name that is too long, rather than refusing a paste.
  static String _clip(String value, int maxLength) =>
      value.runes.length <= maxLength ? value : String.fromCharCodes(value.runes.take(maxLength));

  void _write() {
    try {
      final encoded = jsonEncode([
        for (final tag in state) {'id': tag.id, 'name': tag.name, 'description': tag.description},
      ]);
      unawaited(StoragePrefs.setString(_tagsKey, encoded));
    } on Object {
      // The tags are a preference; a closed store loses them.
    }
  }
}

/// The viewer's follow tags.
final followTagsProvider = NotifierProvider<FollowTagsController, List<FollowTag>>(FollowTagsController.new);
