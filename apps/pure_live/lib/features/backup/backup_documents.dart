import 'dart:convert';
import 'dart:io';

import 'package:live_library/live_library.dart';
import 'package:path/path.dart' as p;

/// The follows-only backup (the reference's `exportFollows` half, ported to
/// this app's own store shape): one JSON document holding the followed
/// rooms and the follow groups — everything the follow page is made of,
/// and nothing else, exactly the 仅关注 scope's promise.
final class FollowsBackup {
  /// The parsed document.
  const new({required this.rooms, required this.groups});

  /// The followed rooms, records included (note, groups, position).
  final List<LibraryRoom> rooms;

  /// The follow groups.
  final List<FollowGroup> groups;

  /// Reads the document; null when the shape is not a follows backup. Every
  /// entry is checked rather than cast, so a hand-edited file answers the
  /// "not a backup" path instead of throwing mid-list.
  static FollowsBackup? tryParse(Map<String, Object?> json) {
    if (json['kind'] != 'follows') {
      return null;
    }
    final rooms = json['rooms'];
    final groups = json['groups'];
    if (rooms is! List || groups is! List) {
      return null;
    }
    try {
      return FollowsBackup(
        rooms: [
          for (final room in rooms)
            if (room is Map) LibraryRoom.fromJson(Map<String, Object?>.from(room)) else ...const [],
        ],
        groups: [
          for (final group in groups)
            if (group is Map) FollowGroup.fromJson(Map<String, Object?>.from(group)) else ...const [],
        ],
      );
    } on Object {
      return null;
    }
  }

  /// The document as written.
  Map<String, Object?> toJson() => {
    'kind': 'follows',
    'version': 1,
    'rooms': [for (final room in rooms) room.toJson()],
    'groups': [for (final group in groups) group.toJson()],
  };
}

/// The follows document of the current repository state.
Map<String, Object?> buildFollowsDocument(FollowRepository repository) =>
    FollowsBackup(rooms: repository.rooms, groups: repository.groups).toJson();

/// The stamped file name of a follows backup; the `-follows-` in it is what
/// the file list reads as the kind, so it must stay in one piece.
String followsBackupName(DateTime at) =>
    'pure_live-follows-${at.year}${_two(at.month)}${_two(at.day)}-${_two(at.hour)}${_two(at.minute)}${_two(at.second)}.json';

/// Writes the follows document into [folder] and returns the file.
File writeFollowsBackup({required Directory folder, required Map<String, Object?> document, DateTime? now}) {
  folder.createSync(recursive: true);
  final file = File(p.join(folder.path, followsBackupName(now ?? DateTime.now())))
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(document), flush: true);
  return file;
}

/// Reads a backup file's JSON; throws [FormatException] when the file is not
/// a JSON object (the reference's "not a backup" answer).
Map<String, Object?> readBackupDocument(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('not a backup document');
  }
  return Map<String, Object?>.from(decoded);
}

String _two(int value) => value.toString().padLeft(2, '0');
