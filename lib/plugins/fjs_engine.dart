import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:pure_live/core/common/core_log.dart';

/// Flutter JS Engine 单例
///
/// 基于 flutter_js
///
/// 负责：
/// - JavascriptRuntime 初始化
/// - JavaScript 执行
/// - Engine 销毁
/// - Engine 重启
class FlutterJsEngine {
  FlutterJsEngine._();

  static final FlutterJsEngine instance = FlutterJsEngine._();

  JavascriptRuntime? _runtime;

  /// 防止多个地方同时初始化
  Future<void>? _initFuture;

  bool get isInitialized => _runtime != null;

  /// 获取当前 Runtime
  JavascriptRuntime get engine {
    final runtime = _runtime;

    if (runtime == null) {
      throw StateError(
        'FlutterJsEngine has not been initialized. '
        'Call FlutterJsEngine.instance.init() first.',
      );
    }

    return runtime;
  }

  // ============================================================
  // 初始化
  // ============================================================

  /// 初始化 Flutter JS Runtime
  ///
  /// 多次调用不会重复初始化。
  ///
  /// 如果多个地方同时调用 init()，
  /// 只有第一个调用会真正执行初始化，
  /// 其他调用会等待同一个 Future。
  Future<void> init() async {
    if (_runtime != null) {
      return;
    }

    final initializing = _initFuture;

    if (initializing != null) {
      await initializing;
      return;
    }

    final future = _initInternal();

    _initFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }
  }

  Future<void> _initInternal() async {
    CoreLog.d('FlutterJS: initializing...');

    try {
      final runtime = getJavascriptRuntime();

      _runtime = runtime;

      CoreLog.d('FlutterJS: initialized');
    } catch (e, stackTrace) {
      CoreLog.error('FlutterJS initialization failed: $e\n$stackTrace');

      _runtime = null;

      rethrow;
    }
  }

  // ============================================================
  // JavaScript 执行
  // ============================================================

  /// 执行 JavaScript
  ///
  /// 例如：
  ///
  /// ```dart
  /// final result = await FlutterJsEngine.instance.eval('1 + 2');
  /// print(result.stringResult);
  /// ```
  Future<JsEvalResult> eval(String source) async {
    await init();

    try {
      return engine.evaluate(source);
    } on PlatformException catch (e, stackTrace) {
      CoreLog.error('FlutterJS evaluate failed: ${e.details}\n$stackTrace');

      rethrow;
    } catch (e, stackTrace) {
      CoreLog.error('FlutterJS evaluate failed: $e\n$stackTrace');

      rethrow;
    }
  }

  /// 同步执行 JavaScript
  ///
  /// 如果你已经确保 Engine 初始化，可以直接使用这个方法。
  JsEvalResult evalSync(String source) {
    return engine.evaluate(source);
  }

  /// 执行 JavaScript 并返回字符串
  Future<String> evalString(String source) async {
    final result = await eval(source);
    return result.stringResult;
  }

  /// 执行 JavaScript 并返回 int
  Future<int?> evalInt(String source) async {
    final result = await eval(source);

    return result.isError ? null : int.tryParse(result.stringResult);
  }

  /// 执行 JavaScript 并返回 double
  Future<double?> evalDouble(String source) async {
    final result = await eval(source);

    return result.isError ? null : double.tryParse(result.stringResult);
  }

  /// 执行 JavaScript 并判断是否出错
  Future<bool> evalBool(String source) async {
    final result = await eval(source);

    if (result.isError) {
      return false;
    }

    return result.stringResult == 'true';
  }

  // ============================================================
  // 生命周期
  // ============================================================

  /// 销毁 Runtime
  Future<void> close() async {
    final runtime = _runtime;

    if (runtime == null) {
      return;
    }

    // 先置空，避免关闭期间其他代码继续使用
    _runtime = null;

    try {
      runtime.dispose();

      CoreLog.d('FlutterJS: closed');
    } catch (e, stackTrace) {
      CoreLog.error('FlutterJS close failed: $e\n$stackTrace');
    }
  }

  /// 重启 Runtime
  Future<void> restart() async {
    await close();
    await init();
  }
}
