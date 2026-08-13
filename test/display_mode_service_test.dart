import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/display_mode_service.dart';

void main() {
  test('parses Android display mode information', () {
    final info = DisplayModeInfo.fromMap({
      'enabled': true,
      'currentRefreshRate': 120,
      'maxRefreshRate': 120.0,
      'preferredRefreshRate': 120,
      'supportedRefreshRates': [60, 90.0, 120],
      'width': 1080,
      'height': 2400,
    });

    expect(info.enabled, isTrue);
    expect(info.currentRefreshRate, 120.0);
    expect(info.maxRefreshRate, 120.0);
    expect(info.supportedRefreshRates, [60.0, 90.0, 120.0]);
    expect(info.width, 1080);
    expect(info.height, 2400);
  });
}
