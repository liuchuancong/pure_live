import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

void main() {
  test('detects WindowsApps package executables without matching portable paths', () {
    expect(
      AppPathManager.isWindowsMsixExecutablePath(
        r'C:\Program Files\WindowsApps\PureLive_2.9.4_x64__publisher\pure_live.exe',
      ),
      isTrue,
    );
    expect(
      AppPathManager.isWindowsMsixExecutablePath(
        'C:/Program Files/WindowsApps/PureLive_2.9.4_x64__publisher/pure_live.exe',
      ),
      isTrue,
    );
    expect(AppPathManager.isWindowsMsixExecutablePath(r'D:\Soft\PureLive\pure_live.exe'), isFalse);
  });
}
