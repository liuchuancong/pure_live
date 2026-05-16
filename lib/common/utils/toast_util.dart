import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class ToastUtil {
  static void show(String? msg) {
    if (msg == null || msg.isEmpty) return;
    SmartDialog.showToast(msg);
  }
}
