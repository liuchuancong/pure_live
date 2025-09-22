import 'dart:convert';
import 'dart:io';

import 'package:catcher_2/model/platform_type.dart';
import 'package:catcher_2/model/report.dart';
import 'package:catcher_2/model/report_handler.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/core/common/core_log.dart';

typedef FileSupplier = File Function(Report);

class CustomizeFileHandler extends ReportHandler {
  CustomizeFileHandler(
      this.file, {
        this.fileSupplier,
        this.enableDeviceParameters = true,
        this.enableApplicationParameters = true,
        this.enableStackTrace = true,
        this.enableCustomParameters = true,
        this.printLogs = false,
        this.handleWhenRejected = false,
      });

  /// A file that should be written to. Is overwritten by [fileSupplier].
  final File file;

  /// Function that returns a file that should be written to. If this is set,
  /// [file] has no effect.
  final FileSupplier? fileSupplier;
  final bool enableDeviceParameters;
  final bool enableApplicationParameters;
  final bool enableStackTrace;
  final bool enableCustomParameters;
  final bool printLogs;
  final bool handleWhenRejected;

  File? _openedFile;
  IOSink? _sink;
  bool _fileValidated = false;
  bool _fileValidationResult = false;

  /// 一行的分隔符 modify
  static final String lineSeparator = "#&&#";

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    _openedFile = fileSupplier != null ? fileSupplier!(report) : file;
    try {
      if (!_fileValidated) {
        _fileValidationResult = await _checkFile();
        _fileValidated = true;
      }
      return await _processReport(report);
    } catch (exc, stackTrace) {
      _printLog('Exception occurred: $exc stack: $stackTrace');
      return false;
    }
  }

  Future<bool> _processReport(Report report) async {
    if (_fileValidationResult) {
      await _openFile();
      await _writeReportToFile(report);
      await _closeFile();
      return true;
    } else {
      return false;
    }
  }

  Future<bool> _checkFile() async {
    if (_openedFile == null) {
      return false;
    }
    try {
      final exists = _openedFile!.existsSync();
      if (!exists) {
        _openedFile!.createSync();
      }
      final sink = _openedFile!.openWrite(mode: FileMode.append)..write('');
      await sink.flush();
      await sink.close();
      return true;
    } catch (exc, stackTrace) {
      _printLog('Exception occurred: $exc stack: $stackTrace');
      return false;
    }
  }

  Future<void> _openFile() async {
    if (_openedFile == null) {
      _printLog('Could not open file');
      return;
    }
    _sink = _openedFile!.openWrite(mode: FileMode.append);
    _printLog('Opened file');
  }

  void _writeLineToFile(String text) {
    if(!isPrint(text)) return;
    _sink?.add(utf8.encode('$text$lineSeparator'));
  }

  bool isPrint(String text){
    if(text.length < 3) {
      return false;
    }
    if(text[0] == '#') {
      return text.contains("pure_live");
    }
    return true;
  }

  Future<void> _closeFile() async {
    await _sink?.flush();
    await _sink?.close();
    _printLog('Closed file');
  }

  Future<void> _writeReportToFile(Report report) async {
    _printLog('Writing report to file');
    _writeLineToFile(
      '============================== '
          'CATCHER 2 LOG '
          '==============================',
    );
    _writeLineToFile('Crash occurred on ${report.dateTime}');
    _writeLineToFile('');
    if (enableDeviceParameters) {
      _logDeviceParametersFormatted(report.deviceParameters);
      _writeLineToFile('');
    }
    if (enableApplicationParameters) {
      _logApplicationParametersFormatted(report.applicationParameters);
      _writeLineToFile('');
    }
    _writeLineToFile('---------- ERROR ----------');
    _writeLineToFile('${report.error}');
    _writeLineToFile('');
    if (enableStackTrace) {
      _writeLineToFile('------- STACK TRACE -------');
      _writeLineToFile('${report.stackTrace}');
    }
    if (enableCustomParameters) {
      _logCustomParametersFormatted(report.customParameters);
    }
    _writeLineToFile(
      '======================================================================',
    );
    // new line modify
    _sink?.add(utf8.encode('\n'));
  }

  void _logDeviceParametersFormatted(Map<String, dynamic> deviceParameters) {
    _writeLineToFile('------- DEVICE INFO -------');
    for (final entry in deviceParameters.entries) {
      _writeLineToFile('${entry.key}: ${entry.value}');
    }
  }

  void _logApplicationParametersFormatted(
      Map<String, dynamic> applicationParameters,
      ) {
    _writeLineToFile('------- APP INFO -------');
    for (final entry in applicationParameters.entries) {
      _writeLineToFile('${entry.key}: ${entry.value}');
    }
  }

  void _logCustomParametersFormatted(Map<String, dynamic> customParameters) {
    _writeLineToFile('------- CUSTOM INFO -------');
    for (final entry in customParameters.entries) {
      _writeLineToFile('${entry.key}: ${entry.value}');
    }
  }

  void _printLog(String log) {
    if (printLogs && isPrint(log)) {
      // logger.info(log);
      CoreLog.w(log);
    }
  }

  @override
  List<PlatformType> getSupportedPlatforms() => [
    PlatformType.android,
    PlatformType.iOS,
    PlatformType.linux,
    PlatformType.macOS,
    PlatformType.windows,
  ];

  @override
  bool shouldHandleWhenRejected() => handleWhenRejected;
}
