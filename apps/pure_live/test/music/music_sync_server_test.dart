import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/music/controller/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/music_sync_data.dart';
import 'package:pure_live/modules/music/controller/music_sync_server.dart';

Map<String, Object?> _song(String id) => <String, Object?>{'id': id, 'name': 'Song $id'};

Map<String, Object?> _userList(String id, {int? updateTime, List<Object?>? songs}) => <String, Object?>{
  'id': id,
  'name': 'List $id',
  ...?updateTime == null ? null : <String, Object?>{'locationUpdateTime': updateTime},
  'list': songs ?? const <Object?>[],
};

void main() {
  group('merge modes', () {
    final local = <String, Object?>{
      'defaultList': [_song('a'), _song('b')],
      'loveList': [_song('love-1')],
      'userList': [_userList('u1', songs: [_song('x')])],
    };
    final remote = <String, Object?>{
      'defaultList': [_song('b'), _song('c')],
      'loveList': <Object?>[],
      'userList': [_userList('u2', songs: [_song('y')])],
    };

    test('merge keeps both sides and dedupes by song id', () {
      final result = musicSyncMergeListData(local, remote, 'merge_remote_local', addToTop: false)!;
      expect(result.updateLocal, isTrue);
      expect(result.updateRemote, isTrue);
      expect((result.data['defaultList']! as List).map((s) => (s as Map)['id']), ['b', 'c', 'a']);
      // Both user lists survive a merge.
      expect((result.data['userList']! as List).length, 2);
    });

    test('full overwrites take one side untouched', () {
      final localWins = musicSyncMergeListData(local, remote, 'overwrite_local_remote_full', addToTop: true)!;
      expect(localWins.updateLocal, isFalse);
      expect(localWins.data, local);

      final remoteWins = musicSyncMergeListData(local, remote, 'overwrite_remote_local_full', addToTop: true)!;
      expect(remoteWins.updateRemote, isFalse);
      expect(remoteWins.data, remote);
    });

    test('a stranger mode reads as cancel', () {
      expect(musicSyncMergeListData(local, remote, 'cancel', addToTop: true), isNull);
      expect(musicSyncMergeListData(local, remote, 'bogus', addToTop: true), isNull);
    });

    test('partial payloads patch to empty lists', () {
      expect(musicSyncListDataIsEmpty(musicSyncPatchListData(null)), isTrue);
      expect(musicSyncListDataIsEmpty(musicSyncPatchListData(<String, Object?>{'loveList': [_song('a')]})), isFalse);
    });

    test('a target-only user list with a remembered position joins at it', () {
      final source = <String, Object?>{
        'defaultList': const <Object?>[],
        'loveList': const <Object?>[],
        'userList': [_userList('keep', songs: const <Object?>[])],
      };
      final target = <String, Object?>{
        'defaultList': const <Object?>[],
        'loveList': const <Object?>[],
        'userList': [_userList('new', updateTime: 5), _userList('untracked', updateTime: 7)],
      };
      final merged = musicSyncOverwriteUserLists(source, target);
      final ids = (merged['userList']! as List).map((l) => (l as Map)['id']).toList();
      expect(ids, ['new', 'untracked', 'keep']);
    });
  });

  group('dislike merge', () {
    test('both sides normalize, alias their inner markers and dedupe', () {
      final merged = musicSyncDislikeMerge('Song A@singer\nsong b@x', 'song a@SINGER\nSong C');
      expect(merged.split('\n')..sort(), ['song a@singer', 'song b@x', 'song c']);
    });

    test('the split keeps the first two fields and drops the rest', () {
      // The reference splits on the marker, so a third field falls away.
      expect(musicSyncDislikeMerge('Weird@Name@1', ''), 'weird@name');
      expect(musicSyncDislikeMerge('@Singer Only', ''), '@singer only');
    });
  });

  group('device registry shape', () {
    test('the key info round-trips through JSON', () {
      final device = MusicSyncServerDevice(
        clientId: 'cid',
        key: 'key',
        deviceName: 'Phone',
        isMobile: true,
        lastConnectDate: 1234,
      );
      final restored = MusicSyncServerDevice.fromJson(device.toJson());
      expect(restored.clientId, 'cid');
      expect(restored.key, 'key');
      expect(restored.deviceName, 'Phone');
      expect(restored.isMobile, isTrue);
      expect(restored.lastConnectDate, 1234);
    });

    test('a damaged entry is rejected, not guessed', () {
      expect(() => MusicSyncServerDevice.fromJson(<String, Object?>{'clientId': 'cid'}), throwsFormatException);
    });
  });

  group('crypto', () {
    test('a peer public key parses from SPKI and answers an OAEP round trip', () {
      final pair = MusicSyncRsaKeyPair.generate();
      final peer = MusicSyncPeerPublicKey.parseSpki(pair.publicSpkiBase64);
      final sealed = peer.encryptOaepBase64('lx-music connect');
      expect(pair.decryptOaep(sealed), 'lx-music connect');
    });

    test('random tokens are base64 and unique', () {
      final a = musicSyncRandomToken();
      expect(a, isNot(equals(musicSyncRandomToken())));
      expect(a.endsWith('='), anyOf(isTrue, isFalse)); // base64, 16 bytes → 24 chars
      expect(a.length, 24);
    });

    test('the connection code is six digits', () {
      expect(RegExp(r'^\d{6}$').hasMatch(musicSyncGenerateAuthCode()), isTrue);
    });
  });

  group('apply reads the list position time back', () {
    test('a synced user list keeps its locationUpdateTime', () {
      final decoded = musicSyncApplyListData(<String, Object?>{
        'userList': [_userList('u1', updateTime: 1700000000000)],
      });
      expect(decoded.playlists.single.locationUpdateTime!.millisecondsSinceEpoch, 1700000000000);
    });
  });
}
