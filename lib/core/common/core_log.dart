import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/plugins/catcher/file_handler.dart';

enum RequestLogType {
  /// 输出所有请求信息
  /// 包括请求的URL，请求的参数，请求的头，请求的体，响应的头，响应的内容，耗时
  all,

  /// 简洁的输出
  /// 仅输出请求的URL和响应的状态码
  short,

  /// 不输出请求信息
  none,
}

class CoreLog {
  static bool enableLog = true;
  static Function(Level, String)? onPrintLog;
  /// 请求日志模式
  static RequestLogType requestLogType = RequestLogType.none;
  static Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  static void d(String message) {
    onPrintLog?.call(Level.debug, message);
    if (!enableLog) {
      return;
    }
    logger.d("${DateTime.now().toString()} - ${getFunctionName()}\n$message");
  }

  static void i(String message) {
    onPrintLog?.call(Level.info, message);
    if (!enableLog) {
      return;
    }
    logger.i("${DateTime.now().toString()} - ${getFunctionName()} - ${getFunctionName()}\n$message");
  }

  static void e(String message, StackTrace stackTrace) {
    onPrintLog?.call(Level.error, message);
    if (!enableLog) {
      return;
    }
    logger.e("${DateTime.now().toString()} - ${getFunctionName()} - ${getFunctionName()}\n$message", stackTrace: stackTrace);
  }

  static String getFunctionName() {
    var stackTrace = StackTrace.current;
    // log(stackTrace.toString());
    var frames = stackTrace.toString().split("\n");
    var functionName = frames[2].trim().split(RegExp("\\s+"))[1];
    return functionName;
  }

  static const String splitToken =
      '======================================================================';
  static Future<void> error(dynamic e) async {
    onPrintLog?.call(Level.error, e.toString());
    logger.e(
      "${DateTime.now().toString()} - ${getFunctionName()}\n${e.toString()}",
      error: e?.toString(),
      stackTrace: (e is Error) ? e.stackTrace : StackTrace.current,
    );
    if(e is Error) {
      // 添加至文件末尾
      File logFile = await getLogsPath();
      var stackTraceText = "${e.stackTrace}";
      var splits = stackTraceText.split("\n");
      var newStackTraceTextList = [];
      for(var line in splits) {
        if(!isPrint(line)) continue;
        newStackTraceTextList.add(line);
      }
      stackTraceText = newStackTraceTextList.join("\n");
      logFile.writeAsString(
        "$splitToken\nCrash occurred on ${DateTime.now()}\n ${e.toString()} \n $stackTraceText".replaceAll("\n", CustomizeFileHandler.lineSeparator),
        mode: FileMode.writeOnlyAppend,
      );
    }

  }

  static bool isPrint(String text){
    if(text.length < 3) {
      return false;
    }
    if(text[0] == '#') {
      return text.contains("pure_live");
    }
    return true;
  }

  static void w(String message) {
    onPrintLog?.call(Level.warning, message);
    if (!enableLog) {
      return;
    }
    logger.w("${DateTime.now().toString()} - ${getFunctionName()}\n$message");
  }

  static void logPrint(dynamic obj) {
    onPrintLog?.call(Level.error, obj.toString());
    if (!enableLog) {
      return;
    }
  }

  static Future<File> getLogsPath() async {
    var dir = await getApplicationCacheDirectory();
    final File file = File('${dir.path}${Platform.pathSeparator}1._logs');
    d("log file: ${file.path}");
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  static Future<bool> clearLogs() async {
    final File file = await getLogsPath();
    try {
      await file.writeAsString('');
    } catch (e) {
      w('Error clearing file: $e');
      return false;
    }
    return true;
  }

}
