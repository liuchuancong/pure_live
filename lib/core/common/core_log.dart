import 'log.dart';
import 'package:logger/logger.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';

class CoreLog {
  static Function(Level, String)? onPrintLog;

  static void d(String message) {
    onPrintLog?.call(Level.debug, message);
    if (!LogController.to.enableLog) return;
    Log.d(message);
  }

  static void i(String message) {
    onPrintLog?.call(Level.info, message);
    if (!LogController.to.enableLog) return;
    Log.i(message);
  }

  static void e(String message, StackTrace stackTrace) {
    onPrintLog?.call(Level.error, message);
    if (!LogController.to.enableLog) return;
    Log.e(message, stackTrace);
  }

  static void error(dynamic e) {
    final String msg = e.toString();
    onPrintLog?.call(Level.error, msg);
    if (!LogController.to.enableLog) return;

    final StackTrace trace = (e is Error) ? (e.stackTrace ?? StackTrace.current) : StackTrace.current;
    Log.e(msg, trace);
  }

  static void w(String message) {
    onPrintLog?.call(Level.warning, message);
    if (!LogController.to.enableLog) return;
    Log.w(message);
  }

  static void logPrint(dynamic obj) {
    final String content = obj.toString();
    onPrintLog?.call(Level.error, content);
    if (!LogController.to.enableLog) return;
    Log.logPrint(content);
  }
}
