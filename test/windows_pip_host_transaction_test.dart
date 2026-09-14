import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/player/utils/window_helper.dart';

void main() {
  const display = WindowsPipDisplay(
    id: 'primary',
    size: Size(1920, 1080),
    visiblePosition: Offset.zero,
    visibleSize: Size(1920, 1040),
  );

  WindowsPipPreferences preferences({bool alwaysOnTop = true, bool rememberPosition = true}) {
    return WindowsPipPreferences(rememberPosition: rememberPosition, alwaysOnTop: alwaysOnTop, savedDisplayId: '');
  }

  test('Windows PiP entry commits mode only after the host transition succeeds', () async {
    final host = _FakeWindowsPipHost();
    host.failOnce('setPosition');
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );

    await expectLater(helper.enterPiP(16 / 9), throwsStateError);

    expect(helper.currentMode, WindowLayoutMode.normal);
    expect(host.size, host.normalSize);
    expect(host.position, host.normalPosition);
    expect(host.minimumSize, const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight));
    expect(host.alwaysOnTop, isFalse);

    await helper.enterPiP(16 / 9);
    expect(helper.currentMode, WindowLayoutMode.pip);
  });

  test('Windows PiP exit keeps PiP mode and bounds when host restoration fails', () async {
    final host = _FakeWindowsPipHost();
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );
    await helper.enterPiP(16 / 9);
    final pipSize = host.size;
    final pipPosition = host.position;
    host.failOnce('setSize');

    await expectLater(helper.exitPiP(), throwsStateError);

    expect(helper.currentMode, WindowLayoutMode.pip);
    expect(host.size, pipSize);
    expect(host.position, pipPosition);
    expect(host.minimumSize, Size.zero);
    expect(host.alwaysOnTop, isTrue);

    await helper.exitPiP();
    expect(helper.currentMode, WindowLayoutMode.normal);
  });

  test('Windows PiP coalesces repeated direct entry requests', () async {
    final host = _FakeWindowsPipHost();
    final sizeGate = Completer<void>();
    host.setSizeGate = sizeGate;
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );

    final first = helper.enterPiP(16 / 9);
    final second = helper.enterPiP(16 / 9);
    await Future<void>.delayed(Duration.zero);

    expect(host.calls.where((call) => call == 'setSize').length, 1);
    sizeGate.complete();
    await Future.wait([first, second]);
    expect(helper.currentMode, WindowLayoutMode.pip);
  });

  test('Windows PiP coalesces repeated direct exit requests', () async {
    final host = _FakeWindowsPipHost();
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );
    await helper.enterPiP(16 / 9);
    final positionGate = Completer<void>();
    host.setPositionGate = positionGate;

    final first = helper.exitPiP();
    final second = helper.exitPiP();
    await Future<void>.delayed(Duration.zero);

    expect(host.calls.where((call) => call == 'setMinimumSize:Size(400.0, 300.0)').length, 1);
    positionGate.complete();
    await Future.wait([first, second]);
    expect(helper.currentMode, WindowLayoutMode.normal);
  });

  test('always-on-top updates finish before a queued Windows PiP exit', () async {
    final host = _FakeWindowsPipHost();
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );
    await helper.enterPiP(16 / 9);
    final alwaysOnTopGate = Completer<void>();
    host.setAlwaysOnTopGate = alwaysOnTopGate;

    final stackingUpdate = helper.setPiPAlwaysOnTop(false);
    await Future<void>.delayed(Duration.zero);
    final exiting = helper.exitPiP();
    await Future<void>.delayed(Duration.zero);

    expect(host.calls.where((call) => call == 'setMinimumSize:Size(400.0, 300.0)'), isEmpty);
    alwaysOnTopGate.complete();
    await Future.wait([stackingUpdate, exiting]);
    expect(helper.currentMode, WindowLayoutMode.normal);
  });

  test('Windows PiP exit restores the application minimum window size contract', () async {
    final host = _FakeWindowsPipHost();
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );
    await helper.enterPiP(16 / 9);

    await helper.exitPiP();

    expect(host.minimumSize, const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight));
    expect(helper.currentMode, WindowLayoutMode.normal);
  });

  test('geometry capture does not observe a partially entered Windows PiP window', () async {
    final host = _FakeWindowsPipHost();
    final readGate = Completer<void>();
    host.firstSizeReadGate = readGate;
    final writes = <Rect>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
      writeGeometry: (size, position, _) => writes.add(position & size),
    );

    final entering = helper.enterPiP(16 / 9);
    await Future<void>.delayed(Duration.zero);
    final capture = helper.capturePiPGeometry();
    await Future<void>.delayed(Duration.zero);

    expect(writes, isEmpty);
    readGate.complete();
    await Future.wait([entering, capture]);
  });

  test('desktop window events delegate normal and PiP geometry to the serialized host owner', () {
    final source = File('lib/common/global/platform/desktop_manager.dart').readAsStringSync();

    expect(source, contains('captureWindowGeometry'));
    expect(source, isNot(contains('windowManager.getSize().then(_sizeController.updateSize)')));
    expect(source, contains('Desktop window geometry capture failed:'));
  });

  test('normal window geometry persists only a restorable window size', () async {
    final host = _FakeWindowsPipHost();
    final writes = <Size>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );

    await helper.captureWindowGeometry(writes.add);
    expect(writes, [host.normalSize]);

    host
      ..minimized = true
      ..size = Size.zero;
    await helper.captureWindowGeometry(writes.add);
    host
      ..minimized = false
      ..maximized = true
      ..size = const Size(1920, 1040);
    await helper.captureWindowGeometry(writes.add);
    host
      ..maximized = false
      ..fullScreen = true
      ..size = const Size(1920, 1080);
    await helper.captureWindowGeometry(writes.add);

    expect(writes, [host.normalSize]);
  });

  test('normal geometry capture rechecks native presentation after its asynchronous size read', () async {
    final host = _FakeWindowsPipHost();
    final readGate = Completer<void>();
    host.firstSizeReadGate = readGate;
    final writes = <Size>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );

    final capture = helper.captureWindowGeometry(writes.add);
    await Future<void>.delayed(Duration.zero);
    host.maximized = true;
    readGate.complete();
    await capture;

    expect(writes, isEmpty);
  });

  test('failed normal geometry capture leaves the shared host queue retryable', () async {
    final host = _FakeWindowsPipHost()..failOnce('isMaximized');
    final writes = <Size>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
    );

    await expectLater(helper.captureWindowGeometry(writes.add), throwsStateError);
    await helper.captureWindowGeometry(writes.add);

    expect(writes, [host.normalSize]);
  });

  test('geometry capture queued behind PiP entry writes only the committed PiP rectangle', () async {
    final host = _FakeWindowsPipHost();
    final sizeGate = Completer<void>();
    host.setSizeGate = sizeGate;
    final normalWrites = <Size>[];
    final pipWrites = <Rect>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
      writeGeometry: (size, position, _) => pipWrites.add(position & size),
    );

    final entering = helper.enterPiP(16 / 9);
    await Future<void>.delayed(Duration.zero);
    final capture = helper.captureWindowGeometry(normalWrites.add);
    await Future<void>.delayed(Duration.zero);

    expect(normalWrites, isEmpty);
    expect(pipWrites, isEmpty);
    sizeGate.complete();
    await Future.wait([entering, capture]);
    expect(normalWrites, isEmpty);
    expect(pipWrites, hasLength(2));
    expect(pipWrites, everyElement(host.position & host.size));
  });

  test('geometry capture queued behind PiP exit persists only the restored normal size', () async {
    final host = _FakeWindowsPipHost();
    final normalWrites = <Size>[];
    final pipWrites = <Rect>[];
    final helper = WindowHelper.test(
      host: host.adapter(displays: const [display]),
      readPreferences: preferences,
      writeGeometry: (size, position, _) => pipWrites.add(position & size),
    );
    await helper.enterPiP(16 / 9);
    pipWrites.clear();
    final positionGate = Completer<void>();
    host.setPositionGate = positionGate;

    final exiting = helper.exitPiP();
    await Future<void>.delayed(Duration.zero);
    final capture = helper.captureWindowGeometry(normalWrites.add);
    await Future<void>.delayed(Duration.zero);

    expect(normalWrites, isEmpty);
    expect(pipWrites, isEmpty);
    positionGate.complete();
    await Future.wait([exiting, capture]);
    expect(normalWrites, [host.normalSize]);
    expect(pipWrites, isEmpty);
  });
}

class _FakeWindowsPipHost {
  final Size normalSize = const Size(1200, 700);
  final Offset normalPosition = const Offset(80, 40);
  late Size size = normalSize;
  late Offset position = normalPosition;
  Size minimumSize = const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight);
  bool alwaysOnTop = false;
  bool minimized = false;
  bool maximized = false;
  bool fullScreen = false;
  final List<String> calls = [];
  final Map<String, int> _failures = {};
  Completer<void>? setSizeGate;
  Completer<void>? setPositionGate;
  Completer<void>? setAlwaysOnTopGate;
  Completer<void>? firstSizeReadGate;
  int _sizeReads = 0;

  void failOnce(String operation) {
    _failures[operation] = 1;
  }

  WindowsPipHost adapter({required List<WindowsPipDisplay> displays}) {
    return WindowsPipHost(
      getSize: () async {
        calls.add('getSize');
        _sizeReads++;
        if (_sizeReads == 1 && firstSizeReadGate != null) {
          await firstSizeReadGate!.future;
        }
        _throwIfRequested('getSize');
        return size;
      },
      getPosition: () async {
        calls.add('getPosition');
        _throwIfRequested('getPosition');
        return position;
      },
      isAlwaysOnTop: () async {
        calls.add('isAlwaysOnTop');
        _throwIfRequested('isAlwaysOnTop');
        return alwaysOnTop;
      },
      isMinimized: () async {
        calls.add('isMinimized');
        _throwIfRequested('isMinimized');
        return minimized;
      },
      isMaximized: () async {
        calls.add('isMaximized');
        _throwIfRequested('isMaximized');
        return maximized;
      },
      isFullScreen: () async {
        calls.add('isFullScreen');
        _throwIfRequested('isFullScreen');
        return fullScreen;
      },
      getDisplays: () async {
        calls.add('getDisplays');
        _throwIfRequested('getDisplays');
        return displays;
      },
      getPrimaryDisplay: () async {
        calls.add('getPrimaryDisplay');
        _throwIfRequested('getPrimaryDisplay');
        return displays.first;
      },
      setAlwaysOnTop: (value) async {
        calls.add('setAlwaysOnTop:$value');
        _throwIfRequested('setAlwaysOnTop');
        alwaysOnTop = value;
        if (setAlwaysOnTopGate != null) await setAlwaysOnTopGate!.future;
      },
      setMinimumSize: (value) async {
        calls.add('setMinimumSize:$value');
        _throwIfRequested('setMinimumSize');
        minimumSize = value;
      },
      setSize: (value) async {
        calls.add('setSize');
        _throwIfRequested('setSize');
        size = value;
        if (setSizeGate != null) await setSizeGate!.future;
      },
      setPosition: (value) async {
        calls.add('setPosition');
        _throwIfRequested('setPosition');
        position = value;
        if (setPositionGate != null) await setPositionGate!.future;
      },
    );
  }

  void _throwIfRequested(String operation) {
    final remaining = _failures[operation] ?? 0;
    if (remaining <= 0) return;
    _failures[operation] = remaining - 1;
    throw StateError('$operation fixture failure');
  }
}
