import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/live_audio_service.dart';

void main() {
  test('notification metadata keeps room title and streamer in their intended fields', () {
    final item = LiveAudioService.buildMediaItem(
      roomId: 'room-1',
      title: '直播标题',
      author: '主播名称',
      cover: 'https://example.com/cover.jpg',
    );

    expect(item.id, 'room-1');
    expect(item.title, '直播标题');
    expect(item.artist, '主播名称');
    expect(item.artUri, Uri.parse('https://example.com/cover.jpg'));
  });
}
