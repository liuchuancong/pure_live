import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/audio_only_presentation.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/dummy_video_cover.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/picture_cover.dart';

void main() {
  group('画面盖子的选择', () {
    final room = LiveRoom(platform: 'missevan', roomId: '123', cover: 'https://cdn.example/c.jpg');

    test('纯音频优先：它本来就把画面盖住了，占位视频轨已经无关', () {
      expect(pictureCoverFor(audioOnly: true, dummyVideo: true, room: room), isA<AudioOnlyPresentation>());
      expect(pictureCoverFor(audioOnly: true, dummyVideo: false, room: room), isA<AudioOnlyPresentation>());
    });

    test('只有占位视频轨时显示房间封面', () {
      expect(pictureCoverFor(audioOnly: false, dummyVideo: true, room: room), isA<DummyVideoCover>());
    });

    test('两者都不成立就不给盖子，画面照常显示', () {
      expect(pictureCoverFor(audioOnly: false, dummyVideo: false, room: room), isNull);
    });

    test('没有房间就没有封面可显示', () {
      // PiP 那棵树读的是 room detail，加载完成前是 null；这时露出底下的画面，
      // 比盖一层空壳诚实。
      expect(pictureCoverFor(audioOnly: true, dummyVideo: true, room: null), isNull);
    });
  });
}
