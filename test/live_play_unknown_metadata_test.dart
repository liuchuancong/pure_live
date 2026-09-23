import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class _Recorder extends Fake implements RecorderController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Interaction extends Fake implements LocalInteractionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.lazyPut<RecorderController>(() => _Recorder());
    Get.lazyPut<LocalInteractionController>(() => _Interaction());
  });
  tearDown(() => Get.reset());

  for (final hasPlaybackSource in [false, true]) {
    test('unknown metadata settles loading while playback source=$hasPlaybackSource', () {
      final room = LiveRoom(roomId: '12345', platform: 'bilibili').getLiveRoomWithError();
      final owner = LivePlayController(room: room, site: 'bilibili');
      try {
        owner.state.value = LivePlayState(
          room: RoomState(detail: room, isLoading: true),
          player: PlayerState(playUrls: hasPlaybackSource ? const ['https://media.example/live.flv'] : const []),
        );

        owner.settleUnknownRoomMetadata();

        expect(owner.state.value.room.detail, same(room));
        expect(owner.state.value.room.isLoading, isFalse);
        expect(owner.state.value.room.isLiving, hasPlaybackSource);
        expect(owner.state.value.room.success, hasPlaybackSource);
        expect(owner.state.value.room.loadError, isNotEmpty);
      } finally {
        // onInit was not invoked; close only constructor-owned reactive state.
        owner.state.close();
        owner.danmakuMessages.close();
        owner.danmakuPresentationRevision.close();
        owner.localGiftEffect.close();
        owner.superChats.close();
      }
    });
  }
}
