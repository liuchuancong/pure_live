import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-log-settings-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });

  tearDown(() async {
    Get.deleteAll(force: true);
    Get.reset();
    await HivePrefUtil.flush();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('runtime log endpoint never restores a stale address from Hive', () async {
    await HivePrefUtil.setString('user_log_address', '192.168.1.99');
    await HivePrefUtil.setInt('user_log_port', 45678);

    final controller = LogController(applyLogStatus: (_) async => true);

    expect(controller.serverAddress.value, isEmpty);
    expect(controller.serverPort.value, 0);
  });

  test('logging state commits only after the asynchronous action succeeds', () async {
    final gate = Completer<bool>();
    final controller = Get.put(LogController(applyLogStatus: (_) => gate.future));

    final operation = controller.setLoggingEnabled(true);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isApplyingLogStatus.value, isTrue);
    expect(controller.storedEnableLog.value, isFalse);
    gate.complete(true);

    expect(await operation, isTrue);
    expect(controller.isApplyingLogStatus.value, isFalse);
    expect(controller.storedEnableLog.value, isTrue);
    expect(controller.logStatusKey.value, isEmpty);
  });

  test('failed enable rolls back and a verified disable clears the runtime endpoint', () async {
    var succeeds = false;
    final controller = Get.put(LogController(applyLogStatus: (_) async => succeeds));

    expect(await controller.setLoggingEnabled(true), isFalse);
    expect(controller.storedEnableLog.value, isFalse);
    expect(controller.logStatusKey.value, 'local_log_apply_failed');

    succeeds = true;
    expect(await controller.setLoggingEnabled(true), isTrue);
    controller.updateServerInfo('127.0.0.1', 45678);
    expect(await controller.setLoggingEnabled(false), isTrue);
    expect(controller.serverAddress.value, isEmpty);
    expect(controller.serverPort.value, 0);
  });

  test('legacy direct reactive writes still use the verified transaction', () async {
    var calls = 0;
    final controller = Get.put(
      LogController(
        applyLogStatus: (enabled) async {
          calls++;
          return false;
        },
      ),
    );

    controller.storedEnableLog.value = true;
    await _waitFor(() => !controller.isApplyingLogStatus.value && calls == 1);

    expect(controller.storedEnableLog.value, isFalse);
    expect(controller.logStatusKey.value, 'local_log_apply_failed');
  });

  test('latest request wins while each caller reports its own requested target', () async {
    final requests = <bool>[];
    final gates = <Completer<bool>>[];
    final controller = Get.put(
      LogController(
        applyLogStatus: (enabled) {
          requests.add(enabled);
          final gate = Completer<bool>();
          gates.add(gate);
          return gate.future;
        },
      ),
    );

    final enableResult = controller.setLoggingEnabled(true);
    await _waitFor(() => requests.length == 1);
    final disableResult = controller.setLoggingEnabled(false);
    gates.first.complete(true);
    await _waitFor(() => requests.length == 2);
    gates.last.complete(true);

    expect(await enableResult, isFalse);
    expect(await disableResult, isTrue);
    expect(requests, [true, false]);
    expect(controller.storedEnableLog.value, isFalse);
  });

  test('browser log server binds to a loopback address', () {
    expect(Log.logServerBindAddress.isLoopback, isTrue);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the logging transaction.');
}
