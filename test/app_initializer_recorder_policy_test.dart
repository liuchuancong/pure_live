import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/initialized.dart';

void main() {
  test('mobile begins recorder native prewarm during startup', () {
    expect(AppInitializer.shouldStartRecorderPrewarmImmediately(mobile: true), isTrue);
    expect(AppInitializer.shouldStartRecorderPrewarmImmediately(mobile: false), isFalse);
  });
}
