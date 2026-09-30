import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class _FakeLivePlayController implements LivePlayController {
  @override
  final state = LivePlayState().obs;

  void setScreenMode(VideoMode mode) {
    state.value = LivePlayState(ui: UIState(screenMode: mode));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DragAreaController implements VideoController {
  @override
  final showLocked = false.obs;
  @override
  final livePlayController = _FakeLivePlayController();

  final setBrightnessCalls = <double>[];
  final setVolumeCalls = <double>[];
  int portraitRestores = 0;

  @override
  Future<double> brightness() async => 0.5;

  @override
  Future<double?> volume() async => 0.5;

  @override
  Future<void> setBrightness(double value) async {
    setBrightnessCalls.add(value);
  }

  @override
  Future<void> setVolume(double value) async {
    setVolumeCalls.add(value);
  }

  @override
  Future<void> exitPortraitFullScreen() async {
    portraitRestores++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('system home gesture zone resolution', () {
    test('drags starting at the bottom launcher strip are excluded', () {
      const surface = Size(800, 400);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(600, 398), surfaceSize: surface), isTrue);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(600, 352), surfaceSize: surface), isTrue);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(600, 351), surfaceSize: surface), isFalse);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(600, 200), surfaceSize: surface), isFalse);
      // Both halves keep the exclusion: brightness and volume equally lose the strip.
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(10, 390), surfaceSize: surface), isTrue);
    });

    test('small surfaces clamp the strip instead of swallowing the surface', () {
      const tiny = Size(200, 120);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(100, 110), surfaceSize: tiny), isTrue);
      expect(startsInSystemHomeGestureZone(localPosition: const Offset(100, 79), surfaceSize: tiny), isFalse);
    });

    test('degenerate surfaces never exclude', () {
      expect(startsInSystemHomeGestureZone(localPosition: Offset.zero, surfaceSize: Size.zero), isFalse);
    });
  });

  Future<_DragAreaController> pumpDragArea(WidgetTester tester) async {
    final controller = _DragAreaController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 800, height: 400, child: BrightnessVolumnDargArea(controller: controller)),
          ),
        ),
      ),
    );
    return controller;
  }

  Future<void> dragUpFrom(WidgetTester tester, Offset start) async {
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('an upward launcher drag from the bottom strip leaves volume untouched', (tester) async {
    final controller = await pumpDragArea(tester);
    final area = tester.getRect(find.byType(BrightnessVolumnDargArea));

    // Bottom-right start, exactly where the Android/iOS home gesture begins.
    await dragUpFrom(tester, Offset(area.center.dx + 100, area.bottom - 4));

    expect(
      controller.setVolumeCalls,
      isEmpty,
      reason: 'A launcher swipe starting in the home-gesture strip must not become a volume drag.',
    );
    expect(controller.setBrightnessCalls, isEmpty);
    expect(controller.portraitRestores, 0);
  });

  testWidgets('an upward drag above the strip still adjusts volume', (tester) async {
    final controller = await pumpDragArea(tester);
    final area = tester.getRect(find.byType(BrightnessVolumnDargArea));

    await dragUpFrom(tester, Offset(area.center.dx + 100, area.bottom - 64));

    expect(
      controller.setVolumeCalls,
      isNotEmpty,
      reason: 'The brightness/volume gesture must keep working outside the launcher strip.',
    );
  });

  testWidgets('an upward launcher drag from the bottom strip leaves brightness untouched', (tester) async {
    final controller = await pumpDragArea(tester);
    final area = tester.getRect(find.byType(BrightnessVolumnDargArea));

    await dragUpFrom(tester, Offset(area.center.dx - 200, area.bottom - 4));

    expect(
      controller.setBrightnessCalls,
      isEmpty,
      reason: 'A launcher swipe starting in the home-gesture strip must not become a brightness drag.',
    );
    expect(controller.setVolumeCalls, isEmpty);
    expect(controller.portraitRestores, 0);
  });

  testWidgets('a drag that only dips into the strip from above keeps its started gesture', (tester) async {
    final controller = await pumpDragArea(tester);
    final area = tester.getRect(find.byType(BrightnessVolumnDargArea));

    // Starts at mid-right and drags down INTO the strip: the start position
    // governs, so the volume keeps being adjusted.
    final gesture = await tester.startGesture(Offset(area.center.dx + 100, area.top + 100));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(controller.setVolumeCalls, isNotEmpty);
    expect(controller.portraitRestores, 0);
  });
}
