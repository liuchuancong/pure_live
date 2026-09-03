import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

void main() {
  test('a late quality response cannot mutate a room after its load is invalidated', () async {
    final roomA = LiveRoom(roomId: 'room-a', platform: 'test');
    final roomB = LiveRoom(roomId: 'room-b', platform: 'test');
    final liveSite = _DeferredLiveSite();
    final site = Site(id: 'test', name: 'Test', logo: '', liveSite: liveSite);
    final host = _TestPlayerHost(roomA);
    final controller = PlayerController(host)..initSite(site);

    final oldLoad = controller.getPlayQualites();
    host.setRoom(roomB);
    controller.invalidateLoad();
    liveSite.qualities.complete([LivePlayQuality(quality: 'source')]);
    await oldLoad;

    expect(host.playerUpdateCount, 0);
    expect(host.roomUpdateCount, 0);
    expect(liveSite.playUrlCalls, 0);
    expect(host.state.value.room.detail?.roomId, 'room-b');
  });
}

class _DeferredLiveSite extends LiveSite {
  final Completer<List<LivePlayQuality>> qualities = Completer<List<LivePlayQuality>>();
  int playUrlCalls = 0;

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) => qualities.future;

  @override
  Future<List<String>> getPlayUrls({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    playUrlCalls++;
    return const ['https://example.invalid/live.flv'];
  }
}

class _TestPlayerHost implements PlayerSessionHost {
  _TestPlayerHost(LiveRoom room) : state = LivePlayState(room: RoomState(detail: room)).obs;

  @override
  final Rx<LivePlayState> state;

  int playerUpdateCount = 0;
  int roomUpdateCount = 0;

  void setRoom(LiveRoom room) {
    state.value = state.value.copyWith(room: state.value.room.copyWith(detail: room));
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> setCurrentRoomAudioOnlyFromUser(bool value) async {}

  @override
  void updatePlayer({
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  }) {
    playerUpdateCount++;
  }

  @override
  void updateRoom({
    LiveRoom? detail,
    bool? isLiving,
    bool? success,
    bool? isLoading,
    String? loadError,
  }) {
    roomUpdateCount++;
  }
}
