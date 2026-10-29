/// The reference sync socket's two transport details beyond plain JSON:
/// the `cg_`+gzip framing for payloads past 1 KiB (both directions), and the
/// message2call RPC array format the two ends speak over it. Both sides
/// expose one flat method table — the reference's `callObj` — addressed by
/// name only; the remote "groups" are local queue bookkeeping.
library;

import 'dart:convert' show base64Decode, base64Encode, jsonDecode, jsonEncode, utf8;
import 'dart:io' show GZipCodec;

/// The reference sync socket's two transport details beyond plain JSON:

/// the `cg_`+gzip framing for payloads past 1 KiB (both directions), and the
/// message2call RPC array format the two ends speak over it. Both sides
/// expose one flat method table — the reference's `callObj` — addressed by
/// name only; the remote "groups" are local queue bookkeeping.
/// The 1 KiB threshold the reference frames past.
const int _kGzipThreshold = 1024;

/// Wraps a socket text payload; payloads past the threshold go out gzipped
/// behind the `cg_` marker.
String musicSyncEncodeFrame(String data) =>
    data.length > _kGzipThreshold ? 'cg_${base64Encode(GZipCodec().encode(utf8.encode(data)))}' : data;

/// Unwraps a socket text payload, gzip or plain.
String musicSyncDecodeFrame(String data) =>
    !data.startsWith('cg_') ? data : utf8.decode(GZipCodec().decode(base64Decode(data.substring(3))));

/// A function argument we hand the remote; the remote calls back through
/// [name] with a CALLBACK_REQUEST frame.
final class MusicSyncRpcCallback {
  MusicSyncRpcCallback(this.name);

  final String name;
}

/// An incoming call the remote made on one of our exposed handlers.
final class MusicSyncRpcRequest {
  MusicSyncRpcRequest({required this.name, required this.args, required this.callbackNames});

  /// The unique call name; replies must carry it back.
  final String name;

  /// The positional arguments, with function slots left as
  /// [MusicSyncRpcCallback].
  final List<Object?> args;

  /// Names behind the function slots, aligned with [args].
  final List<String> callbackNames;

  /// Answers the call.
  String reply(Object? result) => jsonEncode([1, name, null, result]);

  /// Answers the call with a failure.
  String replyError(String message) => jsonEncode([1, name, <String, Object?>{'message': message}]);

  /// The name of the callback argument at [index], null when it was data.
  String? callbackAt(int index) {
    final arg = args[index];
    return arg is MusicSyncRpcCallback ? arg.name : null;
  }
}

/// A reply from the remote to a call we made.
final class MusicSyncRpcResponse {
  MusicSyncRpcResponse({required this.name, required this.error, this.result});

  final String name;

  /// `{message: …}`-shaped failure, null on success.
  final Object? error;
  final Object? result;

  String get errorMessage => switch (error) {
    {'message': final Object message} => message.toString(),
    _ => 'sync call failed',
  };
}

/// A remote call asking one of our callback arguments to run.
final class MusicSyncRpcCallbackRequest {
  MusicSyncRpcCallbackRequest({required this.name, required this.args});

  final String name;
  final List<Object?> args;

  /// Answers the callback.
  String reply(Object? result) => jsonEncode([3, name, null, result]);
}

/// Encodes a call the remote should run:
/// `[0, name, path, args, callbackIndexes]`. Function arguments go out as
/// their generated names; [callbackIndexes] marks those positions.
String musicSyncEncodeRequest(String name, List<Object?> args, List<int> callbackIndexes) => jsonEncode([
  0,
  name,
  const <String>[],
  [
    for (final arg in args)
      if (arg is MusicSyncRpcCallback) arg.name else arg,
  ],
  callbackIndexes,
]);

/// Answers a callback the remote invoked on our function argument.
String musicSyncEncodeCallbackResponse(String callbackName, List<Object?> args) =>
    jsonEncode([3, callbackName, null, args]);

/// Parses one socket message; null when it is not one of the shapes we
/// handle (the reference also sends bare `ping` keep-alives).
Object? musicSyncParseMessage(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! List || decoded.isEmpty) return null;
  return switch (decoded[0]) {
    0 when decoded.length >= 5 && decoded[2] is List && decoded[3] is List && decoded[4] is List => _parseRequest(
      decoded[1] as String,
      decoded[3] as List<Object?>,
      decoded[4] as List<Object?>,
    ),
    1 when decoded.length >= 3 => MusicSyncRpcResponse(
      name: decoded[1] as String,
      error: decoded[2],
      result: decoded.length > 3 ? decoded[3] : null,
    ),
    2 when decoded.length >= 3 => MusicSyncRpcCallbackRequest(
      name: decoded[1] as String,
      args: decoded[2] is List<Object?> ? decoded[2] as List<Object?> : const <Object?>[],
    ),
    _ => null,
  };
}

MusicSyncRpcRequest _parseRequest(String name, List<Object?> args, List<Object?> indexes) {
  final rebuilt = <Object?>[];
  final callbackNames = <String>[];
  final callbackPositions = <int>[for (final index in indexes) if (index is int) index];
  for (var i = 0; i < args.length; i++) {
    if (callbackPositions.contains(i)) {
      final callbackName = args[i]?.toString() ?? '';
      callbackNames.add(callbackName);
      rebuilt.add(MusicSyncRpcCallback(callbackName));
    } else {
      rebuilt.add(args[i]);
    }
  }
  return MusicSyncRpcRequest(name: name, args: rebuilt, callbackNames: callbackNames);
}
