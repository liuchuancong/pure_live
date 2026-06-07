import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

void main() {
  test('MyCustomScrollBehavior supports trackpad and mouse drag scrolling', () {
    final behavior = MyCustomScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, contains(PointerDeviceKind.invertedStylus));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
  });
}
