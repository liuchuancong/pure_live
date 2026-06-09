import 'dart:io';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';

class Log {
  static LogFileWriter? _logFileWriter;
  static final List<DebugLogModel> _allLogs = [];
  static final StreamController<List<DebugLogModel>> _logStreamController =
      StreamController<List<DebugLogModel>>.broadcast();

  static Stream<List<DebugLogModel>> get logStream => _logStreamController.stream;
  static List<DebugLogModel> get allLogs => _allLogs;

  static Future<void> init() async {
    if (LogController.to.enableLog) {
      _logFileWriter = LogFileWriter();
      await _logFileWriter!.init();
    }
  }

  static void dispose() {
    _logFileWriter?.close();
    _logFileWriter = null;
    _logStreamController.close();
  }

  static Future<void> updateLogStatus() async {
    _logFileWriter?.close();
    _logFileWriter = null;
    if (LogController.to.enableLog) {
      _logFileWriter = LogFileWriter();
      await _logFileWriter!.init();
    }
  }

  static void writeLog(Object content, [Level level = Level.info]) {
    if (!LogController.to.enableLog || _logFileWriter == null) return;
    _logFileWriter?.write("[${level.name.toUpperCase()}] $_currentTime：$content");
  }

  static void addDebugLog(String content, Color? color) {
    if (kReleaseMode) return;
    if (content.contains("请求响应")) {
      content = content.split("\n").join('\n💡 ');
    }
    try {
      _allLogs.add(DebugLogModel(DateTime.now(), content, color: color));
      _logStreamController.add(_allLogs);
    } catch (e) {
      debugPrint('Add debug log error: $e');
    }
  }

  static final Logger logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
    output: kReleaseMode ? _NullOutput() : ConsoleOutput(),
  );

  static void d(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.orange);
      logger.d(message);
    }
    if (writeFile) writeLog(message, Level.debug);
  }

  static void i(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.blue);
      logger.i(message);
    }
    if (writeFile) writeLog(message, Level.info);
  }

  static void e(String message, StackTrace stackTrace, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
      logger.e(message, stackTrace: stackTrace);
    }
    if (writeFile) writeLog("$message\n$stackTrace", Level.error);
  }

  static void w(String message, [bool writeFile = true]) {
    if (!kReleaseMode) {
      addDebugLog(message, Colors.pink);
      logger.w(message);
    }
    if (writeFile) writeLog(message, Level.warning);
  }

  static void logPrint(dynamic obj, [bool writeFile = true]) {
    final String content = obj.toString();
    if (!kReleaseMode) {
      addDebugLog(content, Colors.red);
      if (kDebugMode) {
        print(content);
      }
    }
    if (writeFile) writeLog(content, Level.info);
  }

  static String get _currentTime => Utils.timeFormat.format(DateTime.now());
}

class _NullOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

class LogFileWriter {
  late final String _fileName;
  IOSink? _fileWriter;
  bool _isInitialized = false;

  LogFileWriter() {
    var dt = DateFormat("yyyy-MM-dd_HH-mm-ss").format(DateTime.now());
    _fileName = "$dt.log";
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      var supportDir = await getSafLogDir();
      var logDir = Directory("${supportDir.path}/log");
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      var logFile = File("${logDir.path}/$_fileName");
      _fileWriter = logFile.openWrite(mode: FileMode.append);
      _isInitialized = true;

      await _writeSystemInfo();
    } catch (e) {
      debugPrint("Init log file failed: $e");
    }
  }

  Future<Directory> getSafLogDir() async {
    Directory logDir;
    if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
      logDir = Directory(path.join(dir!.path, AppPathManager.dirLogs));
    } else {
      logDir = await AppPathManager().getDir(AppPathManager.dirLogs);
    }

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  void write(String content) {
    if (!_isInitialized) return;
    _fileWriter?.write("$content\r\n");
  }

  Future<void> close() async {
    await _fileWriter?.flush();
    await _fileWriter?.close();
    _isInitialized = false;
  }

  Future<void> _writeSystemInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();

      _fileWriter?.write("====================== System Info ======================\r\n");
      _fileWriter?.write("Current Time: ${DateTime.now()}\r\n");
      _fileWriter?.write("Platform    : ${Platform.operatingSystem}\r\n");
      _fileWriter?.write("OS Version  : ${Platform.operatingSystemVersion}\r\n");
      _fileWriter?.write("Locale      : ${Platform.localeName}\r\n");
      _fileWriter?.write("App Version : ${packageInfo.version}+${packageInfo.buildNumber}\r\n");

      String deviceData = "";
      if (Platform.isAndroid) {
        deviceData = (await deviceInfo.androidInfo).data.toString();
      } else if (Platform.isIOS) {
        deviceData = (await deviceInfo.iosInfo).data.toString();
      } else if (Platform.isLinux) {
        deviceData = (await deviceInfo.linuxInfo).data.toString();
      } else if (Platform.isMacOS) {
        deviceData = (await deviceInfo.macOsInfo).data.toString();
      } else if (Platform.isWindows) {
        deviceData = (await deviceInfo.windowsInfo).data.toString();
      }
      _fileWriter?.write("Device Data : $deviceData\r\n");
      _fileWriter?.write("=========================================================\r\n\r\n");
      await _fileWriter?.flush();
    } catch (e) {
      debugPrint("Write system info error: $e");
    }
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
