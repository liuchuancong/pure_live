import 'dart:async';

import 'package:logger/logger.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/get/get.dart';

typedef LogStatusApplier = Future<bool> Function(bool enabled);

class LogController extends GetxController {
  LogController({LogStatusApplier? applyLogStatus}) : _applyLogStatus = applyLogStatus ?? Log.setEnabled;

  static LogController get to => Get.find<LogController>();
  final LogStatusApplier _applyLogStatus;

  // The endpoint belongs to the current HttpServer instance. Persisting it
  // makes the next process advertise a dead port before logging is enabled.
  final RxString serverAddress = ''.obs;
  final RxInt serverPort = 0.obs;

  final RxBool storedEnableLog = false.obs;
  final RxBool _isApplyingLogStatus = false.obs;
  final RxString _logStatusKey = ''.obs;
  Worker? _logStatusWorker;
  Future<bool>? _activeOperation;
  bool? _pendingTarget;
  bool? _internalWrite;
  bool _lastConfirmedEnabled = false;

  static Function(Level, String)? onPrintLog;

  @override
  void onInit() {
    super.onInit();
    _lastConfirmedEnabled = storedEnableLog.v;
    _logStatusWorker = ever<bool>(storedEnableLog, (value) {
      if (_internalWrite == value) {
        _internalWrite = null;
        return;
      }
      unawaited(_setLoggingEnabled(value));
    });
  }

  Future<bool> _setLoggingEnabled(bool enabled) {
    _pendingTarget = enabled;
    final active = _activeOperation;
    if (active != null) {
      return active.then((_) => _lastConfirmedEnabled == enabled && _logStatusKey.v.isEmpty);
    }

    late final Future<bool> operation;
    operation = _drainStatusRequests().whenComplete(() {
      if (identical(_activeOperation, operation)) _activeOperation = null;
    });
    _activeOperation = operation;
    return operation.then((_) => _lastConfirmedEnabled == enabled && _logStatusKey.v.isEmpty);
  }

  Future<bool> _drainStatusRequests() async {
    if (!isClosed) _isApplyingLogStatus.v = true;
    var result = true;
    try {
      while (_pendingTarget != null) {
        final target = _pendingTarget!;
        _pendingTarget = null;
        result = await _applyStatusTarget(target);
      }
      return result;
    } finally {
      if (!isClosed) _isApplyingLogStatus.v = false;
    }
  }

  Future<bool> _applyStatusTarget(bool enabled) async {
    final previous = _lastConfirmedEnabled;
    try {
      if (!await _applyLogStatus(enabled)) return _recordFailure(previous);
      _commitVerifiedState(enabled);
      if (!enabled) _clearRuntimeEndpoint();
      if (!isClosed) _logStatusKey.v = '';
      return true;
    } catch (_) {
      return _recordFailure(previous);
    }
  }

  bool _recordFailure(bool previous) {
    _commitVerifiedState(previous);
    if (!previous) _clearRuntimeEndpoint();
    if (!isClosed) _logStatusKey.v = 'local_log_apply_failed';
    return false;
  }

  void _commitVerifiedState(bool enabled) {
    _lastConfirmedEnabled = enabled;
    if (isClosed || storedEnableLog.v == enabled) return;
    _internalWrite = enabled;
    storedEnableLog.v = enabled;
  }

  void _clearRuntimeEndpoint() {
    if (serverAddress.v.isNotEmpty) serverAddress.v = '';
    if (serverPort.v != 0) serverPort.v = 0;
  }

  @override
  void onClose() {
    _logStatusWorker?.dispose();
    _logStatusWorker = null;
    _pendingTarget = null;
    Log.dispose();
    super.onClose();
  }

  void updateServerInfo(String address, int port) {
    serverAddress.value = address;
    serverPort.value = port;
  }

  bool get enableLog => storedEnableLog.v;
}

extension LogControllerTransactions on LogController {
  RxBool get isApplyingLogStatus => _isApplyingLogStatus;

  RxString get logStatusKey => _logStatusKey;

  Future<bool> setLoggingEnabled(bool enabled) => _setLoggingEnabled(enabled);
}
