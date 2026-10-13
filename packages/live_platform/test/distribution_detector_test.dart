import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// `DistributionDetector` is allowed to say only one thing with confidence: MSIX,
/// recognised from the per-user package container. Everything else must stay
/// `unknown`, because guessing portable mode from a folder name is how an installed
/// build starts writing next to its own executable.
void main() {
  DesktopDistribution detectFrom(String path) => DistributionDetector.detect(Directory(path));

  test('a path that merely looks portable is not guessed', () {
    expect(detectFrom('D:/Games/PureLive Portable/App'), DesktopDistribution.unknown);
    expect(detectFrom('/home/user/build/portable/out'), DesktopDistribution.unknown);
  });

  test('an ordinary installed layout is not guessed either', () {
    expect(detectFrom('C:/Program Files/Pure Live'), DesktopDistribution.unknown);
    expect(detectFrom('/usr/lib/pure_live'), DesktopDistribution.unknown);
  });

  test('the MSIX package container is recognised', () {
    // A synthetic container path is enough: the rule reads the path shape, not the
    // filesystem, so this runs on a Windows CI without an actual package install.
    const container = 'C:/Users/x/AppData/Local/Packages/PureLive_1.0.0.0_x64__zwgq89r223isg/RP/pure_live.exe';

    expect(detectFrom(container), DesktopDistribution.msix);
  }, skip: Platform.isWindows ? false : 'the detector only inspects Windows path shapes');

  test('the container keyword alone is not enough', () {
    // `Packages` with nothing after it, and `Packages` that is not under the user's
    // local app data, are both ordinary directories and must stay unknown.
    expect(detectFrom('C:/Users/x/AppData/Local/Packages'), DesktopDistribution.unknown);
    expect(detectFrom('D:/Packages/PureLive/RP'), DesktopDistribution.unknown);
  });
}
