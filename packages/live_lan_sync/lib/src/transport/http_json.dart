import 'dart:convert' show jsonDecode, utf8;

import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;

/// JSON body codecs shared by the protocol client, the pairing channel and
/// the server: every body on the wire is a UTF-8 JSON object.
abstract final class HttpJson {
  /// Decodes [body] as a JSON object; an empty body is an empty object.
  ///
  /// Throws a [LanSyncError] with `dataValidation` for anything else.
  static Map<String, Object?> decodeObject(List<int> body) {
    if (body.isEmpty) return <String, Object?>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'body_not_json',
        message: 'The body is not valid JSON.',
      );
    }
    return switch (decoded) {
      final Map<Object?, Object?> object => object.cast<String, Object?>(),
      _ => throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'body_not_object',
        message: 'The body must be a JSON object.',
      ),
    };
  }

  /// The typed error a peer answered with, or a transport error when the
  /// answer carries none.
  static LanSyncError errorFromResponse(int status, List<int> body, {String? deviceId}) {
    Map<String, Object?> errorJson;
    try {
      errorJson = switch (decodeObject(body)['error']) {
        final Map<Object?, Object?> error => error.cast<String, Object?>(),
        _ => <String, Object?>{},
      };
    } on LanSyncError {
      errorJson = <String, Object?>{};
    }
    final category = switch (errorJson['category']) {
      final String name => LanSyncErrorCategory.values.where((c) => c.name == name).firstOrNull,
      _ => null,
    };
    return LanSyncError(
      category: category ?? LanSyncErrorCategory.transport,
      code: switch (errorJson['code']) {
        final String code => code,
        _ => 'request_failed',
      },
      message: switch (errorJson['message']) {
        final String message => message,
        _ => 'The peer refused the request.',
      },
      retryable: errorJson['retryable'] == true,
      deviceId: deviceId,
      debugContext: 'status: $status',
    );
  }
}
