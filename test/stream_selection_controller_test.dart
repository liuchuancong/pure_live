import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

void main() {
  test('selection policy clamps stale quality and line indices', () {
    expect(
      resolveStreamSelection(
        qualityCount: 3,
        playUrlCount: 2,
        requestedQualityIndex: 9,
        requestedLineIndex: 7,
      ),
      isA<StreamSelection>()
          .having((value) => value.isValid, 'isValid', isTrue)
          .having((value) => value.qualityIndex, 'quality', 2)
          .having((value) => value.lineIndex, 'line', 1),
    );
    expect(
      resolveStreamSelection(
        qualityCount: 0,
        playUrlCount: 2,
        requestedQualityIndex: 0,
        requestedLineIndex: 0,
      ).isValid,
      isFalse,
    );
  });

  test('server acknowledged quality overrides the tapped label', () {
    final qualities = [
      LivePlayQuality(quality: '原画', id: 10000, data: 10000),
      LivePlayQuality(quality: '蓝光', id: 400, data: 400),
      LivePlayQuality(quality: '超清', id: 250, data: 250),
    ];

    expect(
      resolveAppliedQualityIndex(qualities: qualities, requestedIndex: 0, appliedQualityData: 250),
      2,
    );
    expect(
      resolveAppliedQualityIndex(qualities: qualities, requestedIndex: 1, appliedQualityData: null),
      1,
    );
  });

  test('quality metadata uses stable ids and drops duplicate choices', () {
    final qualities = normalizePlayQualities([
      LivePlayQuality(quality: '原画', id: 0, data: const ['source']),
      LivePlayQuality(quality: '重复原画', id: 0, data: const ['duplicate']),
      LivePlayQuality(quality: '流畅', id: 500, data: const ['smooth']),
      LivePlayQuality(quality: '   ', id: 2000),
    ]);

    expect(qualities.map((quality) => quality.quality), ['原画', '流畅']);
    expect(qualities.map((quality) => quality.selectionId), [0, 500]);
    expect(hasSameStreamChoices(const ['a', 'b'], const ['b', 'a']), isTrue);
    expect(hasSameStreamChoices(const ['a'], const ['a?ratio=500']), isFalse);
    expect(normalizeResolvedPlayUrls(const [' a ', '', 'a', 'b']), const ['a', 'b']);
  });

  test('duplicate visible labels are numbered without changing stable ids', () {
    final qualities = normalizePlayQualities([
      LivePlayQuality(quality: '高清', id: 'hd-1'),
      LivePlayQuality(quality: '高清', id: 'hd-2'),
    ]);

    expect(qualities.map((quality) => quality.quality), ['高清 1', '高清 2']);
    expect(qualities.map((quality) => quality.selectionId), ['hd-1', 'hd-2']);
  });

  test('quality switch keeps old state until URLs resolve and clamps the new line', () async {
    final room = LiveRoom(roomId: 'room', platform: 'test');
    final siteImpl = _SelectionLiveSite();
    final host = _SelectionHost(room);
    final opened = <_OpenedStream>[];
    final controller = PlayerController(
      host,
      streamSourceOpener: (url, urls, headers, openedRoom, audioOnly) async {
        opened.add(_OpenedStream(url, urls, openedRoom, audioOnly));
      },
    )..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: siteImpl));

    final switching = controller.switchStreamSelection(
      type: ReloadDataType.changeQuality,
      qualityIndex: 1,
      lineIndex: 8,
    );
    expect(
      host.state.value.player.currentQuality,
      0,
      reason: 'the old source stays active while the URL resolves',
    );
    expect(controller.isStreamSwitching.value, isTrue);

    siteImpl.qualityUrls.complete(const ['https://new/one', 'https://new/two']);
    expect(await switching, isTrue);

    final state = host.state.value.player;
    expect(state.currentQuality, 1);
    expect(state.currentLineIndex, 1);
    expect(state.playUrls, const ['https://new/one', 'https://new/two']);
    expect(state.hasUseDefaultResolution, isTrue);
    expect(opened.single.url, 'https://new/two');
    expect(opened.single.room, same(room));
    expect(controller.isStreamSwitching.value, isFalse);
  });

  test('line switch reuses current URLs without refetching quality metadata', () async {
    final room = LiveRoom(roomId: 'room', platform: 'test');
    final siteImpl = _SelectionLiveSite();
    final host = _SelectionHost(room);
    final opened = <_OpenedStream>[];
    final controller = PlayerController(
      host,
      streamSourceOpener: (url, urls, headers, openedRoom, audioOnly) async {
        opened.add(_OpenedStream(url, urls, openedRoom, audioOnly));
      },
    )..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: siteImpl));

    expect(
      await controller.switchStreamSelection(
        type: ReloadDataType.changeLine,
        qualityIndex: 0,
        lineIndex: 1,
      ),
      isTrue,
    );

    expect(siteImpl.playUrlCalls, 0);
    expect(opened.single.url, 'https://old/two');
    expect(host.state.value.player.currentLineIndex, 1);
  });

  test('failed player open rolls quality, line and URL state back atomically', () async {
    final room = LiveRoom(roomId: 'room', platform: 'test');
    final siteImpl = _SelectionLiveSite();
    final host = _SelectionHost(room);
    final controller = PlayerController(
      host,
      streamSourceOpener: (url, urls, headers, openedRoom, audioOnly) async {
        throw StateError('decoder rejected source');
      },
    )..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: siteImpl));

    final switching = controller.switchStreamSelection(
      type: ReloadDataType.changeQuality,
      qualityIndex: 1,
      lineIndex: 1,
    );
    siteImpl.qualityUrls.complete(const ['https://new/one', 'https://new/two']);

    expect(await switching, isFalse);
    expect(host.state.value.player.currentQuality, 0);
    expect(host.state.value.player.currentLineIndex, 0);
    expect(host.state.value.player.playUrls, const ['https://old/one', 'https://old/two']);
    expect(controller.isStreamSwitching.value, isFalse);
  });

  test('a different label resolving to the same stream is not committed', () async {
    final room = LiveRoom(roomId: 'room', platform: 'test');
    final siteImpl = _SelectionLiveSite();
    final host = _SelectionHost(room);
    var openCalls = 0;
    final controller = PlayerController(
      host,
      streamSourceOpener: (url, urls, headers, openedRoom, audioOnly) async {
        openCalls++;
      },
    )..initSite(Site(id: 'test', name: 'Test', logo: '', liveSite: siteImpl));

    final switching = controller.switchStreamSelection(
      type: ReloadDataType.changeQuality,
      qualityIndex: 1,
      lineIndex: 0,
    );
    siteImpl.qualityUrls.complete(const ['https://old/two', 'https://old/one']);

    expect(await switching, isFalse);
    expect(openCalls, 0);
    expect(host.state.value.player.currentQuality, 0);
  });
}

class _SelectionLiveSite extends LiveSite {
  final Completer<List<String>> qualityUrls = Completer<List<String>>();
  int playUrlCalls = 0;

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) {
    playUrlCalls++;
    return qualityUrls.future;
  }
}

class _SelectionHost implements PlayerSessionHost {
  _SelectionHost(LiveRoom room)
    : state = LivePlayState(
        room: RoomState(detail: room, success: true, isLiving: true),
        player: PlayerState(
          qualites: [
            LivePlayQuality(quality: '高清'),
            LivePlayQuality(quality: '原画'),
          ],
          currentQuality: 0,
          playUrls: const ['https://old/one', 'https://old/two'],
          currentLineIndex: 0,
        ),
      ).obs;

  @override
  final Rx<LivePlayState> state;

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
    state.value = state.value.copyWith(
      player: state.value.player.copyWith(
        videoController: resolveVideoControllerUpdate(
          current: state.value.player.videoController,
          next: videoController,
          clear: clearVideoController,
        ),
        qualites: qualites,
        currentQuality: currentQuality,
        playUrls: playUrls,
        currentLineIndex: currentLineIndex,
        isCurrentRoomAudioOnly: isCurrentRoomAudioOnly,
        hasUseDefaultResolution: hasUseDefaultResolution,
      ),
    );
  }

  @override
  void updateRoom({
    LiveRoom? detail,
    bool? isLiving,
    bool? success,
    bool? isLoading,
    String? loadError,
  }) {
    state.value = state.value.copyWith(
      room: state.value.room.copyWith(
        detail: detail,
        isLiving: isLiving,
        success: success,
        isLoading: isLoading,
        loadError: loadError,
      ),
    );
  }
}

class _OpenedStream {
  const _OpenedStream(this.url, this.urls, this.room, this.audioOnly);

  final String url;
  final List<String> urls;
  final LiveRoom room;
  final bool audioOnly;
}
