import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_js/flutter_js.dart';
import 'package:sync_http/sync_http.dart';

// ReceivePort _callDartReceivePort = new ReceivePort();

// void _setupCallDartPorts() {
//   IsolateNameServer.registerPortWithName(
//       _callDartReceivePort.sendPort, 'QuickJsServiceCallDart');

//   _callDartReceivePort.listen((portMessage) {
//     final decodedMessage = (portMessage as String).split(':');
//     int idEngine = int.parse(decodedMessage[0]);
//     String channel = decodedMessage[1];
//     String message = utf8.decode(base64.decode(decodedMessage[2]));
//   });
// }

class QuickJsService extends JavascriptRuntime {
  ReceivePort _receivePort = new ReceivePort();
  SendPort? _callServerSendPort;

  bool _ready = false;
  String? _dartAddress;

  final FlutterJs _flutterJs;

  QuickJsService(this._flutterJs) {
    _startServer();
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, 'QuickJsService');
    initChannelFunctions();
  }

  bool get isReady => _ready;
  _startServer() async {
    _receivePort.listen((message) async {
      if (_dartAddress == null) {
        _dartAddress = message;
        _ready = true;
        return;
      }
      if (_callServerSendPort == null) {
        _callServerSendPort = message;
      }
    });
    Isolate.spawn(startQuickJsServer, _receivePort.sendPort);
  }

  void dispose() {
    this._callServerSendPort!.send('STOP');
    _flutterJs.dispose();
  }

  JsEvalResult evaluate(String code, {String? sourceUrl}) {
    var request = SyncHttpClient.postUrl(new Uri.http(
      "localhost:${FlutterJs.httpPort}",
      "",
      {
        "id": _flutterJs.id.toString(),
        "password": FlutterJs.httpPassword,
      },
    ));
    request..write(code);
    var response = request.close();

    var result = response.body!;

    try {
      result = json.decode(result);
    } catch (e) {}

    return JsEvalResult(
      response.body != null && response.body!.isNotEmpty ? result : "",
      null,
      isPromise: response.body == 'isPromise',
      isError: response.statusCode != 200,
    );
  }

  @override
  JsEvalResult callFunction(dynamic fn, dynamic obj) {
    throw UnimplementedError(
        'Call function yet not implemented in FlutterJS through Platform Channel');
    // _flutterJs.callFunction(fn, obj);
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    if (T is int) {
      return int.parse(jsValue.stringResult) as T;
    } else if (T is Map || T is List) {
      return jsonDecode(jsValue.stringResult) as T?;
    } else if (T is double) {
      return double.parse(jsValue.stringResult) as T;
    } else if (T is num) {
      return num.parse(jsValue.stringResult) as T;
    }
    return jsValue.stringResult as T;
  }

  @override
  int executePendingJob() {
    evaluate('(function(){})();');
    return 0;
  }

  @override
  String getEngineInstanceId() {
    return _flutterJs.id.toString();
  }

  @override
  void initChannelFunctions() {
    JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()] = {};
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    return jsValue.stringResult;
  }

  @override
  void setInspectable(bool inspectable) {
    // Nothing to do.
  }

  @override
  bool setupBridge(String channelName, dynamic Function(dynamic args) fn) {
    // final channelFunctionCallbacks =
    //     JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()];
    // if (channelFunctionCallbacks.keys.contains(channelName)) return false;

    // channelFunctionCallbacks[channelName] = fn;
    _flutterJs.addChannel(channelName, (args) {
      final mapArgs = json.decode(args!);
      final res = fn(mapArgs);
      this.evaluate("""
         FLUTTERJS_pendingMessages['${mapArgs['id']}'].resolve(${json.encode(res)});
      """
          .trim());
      return Future.value(res);
    }, dartChannelAddress: 'http://$_dartAddress');

    return true;
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) async {
    String strResult = await _flutterJs.eval(code);
    return JsEvalResult(
      strResult,
      null,
      isError: strResult.startsWith('ERROR:'),
      isPromise: strResult == '[object Promise]',
    );
  }
}

void startQuickJsServer(SendPort sendPort) async {
  var server = new QuickJsSyncServer();

  server.serve().then((address) {
    sendPort.send(address);
    sendPort.send(server.dispatchSendPort);
  });
}

class QuickJsSyncServer {
  /// Server address
  InternetAddress? address;

  SendPort get dispatchSendPort => _dispatchPort.sendPort;
  late ReceivePort _dispatchPort;

  ReceivePort _receiveCallDartResponsePort = ReceivePort();

  /// Optional server port (note: might be already taken)
  /// Defaults to 0 (binds server to a random free port)
  late int port;
  late HttpServer _server;
  SyncHttpClient? client;

  QuickJsSyncServer() {
    address = InternetAddress.loopbackIPv4;
    port = 0;
    _dispatchPort = new ReceivePort();

    IsolateNameServer.registerPortWithName(
      _receiveCallDartResponsePort.sendPort,
      'ReceiveCallDartResponsePort',
    );

    _dispatchPort.listen((message) {
      if (message == 'STOP') {
        _server.close();
      }
    });
  }

  /// Actual port server is listening on
  get boundPort => _server.port;

  /// Starts server
  Future<String> serve() async {
    _server = await HttpServer.bind(this.address, this.port);
    _server.listen(_handleReq);
    return '${_server.address.address}:${_server.port}';
  }

  _handleReq(HttpRequest request) async {
    String path = request.requestedUri.path.replaceFirst('/', '');

    if (path == '') {
      path = 'callDart';
    }

    if (path == 'callDart') {
      try {
        // if not is eval it should be call to Dart
        String message = await utf8.decoder.bind(request).join();
        String? idEngine = request.uri.queryParameters['id'];
        String? channel = request.uri.queryParameters['channel'];

        final callDartPort =
            IsolateNameServer.lookupPortByName('QuickJsServiceCallDart')!;

        callDartPort
            .send("$idEngine:$channel:${base64.encode(utf8.encode(message))}");

        final result = await _receiveCallDartResponsePort.take(1).first;

        var response = request.response;
        response
          ..contentLength = result.length
          ..write(result)
          ..close();
      } catch (err) {
        request.response
          ..statusCode = 500
          ..write("ERROR")
          ..close();
      }
    } else {}
  }
}
