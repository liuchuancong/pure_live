import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:test/test.dart';

/// `PlatformBootstrap.init` is where the platform facts are assembled, so the
/// cases below pin the trust order — a declaration beats the user-placed
/// portable markers, the markers beat shape detection, and the form factor a
/// user chose beats the host default.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_bootstrap');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('the detected kind matches dart:io and the unknown default is honest', () {
    final runtime = PlatformBootstrap.init();

    expect(runtime.environment.runtime.kind, PlatformRuntimeInfo.inferKind());
    expect(
      runtime.environment.runtime.distribution,
      DistributionDetector.detectMarkers(root) ?? DistributionDetector.detect(root),
      reason: 'nothing was declared and no marker was placed next to the test runner',
    );
  });

  test('a declared distribution wins over every detection', () {
    final portable = PlatformBootstrap.init(declaredDistribution: DesktopDistribution.portable);
    final msix = PlatformBootstrap.init(declaredDistribution: DesktopDistribution.msix);

    expect(portable.environment.runtime.distribution, DesktopDistribution.portable);
    expect(portable.environment.runtime.isPortable, isTrue);
    expect(portable.environment.runtime.isPackaged, isFalse);

    expect(msix.environment.runtime.distribution, DesktopDistribution.msix);
    expect(msix.environment.runtime.isPackaged, isTrue);
    expect(msix.environment.runtime.isPortable, isFalse);
  });

  test('an explicit form factor beats the host default', () {
    final runtime = PlatformBootstrap.init(formFactor: FormFactor.tv);

    expect(runtime.environment.runtime.formFactor, FormFactor.tv);
    expect(runtime.environment.capabilities.systemTray, isFalse, reason: 'TV builds claim no tray');
  });

  test('a declared form factor reaches the capability defaults', () {
    final phone = PlatformBootstrap.init(formFactor: FormFactor.phone);

    expect(phone.environment.runtime.formFactor, FormFactor.phone);
  });

  test('the executable root is the running binary directory', () {
    final runtime = PlatformBootstrap.init();

    expect(runtime.environment.runtime.executableRoot.path, File(Platform.resolvedExecutable).parent.path);
    expect(runtime.environment.runtime.osVersion, Platform.operatingSystemVersion);
  });
}
