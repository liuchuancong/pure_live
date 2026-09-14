import 'dart:async';

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
}

class _FakeWindowsPipHost {
  final Size normalSize = const Size(1200, 700);
  final Offset normalPosition = const Offset(80, 40);
  late Size size = normalSize;
  late Offset position = normalPosition;
  Size minimumSize = const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight);
  bool alwaysOnTop = false;
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
