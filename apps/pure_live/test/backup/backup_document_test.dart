import 'dart:convert' show jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';

/// The backup document's codec: the round trip that writes only the
/// sections it carries, the absence that tells a restore to leave a box
/// alone, the reference's follows-only scope honoured on the read side,
/// the stranger's JSON that never passes for a backup, the entries a
/// newer writer's shapes cost, and the damaged stamp that must not turn
/// a decode into a throw.
void main() {
  /// The version tag this app writes.
  Map<String, Object?> version({
    String scope = 'all',
    int schema = BackupDocument.schemaVersion,
    Object? exportedAt = '2026-11-21T08:00:00.000Z',
  }) => {'app': BackupDocument.appTag, 'schema': schema, 'scope': scope, 'exportedAt': exportedAt};

  test('the round trip writes only the sections the document carries', () {
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21, 8),
      follows: {
        'bili:1': {'roomId': 1},
      },
      settings: {'interface.theme': 'dark'},
      secrets: {'webdav.main.password': 'hush'},
      presentSections: {BackupSection.follows, BackupSection.settings, BackupSection.secrets},
    );
    final read = BackupDocument.tryDecode(document.encode());

    expect(read, isNotNull);
    expect(read!.exportedAt, document.exportedAt);
    expect(read.hasFollows, isTrue);
    expect(read.hasSettings, isTrue);
    expect(read.hasSecrets, isTrue);
    expect(read.hasHistory, isFalse); // never written, never restored
    expect(read.hasIptv, isFalse);
    expect(read.follows['bili:1'], {'roomId': 1});
    expect(read.settings['interface.theme'], 'dark');
    expect(read.secrets['webdav.main.password'], 'hush');
    expect(read.followsOnly, isFalse);
    expect(read.restoresFollowsOnly, isFalse); // secrets are not follows
    // The absent sections are absent from the wire, not empty.
    expect(document.encode(), isNot(contains('"history"')));
    expect(document.encode(), contains('"scope":"all"'));
  });

  test('a follows-only document names its scope and restores those two alone', () {
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21, 8),
      follows: {
        'bili:1': {'roomId': 1},
      },
      areaFollows: {
        'bili: room:2': {'areaId': 2},
      },
      presentSections: BackupSection.followsOnly,
    );
    final read = BackupDocument.tryDecode(document.encode())!;

    expect(read.followsOnly, isTrue);
    expect(read.restoresFollowsOnly, isTrue);
    expect(read.hasFollows, isTrue);
    expect(read.hasAreas, isTrue);
    expect(read.hasHistory, isFalse);
    expect(document.encode(), contains('"scope":"follows"'));
  });

  test('the schema-1 scope keeps a full write to the boxes it meant', () {
    // Schema 1 wrote every section even for a follows-only file; the scope
    // is what keeps a restore off the rest.
    final root = jsonEncode({
      'version': version(scope: 'follows', schema: 1),
      'follows': {
        'bili:1': {'roomId': 1},
      },
      'areaFollows': {
        'bili: room:2': {'areaId': 2},
      },
      'history': {
        'bili:1': {'roomId': 1, 'lastWatchedAt': 5},
      }, // written but not meant
      'settings': <String, Object?>{},
      'recordings': <String, Object?>{},
      'iptv': <String, Object?>{},
      'multiview': <String, Object?>{},
      'secrets': <String, Object?>{},
    });
    final read = BackupDocument.tryDecode(root)!;

    expect(read.presentSections, BackupSection.followsOnly);
    expect(read.hasFollows, isTrue);
    expect(read.follows, hasLength(1));
    expect(read.hasHistory, isFalse); // the scope wins over the written map
    expect(read.hasSettings, isFalse);
    expect(read.restoresFollowsOnly, isTrue);
  });

  test("a stranger's JSON needs two known sections to pass for a backup", () {
    // Not JSON, not an object.
    expect(BackupDocument.tryDecode('not json'), isNull);
    expect(BackupDocument.tryDecode('"a string"'), isNull);
    // An empty object must never wipe a device.
    expect(BackupDocument.tryDecode('{}'), isNull);
    // A lone known section is some other file's shape.
    expect(
      BackupDocument.tryDecode(
        jsonEncode(<String, Object?>{
          'history': <String, Object?>{'a:1': {}},
        }),
      ),
      isNull,
    );
    // Two known sections pass, untagged.
    final read = BackupDocument.tryDecode(
      jsonEncode({
        'history': {
          'a:1': {'roomId': 1},
        },
        'follows': {
          'a:1': {'roomId': 1},
        },
      }),
    );
    expect(read, isNotNull);
    expect(read!.exportedAt, DateTime.fromMillisecondsSinceEpoch(0)); // no stamp said
    // This app's own tag passes alone, even with nothing to restore.
    final own = BackupDocument.tryDecode(jsonEncode({'version': version()}));
    expect(own, isNotNull);
    expect(own!.presentSections, isEmpty);
    expect(own.isEmpty, isTrue);
  });

  test('the entries a newer shape costs are counted per present section', () {
    final raw = jsonEncode({
      'version': version(),
      'follows': {
        'a:1': {'roomId': 1},
        'a:bad': 'not a map',
        'a:two': {'roomId': 2},
      },
      'secrets': {'webdav.main.password': 'hush', 'webdav.bad.password': 42},
    });
    final read = BackupDocument.tryDecode(raw)!;

    expect(read.follows, hasLength(2));
    expect(read.skipped[BackupSection.follows], 1);
    expect(read.secrets, hasLength(1));
    expect(read.skipped[BackupSection.secrets], 1);

    // Narrowing past a section drops its skipped count with it.
    final narrowed = read.only({BackupSection.follows});
    expect(narrowed.hasSecrets, isFalse);
    expect(narrowed.skipped.containsKey(BackupSection.secrets), isFalse);
    expect(narrowed.skipped[BackupSection.follows], 1);
  });

  test('a damaged stamp is the epoch, never a throw', () {
    // The codec's own contract: a field of the wrong shape is dropped, not
    // a failure — a hand-edited or newer-writer stamp must not turn the
    // whole restore away.
    final stamped = jsonEncode({
      'version': version(exportedAt: 1234567890), // a number where the text goes
      'follows': {
        'a:1': {'roomId': 1},
      },
    });
    final read = BackupDocument.tryDecode(stamped);
    expect(read, isNotNull);
    expect(read!.exportedAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(read.hasFollows, isTrue);

    final unreadable = BackupDocument.tryDecode(
      jsonEncode({
        'version': version(exportedAt: 'not a moment'),
        'follows': {
          'a:1': {'roomId': 1},
        },
      }),
    );
    expect(unreadable!.exportedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('the counts and the empties the pane shows', () {
    final empty = BackupDocument(exportedAt: DateTime.utc(2026, 11, 21));
    expect(empty.isEmpty, isTrue);
    expect(empty.counts.follows, 0);

    final full = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 21),
      follows: {'a:1': {}, 'a:2': {}},
      history: {'a:1': {}},
      iptv: {
        'iptv.playlists.v1': {
          'items': [1, 2, 3],
        },
        'iptv.groups.v1': {
          'items': [1],
        },
        'iptv.empty.v1': <String, Object?>{},
      },
      settings: {'a': 1, 'b': 2},
      presentSections: BackupSection.all,
    );
    expect(full.isEmpty, isFalse);
    expect(full.countOf(BackupSection.follows), 2);
    expect(full.countOf(BackupSection.history), 1);
    expect(full.countOf(BackupSection.iptv), 4); // the items lists summed, the empty one not
    expect(full.countOf(BackupSection.settings), 2);
    expect(full.counts.follows, 2);
    expect(full.counts.history, 1);
    expect(full.counts.secrets, 0);
  });

  test('the export file name carries the local stamp and the kind', () {
    final moment = DateTime(2026, 11, 21, 9, 8, 7);
    expect(BackupDocument.exportFileName(moment), 'pure_live_backup_20261121_090807.json');
    expect(BackupDocument.exportFileName(moment, followsOnly: true), 'pure_live_follows_20261121_090807.json');
    // A single-digit month and day still pad.
    expect(BackupDocument.exportFileName(DateTime(2026, 3, 4, 5, 6, 7)), 'pure_live_backup_20260304_050607.json');
  });
}
