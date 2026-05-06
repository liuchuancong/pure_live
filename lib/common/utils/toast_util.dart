import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class ToastUtil {
  static String? _lastMsg;
  static DateTime? _lastTime;

  static void show(String msg, {Duration interval = const Duration(seconds: 5)}) {
    final now = DateTime.now();
    if (msg == _lastMsg && _lastTime != null && now.difference(_lastTime!) < interval) {
      return;
    }
    _lastMsg = msg;
    _lastTime = now;
    SmartDialog.showToast(msg);
  }
}
