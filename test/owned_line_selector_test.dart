import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/line_selector.dart';
import 'package:pure_live/player/core/playback_source.dart';

void main() {
  for (final owned in [false, true]) {
    testWidgets('line selector renders and selects logical lines (owned=$owned)', (tester) async {
      Get.testMode = true;
      final host = _Host(owned);
      Get.put<LivePlayController>(host);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        host.playerController.onClose();
        Get.reset();
        Get.testMode = false;
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: LineSelector(controller: host),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<int>), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<int>), findsNWidgets(owned ? 1 : 2));
      await tester.tap(find.byType(PopupMenuItem<int>).first);
      await tester.pumpAndSettle();
      expect(host.selected, [0]);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Host extends GetxController implements LivePlayController {
  _Host(bool owned)
    : state = LivePlayState(
        room: RoomState(
          detail: LiveRoom(roomId: 'widget', platform: 'fixture'),
          success: true,
        ),
        player: PlayerState(
          qualites: [LivePlayQuality(quality: 'fixture')],
          playUrls: owned ? const [] : const ['https://fixture/one', 'https://fixture/two'],
          ownedSource: owned
              ? OwnedPlaybackSource(identity: 'fixture', createInput: (_) => throw StateError('no native allocation'))
              : null,
        ),
      ).obs;
  @override
  final Rx<LivePlayState> state;
  @override
  late final PlayerController playerController = PlayerController(this);
  final selected = <int>[];
  @override
  Future<void> setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) async =>
      selected.add(lineIndex);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateUI) return null;
    return super.noSuchMethod(invocation);
  }
}
