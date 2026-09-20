import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Local extends Fake implements LocalInteractionController {
  @override
  final enabled = false.obs;
}

class _Room extends GetxController implements LivePlayController {
  @override
  final danmakuMessages = <LiveMessage>[].obs;
  @override
  final danmakuPresentationRevision = 0.obs;
  @override
  final localInteractionController = _Local();
  final removals = StreamController<bool Function(LiveMessage)>.broadcast(sync: true);
  @override
  Stream<bool Function(LiveMessage)> get danmakuRemovals => removals.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsService {
  @override
  final font = FontSettingsController();
  @override
  // This isolated list does not initialize playback/network services.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('danmaku-frozen-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('filter removes an evicted frozen row without resuming the list', (tester) async {
    Get.testMode = true;
    Get.put<SettingsService>(_Settings());
    Get.put(GlobalPlayerState());
    final room = Get.put<LivePlayController>(_Room()) as _Room;
    addTearDown(() async {
      await room.removals.close();
      Get.reset();
      Get.testMode = false;
    });
    LiveMessage message(String text) =>
        LiveMessage(type: LiveMessageType.chat, userName: text, message: text, color: LiveMessageColor.white);
    room.danmakuMessages.assignAll(List.generate(20, (index) => message('message-$index')));
    final key = GlobalKey<DanmakuListViewState>();
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: DanmakuListView(
            key: key,
            room: LiveRoom(roomId: 'test', platform: 'test'),
            controller: room,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(key.currentState!.userScrolling, isTrue);
    final visible = tester.widgetList<DanmakuItem>(find.byType(DanmakuItem)).toList();
    expect(visible.length, greaterThan(1));
    final blocked = visible.first.danmaku;
    final kept = visible[1].danmaku;
    final incoming = message('incoming');
    room.danmakuMessages.assignAll([incoming]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(ObjectKey(blocked)), findsOneWidget);
    room.removals.add((item) => identical(item, blocked));
    await tester.pump();
    expect(find.byKey(ObjectKey(blocked)), findsNothing);
    expect(find.byKey(ObjectKey(kept)), findsOneWidget);
    expect(find.byKey(ObjectKey(incoming)), findsNothing);
    expect(key.currentState!.userScrolling, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    room.removals.add((_) => true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
