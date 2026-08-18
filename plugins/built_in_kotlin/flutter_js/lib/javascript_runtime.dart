import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'js_eval_result.dart';

class FlutterJsPlatformEmpty extends JavascriptRuntime {
  @override
  JsEvalResult callFunction(Pointer<NativeType> fn, Pointer<NativeType> obj) {
    throw UnimplementedError();
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}

  @override
  JsEvalResult evaluate(String code, {String? sourceUrl}) {
    throw UnimplementedError();
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) {
    throw UnimplementedError();
  }

  @override
  int executePendingJob() {
    throw UnimplementedError();
  }

  @override
  String getEngineInstanceId() {
    throw UnimplementedError();
  }

  @override
  void initChannelFunctions() {
    throw UnimplementedError();
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    throw UnimplementedError();
  }

  @override
  bool setupBridge(String channelName, void Function(dynamic args) fn) {
    throw UnimplementedError();
  }

  @override
  void setInspectable(bool inspectable) {
    throw UnimplementedError();
  }
}

abstract class JavascriptRuntime {
  static bool debugEnabled = false;

  @protected
  JavascriptRuntime init() {
    initChannelFunctions();
    _setupConsoleLog();
    _setupSetTimeout();
    return this;
  }

  Map<String, dynamic> localContext = {};

  Map<String, dynamic> dartContext = {};

  void dispose();

  static Map<String, Map<String, Function(dynamic arg)>>
      _channelFunctionsRegistered = {};

  static Map<String, Map<String, Function(dynamic arg)>>
      get channelFunctionsRegistered => _channelFunctionsRegistered;

  JsEvalResult evaluate(String code, {String? sourceUrl});

  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl});

  JsEvalResult callFunction(Pointer fn, Pointer obj);

  T? convertValue<T>(JsEvalResult jsValue);

  String jsonStringify(JsEvalResult jsValue);

  @protected
  void initChannelFunctions();

  int executePendingJob();

  void _setupConsoleLog() {
    evaluate("""
    var console = {
      log: function() {
        sendMessage('ConsoleLog', JSON.stringify(['log', ...arguments]));
      },
      warn: function() {
        sendMessage('ConsoleLog', JSON.stringify(['info', ...arguments]));
      },
      error: function() {
        sendMessage('ConsoleLog', JSON.stringify(['error', ...arguments]));
      }
    }""");
    onMessage('ConsoleLog', (dynamic args) {
      args..removeAt(0);
      String output = args.join(' ');
      print(output);
    });
  }

  void _setupSetTimeout() {
    evaluate("""
      var __NATIVE_FLUTTER_JS__setTimeoutCount = -1;
      var __NATIVE_FLUTTER_JS__setTimeoutCallbacks = {};
      function setTimeout(fnTimeout, timeout) {
        // console.log('Set Timeout Called');
        try {
        __NATIVE_FLUTTER_JS__setTimeoutCount += 1;
          var timeoutIndex = '' + __NATIVE_FLUTTER_JS__setTimeoutCount;
          __NATIVE_FLUTTER_JS__setTimeoutCallbacks[timeoutIndex] =  fnTimeout;
          ;
          // console.log(typeof(sendMessage));
          // console.log('BLA');
          sendMessage('SetTimeout', JSON.stringify({ timeoutIndex, timeout}));
            
        } catch (e) {
          console.error('ERROR HERE',e.message);
        }
      };
      1
    """);
    //print('SET TIMEOUT EVAL RESULT: $setTImeoutResult');
    onMessage('SetTimeout', (dynamic args) {
      try {
        int duration = args['timeout'] ?? 0;
        String idx = args['timeoutIndex'];

        Timer(Duration(milliseconds: duration), () {
          evaluate("""
            __NATIVE_FLUTTER_JS__setTimeoutCallbacks[$idx].call();
            delete __NATIVE_FLUTTER_JS__setTimeoutCallbacks[$idx];
          """);
        });
      } on Exception catch (e) {
        print('Exception no setTimeout: $e');
      } on Error catch (e) {
        print('Erro no setTimeout: $e');
      }
    });
  }

  sendMessage({
    required String channelName,
    required List<String> args,
    String? uuid,
  }) {
    if (uuid != null) {
      evaluate(
          "DART_TO_QUICKJS_CHANNEL_sendMessage('$channelName', '${jsonEncode(args)}', '$uuid');");
    } else {
      evaluate(
          "DART_TO_QUICKJS_CHANNEL_sendMessage('$channelName', '${jsonEncode(args)}');");
    }
  }

  onMessage(String channelName, dynamic Function(dynamic args) fn) {
    setupBridge(channelName, fn);
  }

  bool setupBridge(String channelName, void Function(dynamic args) fn);

  String getEngineInstanceId();

  void setInspectable(bool inspectable);
}
