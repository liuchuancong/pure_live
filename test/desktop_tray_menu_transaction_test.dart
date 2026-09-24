import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

void main() {
  test('desktop tray context menu has one event owner and one transaction coordinator', () {
    final source = File('lib/common/global/platform/desktop_manager.dart').readAsStringSync();
    final service = File('lib/common/global/platform/desktop_tray_service.dart').readAsStringSync();

    expect(source, contains('class DesktopTrayMenuCoordinator'));
    expect(source, contains('final DesktopTrayMenuCoordinator _trayMenuCoordinator'));
    expect(source, contains('onRightClick: handleTrayRightClick'));
    expect(service, contains('ContextMenuTrigger.none'));
    expect(service, contains('event is TrayIconRightClickedEvent'));
    expect(service, contains('if (_icon != null) return;'));
  });

  test('concurrent context-menu requests share refresh and popup work', () async {
    final coordinator = DesktopTrayMenuCoordinator();
    final refreshGate = Completer<void>();
    var refreshCalls = 0;
    var openCalls = 0;

    Future<void> refresh() async {
      refreshCalls++;
      await refreshGate.future;
    }

    Future<void> open() async => openCalls++;

    final first = coordinator.show(refresh: refresh, open: open);
    final second = coordinator.show(refresh: refresh, open: open);
    expect(identical(first, second), isTrue);
    expect(refreshCalls, 1);
    expect(openCalls, 0);

    refreshGate.complete();
    await Future.wait([first, second]);
    expect(refreshCalls, 1);
    expect(openCalls, 1);
  });

  test('failed context-menu transaction releases the gate for retry', () async {
    final coordinator = DesktopTrayMenuCoordinator();
    var refreshCalls = 0;
    var openCalls = 0;

    await expectLater(
      coordinator.show(
        refresh: () async => refreshCalls++,
        open: () async {
          openCalls++;
          throw StateError('tray popup fixture failure');
        },
      ),
      throwsStateError,
    );
    await coordinator.show(refresh: () async => refreshCalls++, open: () async => openCalls++);

    expect(refreshCalls, 2);
    expect(openCalls, 2);
  });
}
