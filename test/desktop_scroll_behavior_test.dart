import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_controller.dart';
import 'package:scroll_animator/scroll_animator.dart';

void main() {
  test('MyCustomScrollBehavior supports trackpad and mouse drag scrolling', () {
    final behavior = MyCustomScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, contains(PointerDeviceKind.invertedStylus));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
  });

  test('Windows wheel scrolling uses an animated scroll position', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = createPureLiveScrollController();
    addTearDown(controller.dispose);
    expect(controller, isA<AnimatedScrollController>());
  });

  test('Android touch scrolling keeps the native scroll controller', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = createPureLiveScrollController();
    addTearDown(controller.dispose);
    expect(controller, isNot(isA<AnimatedScrollController>()));
  });
}
