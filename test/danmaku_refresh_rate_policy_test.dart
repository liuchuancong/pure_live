import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/app_refresh_rate_mode.dart';
import 'package:pure_live/common/services/display_mode_service.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

void main() {
  const display120 = DisplayModeInfo(
    enabled: true,
    currentRefreshRate: 120,
    maxRefreshRate: 120,
    preferredRefreshRate: 120,
    supportedRefreshRates: [60, 90, 120],
  );

  test('highest policy synchronizes room and PiP danmaku to the device maximum', () {
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display120,
        refreshRateMode: AppRefreshRateMode.performance,
      ),
      120,
    );
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display120,
        pip: true,
        refreshRateMode: AppRefreshRateMode.performance,
      ),
      120,
    );
  });

  test('power-saving and balanced policies retain bounded renderer budgets', () {
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display120,
        refreshRateMode: AppRefreshRateMode.powerSaving,
      ),
      60,
    );
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display120,
        pip: true,
        refreshRateMode: AppRefreshRateMode.powerSaving,
      ),
      30,
    );
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display120,
        pip: true,
        refreshRateMode: AppRefreshRateMode.balanced,
      ),
      60,
    );
  });

  test('detected non-standard maximum is preserved instead of hardcoded to 60', () {
    const display144 = DisplayModeInfo(
      enabled: true,
      currentRefreshRate: 60,
      maxRefreshRate: 144,
      preferredRefreshRate: 144,
      supportedRefreshRates: [60, 144],
    );
    expect(
      DanmakuSettingsController.resolveAdaptiveDanmakuFps(
        display144,
        refreshRateMode: AppRefreshRateMode.performance,
      ),
      144,
    );
  });
}
