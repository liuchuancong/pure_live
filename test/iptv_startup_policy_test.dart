import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';

void main() {
  group('IPTV startup policy', () {
    test('ordinary launches do not schedule network maintenance', () {
      expect(IptvSettingsController.shouldRunBackgroundStartupSync(iptvEnabled: true, autoSyncEnabled: false), isFalse);
      expect(IptvSettingsController.shouldRunBackgroundStartupSync(iptvEnabled: false, autoSyncEnabled: true), isFalse);
    });

    test('explicit auto-sync is eligible only while IPTV is enabled', () {
      expect(IptvSettingsController.shouldRunBackgroundStartupSync(iptvEnabled: true, autoSyncEnabled: true), isTrue);
    });

    test('sync interval owns an IPTV-specific persistence key', () {
      expect(IptvSettingsController.autoSyncHoursIntervalKey, 'autoSyncHoursInterval');
    });
  });
}
