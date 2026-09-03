import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

LiveRoom room({
  required String id,
  required String platform,
  String popularity = '',
  String online = '',
  String total = '',
  AudienceMetricType? metricType,
}) {
  return LiveRoom(
    roomId: id,
    platform: platform,
    watching: popularity.isNotEmpty ? popularity : (total.isNotEmpty ? total : online),
    popularity: popularity,
    onlineViewers: online,
    totalViewers: total,
    audienceMetricType: metricType,
  );
}

void main() {
  test('popular heat mode sorts native platform values descending', () {
    final ranked = rankPopularRoomsByAudience(
      [
        room(id: 'low', platform: 'cc', popularity: '100', online: '900'),
        room(id: 'high', platform: 'cc', popularity: '300', online: '10'),
      ],
      preferRealOnline: false,
      realOnlinePlatforms: const ['cc'],
    );

    expect(ranked.map((item) => item.roomId), ['high', 'low']);
  });

  test('popular online mode sorts explicit concurrent viewers descending', () {
    final ranked = rankPopularRoomsByAudience(
      [
        room(id: 'heat-first', platform: 'cc', popularity: '500000', online: '15'),
        room(id: 'online-first', platform: 'cc', popularity: '200000', online: '376'),
        room(id: 'pending', platform: 'cc', popularity: '900000'),
      ],
      preferRealOnline: true,
      realOnlinePlatforms: const ['cc'],
    );

    expect(ranked.map((item) => item.roomId), ['online-first', 'heat-first', 'pending']);
  });

  test('unsupported heat platforms remain ordered by their native metric', () {
    final ranked = rankPopularRoomsByAudience(
      [
        room(id: 'one', platform: 'douyu', popularity: '2.8万'),
        room(id: 'two', platform: 'douyu', popularity: '350万'),
      ],
      preferRealOnline: true,
      realOnlinePlatforms: const ['douyin', 'cc'],
    );

    expect(ranked.map((item) => item.roomId), ['two', 'one']);
  });
}
