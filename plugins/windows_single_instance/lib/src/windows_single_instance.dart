import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WindowsSingleInstance {
  static const MethodChannel _channel = MethodChannel('windows_single_instance');
  static const _kErrorPipeConnected = 0x80070217;

  WindowsSingleInstance._();

  static HANDLE _openPipe(String filename) {
    final cPipe = filename.toPcwstr();
    try {
      final Win32Result(:value) = CreateFile(
        cPipe,
        GENERIC_WRITE,
        FILE_SHARE_NONE,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
      );
      return value;
    } finally {
      free(cPipe);
    }
  }

  static HANDLE _createPipe(String filename) {
    final cPipe = filename.toPcwstr();
    try {
      return CreateNamedPipe(
        cPipe,
        FILE_FLAGS_AND_ATTRIBUTES(
          PIPE_ACCESS_INBOUND | FILE_FLAG_FIRST_PIPE_INSTANCE | FILE_FLAG_OVERLAPPED,
        ),
        NAMED_PIPE_MODE(
          PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        ),
        PIPE_UNLIMITED_INSTANCES,
        4096,
        4096,
        0,
        null,
      );
    } finally {
      free(cPipe);
    }
  }

  static void _readPipe(SendPort writer, HANDLE pipeHandle) {
    final overlap = calloc<OVERLAPPED>();
    try {
      while (true) {
        while (true) {
          final Win32Result(:error) = ConnectNamedPipe(pipeHandle, overlap);
          final err = error;
          if (err == _kErrorPipeConnected) {
            sleep(const Duration(milliseconds: 200));
            continue;
          } else if (err == ERROR_INVALID_HANDLE) {
            return;
          }
          break;
        }

        const dataSize = 16384;
        final data = calloc<Uint8>(dataSize);
        final numRead = calloc<Uint32>();
        try {
          while (!GetOverlappedResult(pipeHandle, overlap, numRead, false).value) {
            sleep(const Duration(milliseconds: 200));
          }

          ReadFile(pipeHandle, data, dataSize, numRead, overlap);
          final jsonData = data.cast<Utf8>().toDartString();
          writer.send(jsonDecode(jsonData));
        } catch (error) {
          stderr.writeln("[MultiInstanceHandler]: ERROR: $error");
        } finally {
          free(data);
          free(numRead);
          DisconnectNamedPipe(pipeHandle);
        }
      }
    } finally {
      free(overlap);
    }
  }

  static void _writePipeData(String filename, List<String>? arguments) {
    final pipe = _openPipe(filename);
    final bytesString = jsonEncode(arguments ?? []);
    final bytes = bytesString.toNativeUtf8();
    final numWritten = malloc<Uint32>();
    try {
      WriteFile(pipe, bytes.cast<Uint8>(), bytes.length, numWritten, null);
    } finally {
      free(numWritten);
      free(bytes);
      CloseHandle(pipe);
    }
  }

  static void _startReadPipeIsolate(Map args) {
    final pipe = _createPipe(args["pipe"] as String);
    if (pipe == INVALID_HANDLE_VALUE) {
      debugPrint("Pipe create failed");
      return;
    }
    _readPipe(args["port"] as SendPort, pipe);
  }

  /// Checks that the current window is unique, and exits the app if not.
  ///
  /// __Arguments__\
  /// `arguments`: List of strings that will be passed to the callback function of the open instance if this window is not unique\
  /// `pipeName`: A string unique to your app\
  /// `bringWindowToFront`: Should your active window become visible\
  /// `onSecondWindow`: Callback function that is called when a second window is attempted to be opened.
  /// `exitFunction`: An alternate function to exit the app, if not provided, the app will be exited using `exit(0)`.
  static Future ensureSingleInstance(
    List<String> arguments,
    String pipeName, {
    Function(List<String>)? onSecondWindow,
    bool bringWindowToFront = true,
    Future<void> Function()? exitFunction,
  }) async {
    if (!Platform.isWindows) return;
    final fullPipeName = "\\\\.\\pipe\\$pipeName";
    final bool isSingleInstance = await _channel.invokeMethod('isSingleInstance', <String, Object>{
      "pipe": pipeName,
    });
    if (!isSingleInstance) {
      _writePipeData(fullPipeName, arguments);
      await (exitFunction?.call() ?? Future.value(exit(0)));
      return;
    }

    // No callback so don't bother starting pipe
    if (onSecondWindow == null && bringWindowToFront == false) {
      return;
    }

    final reader = ReceivePort()
      ..listen((dynamic msg) {
        if (msg is List) {
          if (onSecondWindow != null) {
            onSecondWindow(msg.map((o) => o.toString()).toList());
          }
          if (bringWindowToFront) _bringWindowToFront();
        }
      });
    await Isolate.spawn(_startReadPipeIsolate, {"port": reader.sendPort, "pipe": fullPipeName});
  }

  static void _bringWindowToFront() {
    _channel.invokeMethod('bringToFront');
  }
}
