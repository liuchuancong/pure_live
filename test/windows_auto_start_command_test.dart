import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/win_auto_start.dart';

void main() {
  test('startup registry command must target the current executable', () {
    const executable = r'C:\Apps\Pure Live\pure_live.exe';

    expect(WindowsAutoStart.commandTargetsExecutable(r'"C:\Apps\Pure Live\pure_live.exe"', executable), isTrue);
    expect(
      WindowsAutoStart.commandTargetsExecutable(r'"c:/apps/pure live/PURE_LIVE.EXE" --background', executable),
      isTrue,
    );
    expect(
      WindowsAutoStart.commandTargetsExecutable(
        r'C:\PureLive\pure_live.exe --background',
        r'C:\PureLive\pure_live.exe',
      ),
      isTrue,
    );
    expect(WindowsAutoStart.commandTargetsExecutable(r'"C:\Old\pure_live.exe"', executable), isFalse);
    expect(WindowsAutoStart.commandTargetsExecutable('', executable), isFalse);
    expect(WindowsAutoStart.commandTargetsExecutable(null, executable), isFalse);
  });
}
