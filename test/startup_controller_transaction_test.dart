import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-startup-settings-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
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

  test('commits each requested startup state only after native verification', () async {
    await HivePrefUtil.setBool('enableStartUp', false);
    var nativeEnabled = false;
    var enableCalls = 0;
    var disableCalls = 0;
    final controller = StartupController(
      readStartupState: () => nativeEnabled,
      enableStartupAction: () {
        enableCalls++;
        nativeEnabled = true;
        return true;
      },
      disableStartupAction: () {
        disableCalls++;
        nativeEnabled = false;
        return true;
      },
    );

    expect(await controller.setStartupEnabled(true), isTrue);
    expect(controller.enableStartUp.value, isTrue);
    expect(controller.startupStatusKey.value, isEmpty);
    expect(enableCalls, 1);

    expect(await controller.setStartupEnabled(false), isTrue);
    expect(controller.enableStartUp.value, isFalse);
    expect(controller.startupStatusKey.value, isEmpty);
    expect(disableCalls, 1);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getBool('enableStartUp'), isFalse);
  });

  test('failed or unverifiable native changes roll the switch back to observed state', () async {
    await HivePrefUtil.setBool('enableStartUp', false);
    var nativeEnabled = false;
    final controller = StartupController(
      readStartupState: () => nativeEnabled,
      enableStartupAction: () => false,
      disableStartupAction: () => false,
    );

    expect(await controller.setStartupEnabled(true), isFalse);
    expect(controller.enableStartUp.value, isFalse);
    expect(controller.startupStatusKey.value, 'startup_apply_failed');

    final unverifiable = StartupController(
      readStartupState: () => nativeEnabled,
      enableStartupAction: () => true,
      disableStartupAction: () => true,
    );
    expect(await unverifiable.setStartupEnabled(true), isFalse);
    expect(unverifiable.enableStartUp.value, isFalse);
    expect(unverifiable.startupStatusKey.value, 'startup_apply_failed');
  });

  test('startup reconciliation repairs a missing native entry and exposes in-flight state', () async {
    await HivePrefUtil.setBool('enableStartUp', true);
    var nativeEnabled = false;
    final enableGate = Completer<bool>();
    final controller = StartupController(
      readStartupState: () => nativeEnabled,
      enableStartupAction: () async {
        final result = await enableGate.future;
        if (result) nativeEnabled = true;
        return result;
      },
      disableStartupAction: () {
        nativeEnabled = false;
        return true;
      },
    );

    final operation = controller.setupLaunchAtStartup();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isApplyingStartup.value, isTrue);
    enableGate.complete(true);
    expect(await operation, isTrue);
    expect(controller.isApplyingStartup.value, isFalse);
    expect(controller.enableStartUp.value, isTrue);
  });

  test('backup-style reactive writes still reconcile the native startup entry', () async {
    await HivePrefUtil.setBool('enableStartUp', false);
    var nativeEnabled = false;
    var enableCalls = 0;
    final controller = Get.put<StartupController>(
      _NoNetworkStartupController(
        readStartupState: () => nativeEnabled,
        enableStartupAction: () {
          enableCalls++;
          nativeEnabled = true;
          return true;
        },
        disableStartupAction: () {
          nativeEnabled = false;
          return true;
        },
      ),
    );

    controller.fromJson({'enableStartUp': true});
    await _waitFor(() => !controller.isApplyingStartup.value && enableCalls == 1);

    expect(nativeEnabled, isTrue);
    expect(controller.enableStartUp.value, isTrue);
    expect(controller.startupStatusKey.value, isEmpty);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getBool('enableStartUp'), isTrue);
  });

  test('latest request wins while each caller reports its own requested target', () async {
    await HivePrefUtil.setBool('enableStartUp', false);
    var nativeEnabled = false;
    final requests = <bool>[];
    final gates = <Completer<bool>>[];
    final controller = StartupController(
      readStartupState: () => nativeEnabled,
      enableStartupAction: () async {
        requests.add(true);
        final gate = Completer<bool>();
        gates.add(gate);
        final result = await gate.future;
        if (result) nativeEnabled = true;
        return result;
      },
      disableStartupAction: () async {
        requests.add(false);
        final gate = Completer<bool>();
        gates.add(gate);
        final result = await gate.future;
        if (result) nativeEnabled = false;
        return result;
      },
    );

    final enableResult = controller.setStartupEnabled(true);
    await _waitFor(() => requests.length == 1);
    final disableResult = controller.setStartupEnabled(false);
    gates.first.complete(true);
    await _waitFor(() => requests.length == 2);
    gates.last.complete(true);

    expect(await enableResult, isFalse);
    expect(await disableResult, isTrue);
    expect(requests, [true, false]);
    expect(controller.enableStartUp.value, isFalse);
  });
}

class _NoNetworkStartupController extends StartupController {
  _NoNetworkStartupController({
    required super.readStartupState,
    required super.enableStartupAction,
    required super.disableStartupAction,
  });

  @override
  Future<void> loadHuyaUa() async {}
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the startup transaction.');
}
