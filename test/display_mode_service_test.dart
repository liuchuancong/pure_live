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
      'requestedRefreshRate': 120,
      'displayId': 0,
      'width': 1080,
      'height': 2400,
    });

    expect(info.enabled, isTrue);
    expect(info.currentRefreshRate, 120.0);
    expect(info.maxRefreshRate, 120.0);
    expect(info.supportedRefreshRates, [60.0, 90.0, 120.0]);
    expect(info.requestedRefreshRate, 120.0);
    expect(info.displayId, 0);
    expect(info.width, 1080);
    expect(info.height, 2400);
  });

  test('parses Windows current and maximum monitor refresh rates', () {
    final info = DisplayModeInfo.fromMap({
      'enabled': true,
      'currentRefreshRate': 200.0,
      'maxRefreshRate': 200.0,
      'preferredRefreshRate': 200.0,
      'supportedRefreshRates': [60.0, 120.0, 165.0, 200.0],
      'requestedRefreshRate': 200.0,
      'width': 3840,
      'height': 2400,
    });

    expect(info.currentRefreshRate, 200.0);
    expect(info.maxRefreshRate, 200.0);
    expect(info.supportedRefreshRates, [60.0, 120.0, 165.0, 200.0]);
    expect(info.displayId, isNull);
    expect(info.width, 3840);
    expect(info.height, 2400);
  });
}
