import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class _AudioController implements VideoController {
  @override
  final audioModeSwitching = false.obs;
  @override
  final audioOnlyState = false.obs;
  @override
  bool get isAudioOnly => audioOnlyState.value;
  int taps = 0;
  @override
  void enableController() {}
  @override
  Future<void> toggleAudioOnly() async {
    taps++;
    audioModeSwitching.value = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('both mounted surfaces observe the shared audio transition', (tester) async {
    final controller = _AudioController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AudioOnlyButton(controller: controller),
              AudioOnlyButton(controller: controller),
            ],
          ),
        ),
      ),
    );
    final buttons = find.byType(IconButton);
    for (var index = 0; index < buttons.evaluate().length; index++) {
      final size = tester.getSize(buttons.at(index));
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    }
    final originalIcon = (tester.widget<IconButton>(buttons.first).icon as Icon).icon;
    controller.audioOnlyState.value = true;
    controller.audioModeSwitching.value = true;
    await tester.pump();
    for (final button in tester.widgetList<IconButton>(buttons)) {
      expect(button.onPressed, isNull);
      expect((button.icon as Icon).icon, isNot(originalIcon));
    }
    controller.audioModeSwitching.value = false;
    await tester.pump();
    for (final button in tester.widgetList<IconButton>(buttons)) {
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('audio button reflects busy and settled state without a parent rebuild', (tester) async {
    final controller = _AudioController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AudioOnlyButton(controller: controller)),
      ),
    );
    IconButton button() => tester.widget<IconButton>(find.byType(IconButton));
    final videoIcon = (button().icon as Icon).icon;
    final videoTooltip = button().tooltip;
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'The busy flag must disable the visible control immediately.');
    await tester.tap(find.byType(IconButton));
    expect(controller.taps, 1);

    controller.audioOnlyState.value = true;
    controller.audioModeSwitching.value = false;
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect((button().icon as Icon).icon, isNot(videoIcon));
    expect(button().tooltip, isNot(videoTooltip));
    expect(button().color, const Color(0xFFFFD166));

    controller.audioOnlyState.value = false;
    await tester.pump();
    expect((button().icon as Icon).icon, videoIcon);
    expect(button().tooltip, videoTooltip);
    expect(button().color, Colors.white);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.audioModeSwitching.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio button re-enables after a failed transition without changing mode', (tester) async {
    final controller = _AudioController()..audioModeSwitching.value = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AudioOnlyButton(controller: controller)),
      ),
    );
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    controller.audioModeSwitching.value = false;
    await tester.pump();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNotNull);
  });
}
