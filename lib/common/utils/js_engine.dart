import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

class JsEngine {
  static JavascriptRuntime? _jsRuntime;
  static JavascriptRuntime get jsRuntime => _jsRuntime!;

  static Future<void> init() async {
    if(_jsRuntime == null) {
      _jsRuntime = getJavascriptRuntime();
      jsRuntime.enableHandlePromises();
      await JsEngine.loadDouyinSdk();
      await JsEngine.loadCryptoJsSdk();
    }
  }

  static Future<void> loadDouyinSdk() async {
    final webmssdkjs = await rootBundle.loadString('assets/js/webmssdk.js');
    jsRuntime.evaluate(webmssdkjs);
  }

  static Future<void> loadDouyinExEcutorSdk() async {
    final douyinsdkjs = await rootBundle.loadString('assets/js/douyin.js');
    jsRuntime.evaluate(douyinsdkjs);
  }



  static JsEvalResult evaluate(String code) {
    return jsRuntime.evaluate(code);
  }

  static Future<JsEvalResult> evaluateAsync(String code) {
    return jsRuntime.evaluateAsync(code);
  }

  static dynamic onMessage(String channelName, dynamic Function(dynamic) fn) {
    return jsRuntime.onMessage(channelName, (args) => null);
  }

  static dynamic sendMessage({required String channelName, required List<String> args, String? uuid}) {
    return jsRuntime.sendMessage(channelName: channelName, args: args);
  }

  static Future<void> loadCryptoJsSdk() async {
    final coreJS = await rootBundle.loadString('assets/js/crypto-js-core.js');
    final md5JS = await rootBundle.loadString('assets/js/crypto-js-md5.js');
    jsRuntime.evaluate(coreJS);
    jsRuntime.evaluate(md5JS);
  }

}
