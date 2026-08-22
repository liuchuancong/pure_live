import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';

void main() {
  test('font manager and downloader share the canonical fonts directory', () {
    expect(AppPathManager.fontDirectoryName, 'fonts');
    expect(
      AppPathManager.fontFamilyFolderPath(p.join('root', 'DOWNLOADS'), 'source-han-sans'),
      p.join('root', 'DOWNLOADS', 'fonts', 'source-han-sans'),
    );
  });

  test('backup migration preserves independent UI and danmaku font files', () {
    final config = FontSettingsController.extractConfig({
      'font': <String, dynamic>{
        'fontFamilyName': 'judousansui',
        'fontFamilyFileName': 'JudouSansUiHans-Regular.ttf',
        'danmakuFontFamilyFileName': 'JudouSansUiHans-Bold.ttf',
      },
    });

    expect(config['fontFamilyFileName'], 'JudouSansUiHans-Regular.ttf');
    expect(config['danmakuFontFamilyFileName'], 'JudouSansUiHans-Bold.ttf');
  });
}
