import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

void main() {
  group('refresh settings migration', () {
    test('keeps automatic thumbnail refresh opt-in for older backups', () {
      final config = RefreshConfigController.extractConfig({
        'refresh': {'autoRefreshFavorite': true},
      });

      expect(config['autoRefreshFavorite'], isTrue);
      expect(config['refreshFavoriteOnResume'], isTrue);
      expect(config['autoRefreshThumbnails'], isFalse);
      expect(config['thumbnailRefreshInterval'], 30);
      expect(config['maxConcurrentRefresh'], RefreshConfigController.defaultMaxConcurrentRefresh);
    });

    test('preserves unrelated refresh and root settings', () {
      final root = <String, dynamic>{
        'refresh': {'autoRefreshFavorite': true},
        'player': {'engine': 'mediaKit'},
      };

      final merged = RefreshConfigController.mergeConfig(root, {
        'autoRefreshThumbnails': true,
        'thumbnailRefreshInterval': 60,
      });

      expect(merged['player'], {'engine': 'mediaKit'});
      expect(merged['refresh']['autoRefreshFavorite'], isTrue);
      expect(merged['refresh']['autoRefreshThumbnails'], isTrue);
      expect(merged['refresh']['thumbnailRefreshInterval'], 60);
    });

    test('normalizes invalid concurrency without hiding advanced values', () {
      expect(RefreshConfigController.normalizeMaxConcurrentRefresh(0), 1);
      expect(RefreshConfigController.normalizeMaxConcurrentRefresh(6), 6);
      expect(
        RefreshConfigController.normalizeMaxConcurrentRefresh(99),
        RefreshConfigController.maxAllowedConcurrentRefresh,
      );
    });
  });
}
