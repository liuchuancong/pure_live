import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('log files always live in the nested LOGS log directory', () {
    expect(
      AppPathManager.logFilesDirectoryPath(p.join('root', AppPathManager.dirLogs)),
      p.join('root', AppPathManager.dirLogs, 'log'),
    );
  });
}
