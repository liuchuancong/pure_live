import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class ToastUtil {
  static String? _lastMsg;

  static void show(String? msg) {
    if (msg == null || msg.isEmpty) return;
    if (msg == _lastMsg) return;

    _lastMsg = msg;

    SmartDialog.showToast(msg);
  }

  static void clear() {
    _lastMsg = null;
  }
}
