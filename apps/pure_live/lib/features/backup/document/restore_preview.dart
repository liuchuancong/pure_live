import 'dart:convert' show jsonDecode;

import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:pure_live/features/backup/document/backup_document.dart';

/// How one section of the device changes in a restore: its entries now and
/// after, and the ones the restore adds and removes, told apart by identity
/// rather than by count — twelve rooms in and twelve out is not "no change".
final class RestorePart {
  /// The change of [section].
  const new({required this.section, required this.current, required this.incoming, this.added = 0, this.removed = 0});

  /// Compares the [current] entries with the [incoming] ones by identity
  /// key: the counts as they are, the additions and removals as sets.
  factory compare(BackupSection section, Iterable<String> current, Iterable<String> incoming) {
    final now = current.toSet();
    final next = incoming.toSet();
    return RestorePart(
      section: section,
      current: current.length,
      incoming: incoming.length,
      added: next.difference(now).length,
      removed: now.difference(next).length,
    );
  }

  /// The section.
  final BackupSection section;

  /// Entries on the device now.
  final int current;

  /// Entries after the restore.
  final int incoming;

  /// Entries the restore brings that the device does not have.
  final int added;

  /// Entries the device has that the restore takes away.
  final int removed;

  /// Whether the restore leaves the section's entries as they are.
  bool get unchanged => added == 0 && removed == 0 && current == incoming;
}

/// What a restore would do to this device, worked out before it runs with
/// the rules the restore itself writes by, so the confirm can show the
/// changes rather than the file's totals.
final class RestorePreview {
  /// The preview.
  const new({
    required this.parts,
    required this.kept,
    this.followsOnlyFile = false,
    this.settingsInFile = 0,
    this.settingsChanged = 0,
    this.accounts = 0,
    this.skipped = 0,
  });

  /// The keyed sections the restore replaces, in section order.
  final List<RestorePart> parts;

  /// The sections this device holds that the restore leaves alone: the
  /// file lacks them, or the user left them unchecked.
  final List<BackupSection> kept;

  /// Whether the file is a follows-only backup: whatever was asked of it,
  /// it restores followed rooms and areas and nothing else.
  final bool followsOnlyFile;

  /// The settings the restore writes.
  final int settingsInFile;

  /// The written settings whose value differs from the stored one.
  final int settingsChanged;

  /// The credentials the restore writes; the vault's others stay.
  final int accounts;

  /// The entries left out because they could not be read.
  final int skipped;

  /// Whether the restore would change anything the preview can tell.
  bool get changesSomething => settingsChanged > 0 || accounts > 0 || parts.any((part) => !part.unchanged);
}

/// The field that names an item under each IPTV setup key: a playlist and a
/// guide source by id, a group by its name, a mapping by the channel it
/// maps (the library keeps one mapping per channel).
const Map<String, String> _iptvIdentityFields = {
  IptvKeys.playlists: 'id',
  IptvKeys.groups: 'name',
  IptvKeys.guideSources: 'id',
  IptvKeys.guideMappings: 'channelId',
};

/// The identities of the IPTV setup's [items] (setup key → its items) as
/// `key/identity`; an item without its naming field counts by its content.
List<String> iptvItemIdentities(Map<String, List<Object?>> items) => [
  for (final MapEntry(:key, value: list) in items.entries)
    for (final item in list) '$key/${_identityOf(item, _iptvIdentityFields[key])}',
];

String _identityOf(Object? item, String? field) {
  final value = item is Map && field != null ? item[field] : null;
  return value is String && value.isNotEmpty ? value : '$item';
}

/// The rooms a multiview section holds: the identity in every filled slot
/// of every wall document (store key → the document, as a map or as its
/// JSON text).
List<String> multiviewRooms(Map<String, Object?> documents) => [
  for (final document in documents.values)
    for (final slot in _slotsOf(document))
      if (slot is String && slot.isNotEmpty) slot,
];

List<Object?> _slotsOf(Object? document) {
  var json = document;
  if (json is String) {
    try {
      json = jsonDecode(json);
    } on FormatException {
      return const [];
    }
  }
  final slots = json is Map ? json['slots'] : null;
  return slots is List ? slots : const [];
}
