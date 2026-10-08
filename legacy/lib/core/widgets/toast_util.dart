import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class ToastUtil {
  static DateTime? _lastShowTime;

  static String? _lastMsg;

  static void show(String? msg) {
    if (msg == null || msg.isEmpty) return;
    final now = DateTime.now();
    if (msg == _lastMsg &&
        _lastShowTime != null &&
        now.difference(_lastShowTime!) < const Duration(milliseconds: 3000)) {
      return;
    }
    _lastShowTime = now;
    _lastMsg = msg;
    try {
      unawaited(
        SmartDialog.showToast(msg).catchError((Object error, StackTrace stackTrace) {
          developer.log('Toast skipped because no dialog host is active', error: error, stackTrace: stackTrace);
        }),
      );
    } catch (error, stackTrace) {
      // Async playback/network callbacks can finish while the root overlay is
      // being replaced or already disposed. A missing toast host must never
      // turn a handled stream failure into an uncaught UI exception.
      developer.log('Toast skipped because no dialog host is active', error: error, stackTrace: stackTrace);
    }
  }
}
