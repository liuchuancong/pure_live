import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_js/javascript_runtime.dart';
import 'package:flutter_js/javascriptcore/jscore_runtime.dart';

import './extensions/fetch.dart';
import './extensions/handle_promises.dart';
import './quickjs/quickjs_runtime2.dart';

export './extensions/handle_promises.dart';
//import 'package:flutter_js/quickjs-sync-server/quickjs_oasis_jsbridge.dart';
//import 'package:flutter_js/quickjs/quickjs_runtime.dart';

export './quickjs/quickjs_runtime.dart';
export './quickjs/quickjs_runtime2.dart';
export 'javascript_runtime.dart';
export 'js_eval_result.dart';
export 'quickjs-sync-server/quickjs_oasis_jsbridge.dart';

// import condicional to not import ffi libraries when using web as target
// import "something.dart" if (dart.library.io) "other.dart";
// REF:
// - https://medium.com/flutter-community/conditional-imports-across-flutter-and-web-4b88885a886e
// - https://github.com/creativecreatorormaybenot/wakelock/blob/master/wakelock/lib/wakelock.dart
JavascriptRuntime getJavascriptRuntime({
  bool forceJavascriptCoreOnAndroid = false,
  bool xhr = true,
  Map<String, dynamic>? extraArgs = const {},
}) {
  JavascriptRuntime runtime;
  if ((Platform.isAndroid && !forceJavascriptCoreOnAndroid)) {
    int stackSize = extraArgs?['stackSize'] ?? 1024 * 1024;
    runtime = QuickJsRuntime2(stackSize: stackSize);
    // FlutterJs engine = FlutterJs();
    // runtime = QuickJsService(engine);
  } else if (Platform.isWindows) {
    runtime = QuickJsRuntime2();
  } else if (Platform.isLinux) {
    // runtime = FlutterJsLinuxWin()..init();
    //runtime = JavascriptCoreRuntime(); //('f1.js');
    runtime = QuickJsRuntime2();
  } else {
    runtime = JavascriptCoreRuntime();
  }
  if (xhr) runtime.enableFetch();
  runtime.enableHandlePromises();
  return runtime;
}

// JavascriptRuntime getJavascriptRuntime({bool xhr = true}) {
//   JavascriptRuntime runtime = JavascriptCoreRuntime();
//   // setFetchDebug(true);
//   if (xhr) runtime.enableFetch();
//   runtime.enableHandlePromises();
//   return runtime;
// }

final Map<int?, FlutterJs> _engineMap = {};

MethodChannel _methodChannel = const MethodChannel('io.abner.flutter_js')
  ..setMethodCallHandler((MethodCall call) {
    if (call.method == "sendMessage") {
      final engineId = call.arguments[0] as int?;
      final channel = call.arguments[1] as String?;
      final message = call.arguments[2] as String?;

      if (_engineMap[engineId] != null) {
        return _engineMap[engineId]!.onMessageReceived(
          channel,
          message,
        );
      } else {
        return Future.value('Error: no engine found with id: $engineId');
      }
    }
    return Future.error('No method "${call.method}" was found!');
  });

bool messageHandlerRegistered = false;

typedef FlutterJsChannelCallbak = Future<String> Function(
  String? args,
);

class FlutterJs {
  int? _engineId;
  static int? _httpPort;

  static int? get httpPort => _httpPort;
  static String? get httpPassword => _httpPassword;

  static var _engineCount = -1;
  static String? _httpPassword;

  bool _ready = false;

  int? get id => _engineId;

  Map<String, FlutterJsChannelCallbak> _channels = {};

  FlutterJs() {
    _engineCount += 1;
    _engineId = _engineCount;
    FlutterJs.initEngine(_engineId).then((_) => _ready = true);
    _engineMap[_engineId] = this;
  }

  dispose() {
    FlutterJs.close(_engineId);
  }

  addChannel(String name, FlutterJsChannelCallbak fn,
      {String? dartChannelAddress}) {
    _channels[name] = fn;
    _methodChannel.invokeMethod(
      "registerChannel",
      {
        "engineId": id,
        "channelName": name,
        "dartChannelAddress": dartChannelAddress
      },
    );
  }

  Future<String> onMessageReceived(String? channel, String? message) {
    if (_channels[channel!] != null) {
      return _channels[channel]!(message);
    } else {
      return Future.error('No channel "$channel" was registered!');
    }
  }

  bool isReady() => _ready;

  // ignore: non_constant_identifier_names
  static bool DEBUG = false;

  Future<String> eval(String code) {
    return evaluate(code, _engineId);
  }

  static Future<String?> get platformVersion async {
    final String? version =
        await _methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<int?> initEngine(int? engineId) async {
    Map<dynamic, dynamic> mapResult = await (_methodChannel.invokeMethod(
        "initEngine", engineId) as Future<Map<dynamic, dynamic>>);
    _httpPort = mapResult['httpPort'] as int?;
    _httpPassword = mapResult['httpPassword'] as String?;
    return engineId;
  }

  static Future<int?> close(int? engineId) async {
    await _methodChannel.invokeMethod("close", engineId);
    return engineId;
  }

  static Future<String> evaluate(String command, int? id,
      {String convertTo = ""}) async {
    var arguments = {
      "engineId": id,
      "command": command,
      "convertTo": convertTo
    };
    final rs = await _methodChannel.invokeMethod("evaluate", arguments);
    final String? jsResult = rs is Map || rs is List ? json.encode(rs) : rs;
    if (DEBUG) {
      print("${DateTime.now().toIso8601String()} - JS RESULT : $jsResult");
    }
    return jsResult ?? "null";
  }
}
