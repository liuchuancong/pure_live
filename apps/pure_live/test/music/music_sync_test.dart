import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show MusicPlaylist;
import 'package:pure_live/modules/music/controller/music_sync_client.dart';
import 'package:pure_live/modules/music/controller/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/music_sync_data.dart';
import 'package:pure_live/modules/music/controller/music_sync_wire.dart';

void main() {
  group('codec', () {
    test('auth key derives 16 ASCII characters', () {
      final key = musicSyncAuthKey('abcd1234');
      expect(key.length, 16);
    });

    test('AES ECB round-trips', () {
      final key = musicSyncAuthKey('auth-code');
      final cipher = musicSyncAesEncrypt('lx-music connect', key);
      expect(musicSyncAesDecrypt(cipher, key), 'lx-music connect');
      expect(cipher, isNot(contains('lx-music')));
    });

    test('RSA pair round-trips an OAEP message', () {
      final pair = MusicSyncRsaKeyPair.generate();
      // The public half must be headerless base64 — the reference strips
      // PEM markers before sending it inside the auth message.
      expect(pair.publicSpkiBase64, isNot(contains('-')));
      expect(pair.privatePkcs8Base64, isNot(contains('-')));
      const secret = 'lx-music auth reply';
      expect(pair.decryptOaep(pair.encryptOaep(secret)), secret);
    });
  });

  group('wire', () {
    test('frames past 1 KiB go out gzipped behind cg_', () {
      final small = musicSyncEncodeFrame('hello');
      expect(small, 'hello');
      final big = musicSyncEncodeFrame('x' * 2048);
      expect(big.startsWith('cg_'), isTrue);
      expect(musicSyncDecodeFrame(big), 'x' * 2048);
    });

    test('request encode/parse round-trips with a callback slot', () {
      final text = musicSyncEncodeRequest('list_sync_get_sync_mode_abc', [
        'arg',
        MusicSyncRpcCallback('func_0_abc'),
      ], [1]);
      final parsed = musicSyncParseMessage(text)! as MusicSyncRpcRequest;
      expect(parsed.name, 'list_sync_get_sync_mode_abc');
      expect(parsed.args[0], 'arg');
      expect(parsed.callbackAt(1), 'func_0_abc');
      expect(parsed.reply('merge_remote_local'), jsonEncode([1, parsed.name, null, 'merge_remote_local']));
    });

    test('response frames parse', () {
      final parsed = musicSyncParseMessage(jsonEncode([1, 'n', null, <String, Object?>{'a': 1}]))! as MusicSyncRpcResponse;
      expect(parsed.error, isNull);
      expect(parsed.result, <String, Object?>{'a': 1});
      final failed = musicSyncParseMessage(jsonEncode([1, 'n', <String, Object?>{'message': 'boom'}]))! as MusicSyncRpcResponse;
      expect(failed.errorMessage, 'boom');
    });

    test('callback frames parse and answer', () {
      final parsed = musicSyncParseMessage(jsonEncode([2, 'func_0_abc', ['merge_remote_local']]))! as MusicSyncRpcCallbackRequest;
      expect(parsed.name, 'func_0_abc');
      expect(parsed.args, ['merge_remote_local']);
      expect(parsed.reply(null), jsonEncode([3, 'func_0_abc', null, null]));
    });

    test('bare ping is not a frame', () {
      expect(musicSyncParseMessage('"ping"'), isNull);
    });
  });

  group('data', () {
    const track = audio.MusicTrack(
      id: '123',
      sourceId: 'kw',
      title: 'Song',
      artist: 'Singer',
      album: 'Album',
      duration: Duration(minutes: 3, seconds: 55),
    );

    test('music info keeps the reference shape', () {
      final info = musicSyncMusicInfo(track);
      expect(info['id'], '123');
      expect(info['name'], 'Song');
      expect(info['singer'], 'Singer');
      expect(info['source'], 'kw');
      expect(info['interval'], '03:55');
      final meta = info['meta']! as Map;
      expect(meta['songId'], '123');
      expect(meta['albumName'], 'Album');
    });

    test('list data round-trips through apply', () {
      final playlist = MusicPlaylist(
        id: 'pl_1',
        name: 'List',
        tracks: const [track],
        createdAt: DateTime.now(),
        locationUpdateTime: DateTime.now(),
      );
      final data = musicSyncListDataFromState([track], [track], [playlist]);
      final decoded = musicSyncApplyListData(data);
      expect(decoded.recent.single.id, '123');
      expect(decoded.favourites.single.title, 'Song');
      expect(decoded.playlists.single.name, 'List');
      expect(decoded.playlists.single.position, 0);
      expect(decoded.playlists.single.tracks.single.id, '123');
    });

    test('partial list data patches to empty', () {
      final decoded = musicSyncApplyListData(<String, Object?>{'loveList': []});
      expect(decoded.recent, isEmpty);
      expect(decoded.favourites, isEmpty);
      expect(decoded.playlists, isEmpty);
    });

    test('md5 is the reference toMD5 shape', () {
      expect(musicSyncMd5Of(<String, Object?>{}), hasLength(32));
    });

    test('dislike rules split and join', () {
      final rules = musicSyncDislikeRulesFromLines(['singer - song', 'other']);
      expect(musicSyncDislikeLines(rules), ['singer - song', 'other']);
      expect(musicSyncDislikeLines('a\n\n b \n'), ['a', 'b']);
    });
  });

  group('client surface', () {
    test('address parsing accepts both schemes and bare hosts', () {
      final address = MusicSyncAddress.parse('http://h:1');
      expect(address?.wsScheme, 'ws');
      expect(MusicSyncAddress.parse('https://h')?.wsScheme, 'wss');
      expect(MusicSyncAddress.parse('h:2')?.httpScheme, 'http');
      expect(MusicSyncAddress.parse('ws://h'), isNull);
      expect(MusicSyncAddress.parse('  '), isNull);
    });

    test('key info round-trips', () {
      const info = MusicSyncKeyInfo(clientId: 'id', key: 'key', serverName: 'srv');
      expect(MusicSyncKeyInfo.fromJson(jsonDecode(jsonEncode(info.toJson()))).serverName, 'srv');
      expect(() => MusicSyncKeyInfo.fromJson(<String, Object?>{}), throwsFormatException);
    });
  });
}
