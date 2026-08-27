import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vendored Android renderer follows the replaceable Surface contract', () {
    final source = File(
      'third_party/media_kit_video/android/src/main/java/com/alexmercerind/media_kit_video/VideoOutput.java',
    ).readAsStringSync();

    expect(source, contains('final Surface currentSurface = surfaceProducer.getSurface()'));
    expect(source, contains('currentSurface != referencedSurface'));
    expect(source, contains('surfaceProducer.setCallback(null)'));
    expect(source, isNot(contains('surfaceProducer.getSurface().release()')));
    expect(source, isNot(contains('deletedGlobalObjectRefs')));
  });
}
