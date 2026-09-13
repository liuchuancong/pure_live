import 'dart:async';
import 'dart:developer' as dev;

import 'package:pure_live/common/global/win_auto_start.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/get/get.dart';

typedef StartupStateReader = FutureOr<bool> Function();
typedef StartupStateWriter = FutureOr<bool> Function();

class StartupController extends GetxController {
  StartupController({
    StartupStateReader? readStartupState,
    StartupStateWriter? enableStartupAction,
    StartupStateWriter? disableStartupAction,
  }) : _readStartupState = readStartupState ?? WindowsAutoStart.isEnabled,
       _enableStartupAction = enableStartupAction ?? WindowsAutoStart.enable,
       _disableStartupAction = disableStartupAction ?? WindowsAutoStart.disable;

  final StartupStateReader _readStartupState;
  final StartupStateWriter _enableStartupAction;
  final StartupStateWriter _disableStartupAction;

  final RxBool enableStartUp = hiveBool('enableStartUp', true);
  final RxBool isApplyingStartup = false.obs;
  final RxString startupStatusKey = ''.obs;

  Worker? _settingWorker;
  Future<bool>? _activeOperation;
  bool? _pendingTarget;
  bool? _internalWrite;
  bool? _lastConfirmedEnabled;

  @override
  void onInit() {
    super.onInit();
    _lastConfirmedEnabled = enableStartUp.v;
    _settingWorker = ever<bool>(enableStartUp, (value) {
      if (_internalWrite == value) {
        _internalWrite = null;
        return;
      }
      unawaited(setStartupEnabled(value));
    });
    loadHuyaUa();
  }

  Future<void> loadHuyaUa() async {
    await HuyaSite().getHuYaUA();
  }

  Future<bool> setupLaunchAtStartup() => setStartupEnabled(enableStartUp.v);

  Future<bool> setStartupEnabled(bool enabled) {
    _pendingTarget = enabled;
    final active = _activeOperation;
    if (active != null) {
      return active.then((_) => _lastConfirmedEnabled == enabled && startupStatusKey.v.isEmpty);
    }

    late final Future<bool> operation;
    operation = _drainStartupRequests().whenComplete(() {
      if (identical(_activeOperation, operation)) _activeOperation = null;
    });
    _activeOperation = operation;
    return operation;
  }

  Future<bool> _drainStartupRequests() async {
    if (!isClosed) isApplyingStartup.v = true;
    var result = true;
    try {
      while (_pendingTarget != null) {
        final target = _pendingTarget!;
        _pendingTarget = null;
        result = await _applyStartupTarget(target);
      }
      return result;
    } finally {
      if (!isClosed) isApplyingStartup.v = false;
    }
  }

  Future<bool> _applyStartupTarget(bool enabled) async {
    final previous = _lastConfirmedEnabled ?? enableStartUp.v;
    bool? observed;
    try {
      observed = await Future<bool>.sync(_readStartupState);
      if (observed != enabled) {
        await Future<bool>.sync(enabled ? _enableStartupAction : _disableStartupAction);
        observed = await Future<bool>.sync(_readStartupState);
      }
      if (observed != enabled) return _recordFailure(observed, previous);
      _commitVerifiedState(enabled);
      if (!isClosed) startupStatusKey.v = '';
      return true;
    } catch (error, stackTrace) {
      dev.log('Auto-start transaction failed: $error', error: error, stackTrace: stackTrace);
      try {
        observed = await Future<bool>.sync(_readStartupState);
      } catch (_) {
        observed = null;
      }
      if (observed == enabled) {
        _commitVerifiedState(enabled);
        if (!isClosed) startupStatusKey.v = '';
        return true;
      }
      return _recordFailure(observed, previous);
    }
  }

  bool _recordFailure(bool? observed, bool previous) {
    _commitVerifiedState(observed ?? previous);
    if (!isClosed) startupStatusKey.v = 'startup_apply_failed';
    return false;
  }

  void _commitVerifiedState(bool enabled) {
    _lastConfirmedEnabled = enabled;
    if (isClosed || enableStartUp.v == enabled) return;
    _internalWrite = enabled;
    enableStartUp.v = enabled;
  }

  Future<bool> enableStartup() => setStartupEnabled(true);

  Future<bool> disableStartup() => setStartupEnabled(false);

  Future<bool> toggleStartup() => setStartupEnabled(!enableStartUp.v);

  Map<String, dynamic> toJson() {
    return {'enableStartUp': enableStartUp.v};
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {'enableStartUp': (json['enableStartUp'] ?? true) as bool};
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    enableStartUp.v = parsed['enableStartUp'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final startup = rootConfig?['startup'] as Map<String, dynamic>? ?? {};
    return {'enableStartUp': startup['enableStartUp'] ?? true};
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final startup = Map<String, dynamic>.from(rootConfig['startup'] ?? {});
    updateFields.forEach((k, v) => startup[k] = v);
    rootConfig['startup'] = startup;
    return rootConfig;
  }

  @override
  void onClose() {
    _settingWorker?.dispose();
    _settingWorker = null;
    super.onClose();
  }
}
