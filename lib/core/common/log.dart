import 'dart:io';
import 'dart:async';
import 'dart:convert';

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
  static const int maxDebugEntries = 2000;
  static LogFileWriter? _logFileWriter;
  static final List<DebugLogModel> _allLogs = [];
  static HttpServer? _server;
  static int _statusGeneration = 0;
  static List<DebugLogModel> get allLogs => List<DebugLogModel>.unmodifiable(_allLogs);

  @visibleForTesting
  static InternetAddress get logServerBindAddress => InternetAddress.loopbackIPv4;

  static bool get _localLoggingEnabled => Get.isRegistered<LogController>() && LogController.to.enableLog;

  @visibleForTesting
  static bool shouldBufferRuntimeLog({required bool releaseMode, required bool localLoggingEnabled}) {
    return !releaseMode || localLoggingEnabled;
  }

  static void clearDebugLogs() => _allLogs.clear();

  static Future<void> init() async {
    await setEnabled(LogController.to.enableLog);
  }

  static void dispose() {
    _statusGeneration++;
    final writer = _logFileWriter;
    final server = _server;
    _logFileWriter = null;
    _server = null;
    _clearRuntimeEndpoint();
    if (writer != null) unawaited(writer.close());
    if (server != null) unawaited(server.close(force: true));
  }

  static Future<bool> setEnabled(bool enabled) async {
    final generation = ++_statusGeneration;
    await _closeActiveResources();
    if (generation != _statusGeneration) return false;
    if (!enabled) return true;

    final writer = LogFileWriter();
    if (!await writer.init()) {
      await writer.close();
      return false;
    }
    if (generation != _statusGeneration) {
      await writer.close();
      return false;
    }

    HttpServer server;
    try {
      // Port zero asks the OS to select and bind an available port atomically;
      // loopback keeps the diagnostic page local to this device.
      server = await HttpServer.bind(logServerBindAddress, 0);
    } catch (error) {
      debugPrint('Failed to start local log server: $error');
      await writer.close();
      return false;
    }

    if (generation != _statusGeneration) {
      await server.close(force: true);
      await writer.close();
      return false;
    }

    _logFileWriter = writer;
    _server = server;
    if (Get.isRegistered<LogController>()) {
      LogController.to.updateServerInfo(server.address.address, server.port);
    }
    server.listen(_handleNativeRequest);
    return true;
  }

  static Future<void> _closeActiveResources() async {
    final writer = _logFileWriter;
    final server = _server;
    _logFileWriter = null;
    _server = null;
    _clearRuntimeEndpoint();
    if (writer != null) await writer.close();
    if (server != null) await server.close(force: true);
  }

  static void _clearRuntimeEndpoint() {
    if (Get.isRegistered<LogController>()) {
      LogController.to.updateServerInfo('', 0);
    }
  }

  static void _handleNativeRequest(HttpRequest request) {
    if (request.uri.path == '/clear') {
      clearDebugLogs();
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': true}))
        ..close();
      return;
    }

    final logRows = _allLogs
        .map((log) {
          final timeStr = Utils.timeFormat.format(log.datetime);
          String typeClass = 'info';
          if (log.color == Colors.red) {
            typeClass = 'error';
          } else if (log.color == Colors.orange) {
            typeClass = 'debug';
          } else if (log.color == Colors.pink) {
            typeClass = 'warning';
          }

          final safeContent = const HtmlEscape()
              .convert(log.content)
              .replaceAll('\n', '<br>')
              .replaceAll(' ', '&nbsp;');
          return '<tr class="$typeClass">'
              '<td class="time-col">$timeStr</td>'
              '<td class="log-content">$safeContent</td>'
              '</tr>';
        })
        .join('\n');

    final html =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PureLive Console Terminal</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    
    :root {
      --bg-color: #fafafa;
      --panel-bg: #ffffff;
      --border-color: #d0d7de;
      --top-bg: #f6f8fa;
      --text-main: #24292f;
      --text-time: #57606a;
      --th-bg: #f6f8fa;
      --badge-bg: #afb8c133;
      --badge-text: #24292f;
      --btn-bg: #f6f8fa;
      --btn-text: #24292f;
      --btn-border: #d0d7de;
      --btn-hover: #f3f4f6;
      
      --log-debug: #9a6700;
      --log-info: #0969da;
      --log-warning: #bf3989;
      --log-error: #cf222e;
      
      --row-hover: #f6f8fa;
    }

    [data-theme="dark"] {
      --bg-color: #0d1117;
      --panel-bg: #161b22;
      --border-color: #30363d;
      --top-bg: #161b22;
      --text-main: #c9d1d9;
      --text-time: #8b949e;
      --th-bg: #161b22;
      --badge-bg: #21262d;
      --badge-text: #8b949e;
      --btn-bg: #21262d;
      --btn-text: #c9d1d9;
      --btn-border: #30363d;
      --btn-hover: #30363d;
      
      --log-debug: #d29922;
      --log-info: #58a6ff;
      --log-warning: #ff7b72;
      --log-error: #f85149;
      
      --row-hover: #1f242c;
    }

    body { background-color: var(--bg-color); color: var(--text-main); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; padding: 24px; transition: background-color 0.2s; }
    .panel { max-width: 1400px; margin: 0 auto; background: var(--panel-bg); border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); border: 1px solid var(--border-color); overflow: hidden; }
    .top-bar { display: flex; justify-content: space-between; align-items: center; background: var(--top-bg); padding: 16px 24px; border-bottom: 1px solid var(--border-color); }
    .title-area { display: flex; align-items: center; gap: 12px; }
    .title { font-size: 16px; font-weight: 600; color: var(--text-main); }
    .badge { background: var(--badge-bg); color: var(--badge-text); padding: 2px 8px; border-radius: 2Fpx; font-size: 12px; font-weight: 500; border: 1px solid var(--border-color); }
    .btn-group { display: flex; gap: 8px; }
    .btn { padding: 5px 16px; background: var(--btn-bg); color: var(--btn-text); border: 1px solid var(--btn-border); border-radius: 6px; font-size: 14px; font-weight: 500; cursor: pointer; transition: all 0.2s; display: inline-flex; align-items: center; }
    .btn:hover { background: var(--btn-hover); }
    .btn-danger { color: #cf222e; }
    [data-theme="dark"] .btn-danger { color: #f85149; }
    .table-container { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; text-align: left; table-layout: fixed; }
    th { background: var(--th-bg); color: var(--text-time); font-size: 12px; font-weight: 600; padding: 12px 16px; border-bottom: 1px solid var(--border-color); }
    tr:hover { background-color: var(--row-hover); }
    td { padding: 10px 16px; border-bottom: 1px solid var(--border-color); font-size: 13px; line-height: 1.5; word-break: break-all; vertical-align: top; }
    .time-col { width: 160px; white-space: nowrap; font-family: monospace; color: var(--text-time); }
    .log-content { font-family: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace; }
    
    .debug .log-content { color: var(--log-debug); }
    .info .log-content { color: var(--text-main); }
    .warning .log-content { color: var(--log-warning); }
    .error .log-content { color: var(--log-error); font-weight: 500; }
  </style>
  <script>
    let autoRefresh = setTimeout(() => location.reload(), 3000);
    
    document.addEventListener('DOMContentLoaded', () => {
      const savedTheme = localStorage.getItem('purelive-theme') || 'light';
      document.documentElement.setAttribute('data-theme', savedTheme);
      document.getElementById('theme-btn').innerText = savedTheme === 'light' ? '🌙 Dark' : '☀️ Light';
    });

    function toggleTheme() {
      const currentTheme = document.documentElement.getAttribute('data-theme');
      const newTheme = currentTheme === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', newTheme);
      localStorage.setItem('purelive-theme', newTheme);
      document.getElementById('theme-btn').innerText = newTheme === 'light' ? '🌙 Dark' : '☀️ Light';
    }
    
    function clearLogs() {
      clearTimeout(autoRefresh);
      fetch('/clear')
        .then(res => res.json())
        .then(data => {
          if(data.success) location.reload();
        })
        .catch(() => {
          autoRefresh = setTimeout(() => location.reload(), 3000);
        });
    }

    function copyLogs() {
      const rows = document.querySelectorAll('tbody tr');
      let text = '';
      rows.forEach(row => {
        const time = row.querySelector('.time-col').innerText;
        const content = row.querySelector('.log-content').innerText;
        text += '[' + time + '] ' + content + '\\n';
      });
      navigator.clipboard.writeText(text).then(() => {
        alert('Copied all logs to clipboard!');
      });
    }
  </script>
</head>
<body>
  <div class="panel">
    <div class="top-bar">
      <div class="title-area">
        <span class="title">PureLive Console Terminal</span>
        <span class="badge">Total: ${_allLogs.length}</span>
      </div>
      <div class="btn-group">
        <button class="btn" id="theme-btn" onclick="toggleTheme()">🌙 Dark</button>
        <button class="btn btn-danger" onclick="clearLogs()">Clear</button>
        <button class="btn" onclick="copyLogs()">Copy</button>
        <button class="btn" onclick="location.reload()">Refresh</button>
      </div>
    </div>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th style="width: 160px;">Time</th>
            <th>Message</th>
          </tr>
        </thead>
        <tbody>
          $logRows
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
''';

    request.response
      ..headers.contentType = ContentType.html
      ..write(html)
      ..close();
  }

  static Future<bool> updateLogStatus() => setEnabled(LogController.to.enableLog);

  static void writeLog(Object content, [Level level = Level.info]) {
    if (!_localLoggingEnabled || _logFileWriter == null) return;
    _logFileWriter?.write("[${level.name.toUpperCase()}] $_currentTime：$content");
  }

  static void addDebugLog(String content, [Color? color]) {
    String processedContent = content;
    if (content.contains("请求响应")) {
      processedContent = content.split("\n").join('\n💡 ');
    }

    _allLogs.add(DebugLogModel(DateTime.now(), processedContent, color: color));
    final overflow = _allLogs.length - maxDebugEntries;
    if (overflow > 0) {
      _allLogs.removeRange(0, overflow);
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

  static void d(String message) {
    final localLoggingEnabled = _localLoggingEnabled;
    if (shouldBufferRuntimeLog(releaseMode: kReleaseMode, localLoggingEnabled: localLoggingEnabled)) {
      addDebugLog(message, Colors.orange);
    }
    if (!kReleaseMode) {
      logger.d(message);
    }
    if (localLoggingEnabled) writeLog(message, Level.debug);
  }

  static void i(String message) {
    final localLoggingEnabled = _localLoggingEnabled;
    if (shouldBufferRuntimeLog(releaseMode: kReleaseMode, localLoggingEnabled: localLoggingEnabled)) {
      addDebugLog(message, Colors.blue);
    }
    if (!kReleaseMode) {
      logger.i(message);
    }
    if (localLoggingEnabled) writeLog(message, Level.info);
  }

  static void e(String message, StackTrace stackTrace) {
    final localLoggingEnabled = _localLoggingEnabled;
    if (shouldBufferRuntimeLog(releaseMode: kReleaseMode, localLoggingEnabled: localLoggingEnabled)) {
      addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
    }
    if (!kReleaseMode) {
      logger.e(message, stackTrace: stackTrace);
    }
    if (localLoggingEnabled) writeLog("$message\n$stackTrace", Level.error);
  }

  static void w(String message) {
    final localLoggingEnabled = _localLoggingEnabled;
    if (shouldBufferRuntimeLog(releaseMode: kReleaseMode, localLoggingEnabled: localLoggingEnabled)) {
      addDebugLog(message, Colors.pink);
    }
    if (!kReleaseMode) {
      logger.w(message);
    }
    if (localLoggingEnabled) writeLog(message, Level.warning);
  }

  static void logPrint(dynamic obj) {
    final String content = obj.toString();
    final localLoggingEnabled = _localLoggingEnabled;
    if (shouldBufferRuntimeLog(releaseMode: kReleaseMode, localLoggingEnabled: localLoggingEnabled)) {
      addDebugLog(content, Colors.red);
    }
    if (!kReleaseMode) {
      if (kDebugMode) {
        print(content);
      }
    }
    if (localLoggingEnabled) writeLog(content, Level.info);
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

  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      final logDir = await resolveLogDirectory();
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      var logFile = File("${logDir.path}/$_fileName");
      _fileWriter = logFile.openWrite(mode: FileMode.append);
      _isInitialized = true;

      await _writeSystemInfo();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Init log file failed: $e\n$stackTrace');
      return false;
    }
  }

  static Future<Directory> resolveLogDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw const FileSystemException('Downloads directory is unavailable');
      }
      return Directory(AppPathManager.logFilesDirectoryPath(path.join(dir.path, AppPathManager.dirLogs)));
    }
    return AppPathManager().logFilesDir;
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

      _fileWriter?.write("=========================================================\r\n");
      _fileWriter?.write("  ____  _   _ ____  _____   _     _____     _______ \r\n");
      _fileWriter?.write(" |  _ \\| | | |  _ \\| ____| | |   |_ _\\ \\   / / ____|\r\n");
      _fileWriter?.write(" | |_) | | | | |_) |  _|   | |    | | \\ \\ / /|  _|  \r\n");
      _fileWriter?.write(" |  __/| |_| |  _ <| |___  | |___ | |  \\ V / | |___ \r\n");
      _fileWriter?.write(" |_|    \\___/|_| \\_\\_____| |_____|___|  \\_/  |_____|\r\n");
      _fileWriter?.write("=========================================================\r\n");
      _fileWriter?.write(" 🕒 Current Time : ${DateTime.now()}\r\n");
      _fileWriter?.write(" 📱 Platform     : ${Platform.operatingSystem}\r\n");
      _fileWriter?.write(" ⚙️ OS Version   : ${Platform.operatingSystemVersion}\r\n");
      _fileWriter?.write(" 🌐 Locale       : ${Platform.localeName}\r\n");
      _fileWriter?.write(" 📦 App Version  : v${packageInfo.version} (${packageInfo.buildNumber})\r\n");

      String model = "Unknown";
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        model = "${info.brand} ${info.model} (API ${info.version.sdkInt})";
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        model = "${info.name} ${info.systemVersion}";
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        model = "${info.name} (${info.versionId})";
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        model = "${info.computerName} (macOS ${info.osRelease})";
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        model = "${info.computerName} (Build ${info.buildNumber})";
      }

      _fileWriter?.write(" 💻 Device Model : $model\r\n");
      _fileWriter?.write("=========================================================\r\n\r\n");
      await _fileWriter?.flush();
    } catch (e, stackTrace) {
      Log.e("Init log file failed: $e", stackTrace);
    }
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
