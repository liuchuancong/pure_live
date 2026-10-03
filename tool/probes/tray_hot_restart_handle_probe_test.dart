// Opt-in native probe, deliberately outside the ordinary offline test suite.
// A Windows hot restart kills the owning Dart isolate without running its
// finalizers, so the process-wide native handle table keeps the old tray icon
// registered with the shell and the next isolate adds a second one. This probe
// reproduces that topology: the test isolate owns a visible tray icon and
// leaks it the way a dead isolate would, then a second isolate picks the
// handle up and releases it exactly as DesktopTrayService now does at startup.
// The native library only ships inside the built runner, so put the runner
// debug dir on PATH and run from the repository root:
//   PATH=build/windows/x64/runner/Debug;%PATH% flutterw test tool/probes/tray_hot_restart_handle_probe_test.dart
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  test('orphaned native tray handle crosses isolates and its release removes the icon', () async {
    final created = TrayIcon.create();
    expect(created, isNotNull, reason: 'native tray icon creation failed');
    final icon = created!;
    addTearDown(icon.dispose);

    final image = Image.fromFile('assets/icons/icon.png');
    if (image != null) {
      addTearDown(image.dispose);
      icon.icon = image;
    }
    expect(icon.setVisible(true), isTrue, reason: 'native tray icon could not be shown');
    final handle = icon.nativeHandle;

    final port = ReceivePort();
    addTearDown(port.close);
    final sweeper = await Isolate.spawn(_sweepEntrypoint, [port.sendPort, handle]);
    addTearDown(sweeper.kill);
    final report = await port.first as Map<String, bool>;

    // The owner side stays leaked until here, matching a dead isolate: the
    // handle survived only inside the native handle table.
    expect(report['visibleBeforeSweep'], isTrue, reason: 'handle did not resolve outside its owner isolate');
    expect(report['visibleAfterSweep'], isFalse, reason: 'releasing the orphaned handle kept the tray icon');
  });
}

void _sweepEntrypoint(List<Object> args) {
  final sendPort = args[0] as SendPort;
  final handle = args[1] as int;
  final visibleBefore = TrayIcon.borrowed(handle).isVisible();
  TrayIcon.borrowed(handle).dispose();
  final visibleAfter = TrayIcon.borrowed(handle).isVisible();
  sendPort.send({'visibleBeforeSweep': visibleBefore, 'visibleAfterSweep': visibleAfter});
}
