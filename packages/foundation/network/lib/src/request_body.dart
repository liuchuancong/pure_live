// Module: lib/src/request_body.dart
// Purpose: The body encodings a spider actually meets - JSON, url-encoded form, raw bytes, multipart - each
// paired with the content type it must be sent as.
// Author: liuchuancong
// Created: 2026-10-11
//
// Handing Dio a Dart Map and hoping its default transformer picks the right encoding is how a Chinese form
// field ends up as latin-1 mojibake and how a signature body arrives as JSON when the endpoint wanted
// url-encoded. The encoding and its header are decided here, once, so a provider cannot get one right and the
// other wrong.

import 'dart:convert';

import 'package:dio/dio.dart' show FormData, MultipartFile;

/// How a body is encoded.
enum RequestBodyKind { empty, json, form, text, bytes, multipart }

/// One file part of a multipart body. Bytes rather than a path: this package stays loadable on web, where a
/// file is whatever the caller already read.
final class MultipartUpload {
  const MultipartUpload({required this.name, required this.bytes, this.filename, this.contentType});

  /// The form field name the server sees.
  final String name;
  final List<int> bytes;

  /// Sent only when set; some endpoints reject a part with no filename.
  final String? filename;
  final String? contentType;
}

/// A request body with the headers its encoding requires.
final class RequestBody {
  const RequestBody._(this.kind, this.value, this.headers);

  /// No body. Distinct from an empty string, which some endpoints read as a malformed payload.
  factory RequestBody.empty() => const RequestBody._(RequestBodyKind.empty, null, <String, String>{});

  /// UTF-8 JSON. Encoded here so a Dart `Map` never reaches the transport and gets guessed at.
  factory RequestBody.json(Object? data) => RequestBody._(
    RequestBodyKind.json,
    jsonEncode(data),
    const <String, String>{'content-type': 'application/json; charset=utf-8'},
  );

  /// `application/x-www-form-urlencoded`, percent-encoded as UTF-8.
  ///
  /// Null values are dropped: an endpoint that wants a field absent and an endpoint that wants it empty are
  /// different, and sending `sign=` when the signature is missing reads as a valid empty signature.
  factory RequestBody.form(Map<String, Object?> fields) {
    final pairs = <String>[];
    fields.forEach((name, value) {
      if (value == null) {
        return;
      }
      pairs.add('${Uri.encodeQueryComponent(name)}=${Uri.encodeQueryComponent('$value')}');
    });
    return RequestBody._(RequestBodyKind.form, pairs.join('&'), const <String, String>{
      'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
    });
  }

  /// A literal string body, for the endpoints that want XML, a plist or a hand-built query string.
  factory RequestBody.text(String text, {String contentType = 'text/plain; charset=utf-8'}) =>
      RequestBody._(RequestBodyKind.text, text, <String, String>{'content-type': contentType});

  /// A protobuf or gzipped payload, sent byte for byte.
  factory RequestBody.raw(List<int> bytes, {String contentType = 'application/octet-stream'}) =>
      RequestBody._(RequestBodyKind.bytes, bytes, <String, String>{'content-type': contentType});

  /// A multipart form: text fields plus byte parts.
  factory RequestBody.multipart({
    Map<String, Object?> fields = const <String, Object?>{},
    List<MultipartUpload> files = const <MultipartUpload>[],
  }) {
    final form = FormData();
    fields.forEach((name, value) {
      if (value != null) {
        form.fields.add(MapEntry<String, String>(name, '$value'));
      }
    });
    for (final upload in files) {
      form.files.add(
        MapEntry<String, MultipartFile>(
          upload.name,
          MultipartFile.fromBytes(
            upload.bytes,
            filename: upload.filename,
            headers: upload.contentType == null
                ? null
                : <String, List<String>>{
                    'content-type': <String>[upload.contentType!],
                  },
          ),
        ),
      );
    }
    return RequestBody._(RequestBodyKind.multipart, form, const <String, String>{});
  }

  /// A value handed to the transport as-is, with no content type attached.
  ///
  /// This is what a legacy caller that passed a bare String or Map used to get, and it is kept because Dio's
  /// default content type is what those endpoints were written against: a form body that arrives labelled
  /// `text/plain` is rejected by half the sites this app talks to.
  factory RequestBody.asIs(Object? value, {Map<String, String> headers = const <String, String>{}}) =>
      RequestBody._(RequestBodyKind.text, value, headers);

  final RequestBodyKind kind;

  /// What goes on the wire: a String, a `List<int>` or a Dio `FormData`.
  final Object? value;

  /// Headers the encoding demands. Empty for JSON-free callers that set their own content type.
  final Map<String, String> headers;

  bool get isEmpty => kind == RequestBodyKind.empty;

  /// The byte length when it is known, so a caller can bound an upload before it starts.
  int? get declaredLength {
    final body = value;
    if (body == null) {
      return 0;
    }
    if (body is List<int>) {
      return body.length;
    }
    if (body is String) {
      return utf8.encode(body).length;
    }
    return null;
  }

  @override
  String toString() => 'RequestBody(${kind.name}${declaredLength == null ? '' : ', $declaredLength bytes'})';
}
