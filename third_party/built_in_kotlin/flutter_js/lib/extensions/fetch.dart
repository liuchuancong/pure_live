import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/javascript_runtime.dart';
import './xhr.dart';

var _fetchDebug = false;

setFetchDebug(bool value) => _fetchDebug = value;

extension JavascriptRuntimeFetchExtension on JavascriptRuntime {
  Future<JavascriptRuntime> enableFetch() async {
    debug('Before enable xhr');
    enableXhr();
    debug('After enable xhr');
    final fetchPolyfill =
        await rootBundle.loadString('packages/flutter_js/assets/js/fetch.js');
    debug('Loaded fetchPolyfill');
    final evalFetchResult = evaluate(fetchPolyfill);
    debug('Eval Fetch Result: $evalFetchResult');
    return this;
  }
}

void debug(String message) {
  if (_fetchDebug) {
    print('JavascriptRuntimeFetchExtension: $message');
  }
}
