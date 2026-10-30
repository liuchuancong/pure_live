import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_tag_writer.dart';

void main() {
  const picture = [0xFF, 0xD8, 0xFF, 0xE0, 0x10, 0x20, 0x30];

  Future<File> fileOf(String name, List<int> bytes) async {
    final dir = await Directory.systemTemp.createTemp('music_tag_writer');
    return File('${dir.path}/$name')..writeAsBytesSync(bytes);
  }

  group('writeAudioTags', () {
    test('mp3 round-trips every field', () async {
      final file = await fileOf('a.mp3', [0xFF, 0xFB, ...List.filled(64, 0x11)]);
      await writeAudioTags(
        file.path,
        MusicTagWrite(
          title: '海阔天空',
          artist: 'Beyond',
          album: '乐与怒',
          lyric: '[00:01.00]今天我',
          picture: Uint8List.fromList(picture),
        ),
      );
      final tag = await const audio.AudioTagReader().read(file);
      expect(tag.title, '海阔天空');
      expect(tag.artist, 'Beyond');
      expect(tag.album, '乐与怒');
      expect(tag.lyric, '[00:01.00]今天我');
      expect(tag.picture?.bytes, Uint8List.fromList(picture));
    });

    test('mp3 keeps untouched fields on a partial write', () async {
      final file = await fileOf('b.mp3', [0xFF, 0xFB, ...List.filled(64, 0x11)]);
      await writeAudioTags(file.path, const MusicTagWrite(title: '光辉岁月', artist: 'Beyond'));
      await writeAudioTags(file.path, const MusicTagWrite(album: '命运派对'));
      final tag = await const audio.AudioTagReader().read(file);
      expect(tag.title, '光辉岁月');
      expect(tag.artist, 'Beyond');
      expect(tag.album, '命运派对');
    });

    test('mp3 drops the picture when told empty', () async {
      final file = await fileOf('c.mp3', [0xFF, 0xFB, ...List.filled(64, 0x11)]);
      await writeAudioTags(file.path, MusicTagWrite(title: '再见理想', picture: Uint8List.fromList(picture)));
      await writeAudioTags(file.path, MusicTagWrite(picture: Uint8List(0)));
      final tag = await const audio.AudioTagReader().read(file);
      expect(tag.title, '再见理想');
      expect(tag.picture, isNull);
    });

    test('flac round-trips every field and keeps the stream', () async {
      final file = await fileOf('d.flac', [
        0x66, 0x4C, 0x61, 0x43, // fLaC
        0x80, 0x00, 0x00, 0x22, // last block, streaminfo, 34 bytes
        ...List.filled(34, 0x00),
        0xFF, 0xF8, 0x99, 0xAA, // fake audio frames
      ]);
      await writeAudioTags(
        file.path,
        MusicTagWrite(
          title: '喜欢',
          artist: '张悬',
          album: 'My Life Will…',
          lyric: '[00:01.50]词',
          picture: Uint8List.fromList(picture),
        ),
      );
      final tag = await const audio.AudioTagReader().read(file);
      expect(tag.title, '喜欢');
      expect(tag.artist, '张悬');
      expect(tag.album, 'My Life Will…');
      expect(tag.lyric, '[00:01.50]词');
      expect(tag.picture?.bytes, Uint8List.fromList(picture));
      // The audio data past the metadata blocks survives the rewrite.
      final bytes = await file.readAsBytes();
      expect(bytes.sublist(bytes.length - 4), [0xFF, 0xF8, 0x99, 0xAA]);
    });

    test('flac drops the picture block on removal', () async {
      final file = await fileOf('e.flac', [
        0x66, 0x4C, 0x61, 0x43,
        0x80, 0x00, 0x00, 0x22,
        ...List.filled(34, 0x00),
        0xFF, 0xF8, 0x99, 0xAA,
      ]);
      await writeAudioTags(file.path, MusicTagWrite(title: '宝贝', picture: Uint8List.fromList(picture)));
      await writeAudioTags(file.path, MusicTagWrite(picture: Uint8List(0)));
      final tag = await const audio.AudioTagReader().read(file);
      expect(tag.title, '宝贝');
      expect(tag.picture, isNull);
    });

    test('formats without a writer refuse', () async {
      final file = await fileOf('f.m4a', List.filled(32, 0x00));
      await expectLater(
        writeAudioTags(file.path, const MusicTagWrite(title: 'x')),
        throwsUnsupportedError,
      );
    });
  });
}
