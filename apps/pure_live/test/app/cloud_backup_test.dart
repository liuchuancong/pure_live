import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/backup/cloud/cloud_callback.dart';
import 'package:pure_live/features/backup/cloud/legacy_backup_importer.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';

void main() {
  group('LegacyBackupImporter', () {
    final versioned = <String, Object?>{
      'backupVersion': 3,
      'sensitiveDataIncluded': true,
      'theme': {'themeMode': 'dark'},
      'favorite': {
        'favoriteRooms': [
          {
            'platform': 'Bilibili',
            'roomId': '123',
            'title': '直播间',
            'nick': '主播',
            'userId': '9',
            'avatar': 'https://a/v.png',
            'cover': 'https://a/c.jpg',
            'liveStatus': 'live',
            'tagIds': ['t1'],
            'area': '游戏',
          },
          '{"platform":"douyu","roomId":"77","title":"s"}',
          {'platform': '', 'roomId': 'x'},
        ],
        'favoriteAreas': [
          {'platform': 'huya', 'areaId': '2', 'areaName': '户外', 'areaType': '1', 'typeName': '娱乐', 'areaPic': 'p'},
        ],
        'shieldList': ['bad'],
      },
      'history': {
        'historyRooms': [
          {'platform': 'douyin', 'roomId': '5', 'title': 'h', 'lastWatchedAt': 1700000000000},
        ],
      },
      'cookie': {'bilibiliCookie': 'SESSDATA=abc', 'huyaCookie': '', 'douyuLtp0': 'ltp'},
    };

    test('a v2 document is not legacy; the old shapes are', () {
      final v2 = BackupDocument(exportedAt: DateTime.utc(2026)).toJson();
      expect(LegacyBackupImporter.looksLegacy(v2), isFalse);
      expect(LegacyBackupImporter.looksLegacy(versioned), isTrue);
      expect(LegacyBackupImporter.looksLegacy({'favoriteRooms': <Object?>[]}), isTrue);
      expect(LegacyBackupImporter.looksLegacy({'random': 1}), isFalse);
    });

    test('rooms, areas, history and cookies cross over; the rest is named as skipped', () {
      final imported = LegacyBackupImporter.tryImport(versioned)!;
      final document = imported.document;

      expect(document.presentSections, {
        BackupSection.follows,
        BackupSection.areaFollows,
        BackupSection.history,
        BackupSection.secrets,
      });
      // Platform lowercased, the stringified item parsed, the roomless one dropped.
      expect(document.follows.keys, ['bilibili:123', 'douyu:77']);
      final room = document.follows['bilibili:123']!;
      expect((room['content']! as Map)['title'], '直播间');
      expect((room['anchor']! as Map)['name'], '主播');
      expect((room['local']! as Map)['tagIds'], ['t1']);
      expect(document.areaFollows, {
        'huya:2': {
          'platform': 'huya',
          'areaId': '2',
          'areaName': '户外',
          'parentAreaId': '1',
          'parentAreaName': '娱乐',
          'iconUrl': 'p',
        },
      });
      expect(document.history.keys, ['douyin:5']);
      expect(document.history['douyin:5']!['lastWatchedAt'], '2023-11-14T22:13:20.000Z');
      // Empty cookies are skipped; known keys map to the vault's refs.
      expect(document.secrets, {'cookie/bilibili': 'SESSDATA=abc', 'cookie/douyu.ltp0': 'ltp'});
      expect(imported.skipped, ['theme']);
      // The v2 writer can encode it and the reader round-trips it.
      expect(BackupDocument.tryDecode(document.encode())!.follows.keys, ['bilibili:123', 'douyu:77']);
    });

    test('the flat pre-version form reads from the root', () {
      final imported = LegacyBackupImporter.tryImport({
        'favoriteRooms': [
          {'platform': 'huya', 'roomId': '1', 'title': 'a'},
        ],
        'themeMode': 'dark',
      })!;
      expect(imported.document.follows.keys, ['huya:1']);
      expect(imported.document.hasHistory, isFalse);
      expect(imported.skipped, ['themeMode']);
    });
  });

  group('gitHubTokenFromCallback', () {
    const token = 'gho_abc123';
    final encoded = Uri.encodeComponent('{"accessToken":"$token"}');

    test('accepts the full link, the encoded JSON and the bare JSON', () {
      expect(gitHubTokenFromCallback('purelive://auth?credential=$encoded'), token);
      expect(gitHubTokenFromCallback(encoded), token);
      expect(gitHubTokenFromCallback('{"accessToken":"$token"}'), token);
      expect(gitHubTokenFromCallback('  purelive://auth?credential=$encoded  '), token);
    });

    test('refuses other hosts, empty tokens and garbage', () {
      expect(gitHubTokenFromCallback('purelive://other?credential=$encoded'), isNull);
      expect(gitHubTokenFromCallback('purelive://auth?credential=${Uri.encodeComponent('{"accessToken":""}')}'), isNull);
      expect(gitHubTokenFromCallback('https://example.com/?credential=$encoded'), isNull);
      expect(gitHubTokenFromCallback('not a link'), isNull);
      expect(gitHubTokenFromCallback(''), isNull);
    });
  });
}
