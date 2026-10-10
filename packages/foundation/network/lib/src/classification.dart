// Module: lib/src/classification.dart
// Purpose: Turns a Dio exception, an HTTP status and a response header set into one failure vocabulary.
// Author: liuchuancong
// Created: 2026-10-11
//
// The classification used to live inside the client, which meant a provider that caught a DioException from
// its own adapter call had no way to name the failure without reconstructing it, and 404 and 5xx both came out
// as `httpStatus` even though the kinds existed. Status-to-kind is a table, not a judgement, so it is one
// table here that the client and the providers both read.

import 'package:dio/dio.dart';

import 'failure.dart';
import 'retry_policy.dart';

/// The failure for a status the transport reported.
NetworkFailureKind kindForStatus(int status) {
  if (status == 401 || status == 403) {
    return NetworkFailureKind.forbidden;
  }
  if (status == 404) {
    return NetworkFailureKind.notFound;
  }
  if (status == 408 || status == 504) {
    return NetworkFailureKind.timeout;
  }
  if (status == 429 || status == 425) {
    return NetworkFailureKind.rateLimited;
  }
  if (status >= 500) {
    return NetworkFailureKind.server;
  }
  return NetworkFailureKind.httpStatus;
}

/// Whether the same request may be sent again after [status].
///
/// 501 (not implemented) and 505 (version unsupported) are excluded: the endpoint will answer the same way no
/// matter how many times it is asked, and retrying burns the budget the next request needs.
bool isRetryableStatus(int status) {
  if (status == 408 || status == 425 || status == 429 || status == 503) {
    return true;
  }
  return status >= 500 && status != 501 && status != 505;
}

/// The failure for a response that came back but should not have.
NetworkFailure failureForStatus(
  int status, {
  required String method,
  required String url,
  Map<String, String> headers = const <String, String>{},
  Uri? actualUri,
  DateTime? now,
}) {
  final kind = kindForStatus(status);
  return NetworkFailure(
    kind: kind,
    method: method,
    url: url,
    statusCode: status,
    retryable: isRetryableStatus(status),
    retryAfter: retryAfterOf(headers, now: now ?? DateTime.now()),
    actualUri: actualUri,
    cause: kind == NetworkFailureKind.rateLimited ? 'the endpoint is throttling this client' : null,
  );
}

/// The gap the server asked for, read from `Retry-After` against the response's own `Date` when it has one.
Duration? retryAfterOf(Map<String, String> headers, {required DateTime now}) {
  final hint = headers['retry-after'] ?? headers['Retry-After'];
  if (hint == null) {
    return null;
  }
  return parseRetryAfter(hint, now: now, serverDate: parseHttpDate(headers['date'] ?? headers['Date']));
}

/// A body whose `content-length` is bigger than [maxBytes], or null when it fits or does not declare a length.
NetworkFailure? oversizeFailure(
  int? declaredLength, {
  required int maxBytes,
  required String method,
  required String url,
  int? statusCode,
}) {
  if (declaredLength == null || declaredLength <= maxBytes) {
    return null;
  }
  return NetworkFailure(
    kind: NetworkFailureKind.responseTooLarge,
    method: method,
    url: url,
    statusCode: statusCode,
    cause: 'content-length $declaredLength exceeds $maxBytes',
  );
}

/// A Dio exception as a [NetworkFailure].
///
/// A body that arrived is classified by its status; a transport that never got one is classified by what it
/// failed to do. [maxBytes] is checked against the bytes actually read as well as against `content-length`,
/// because a chunked response declares nothing and a lying server declares anything.
NetworkFailure classifyDioException(DioException error, {required String method, required String url, int? maxBytes}) {
  final response = error.response;
  if (response != null) {
    final status = response.statusCode ?? 0;
    final headers = _flatHeaders(response);
    final declared = int.tryParse(headers['content-length'] ?? '');
    final bodyLength = _bodyLength(response.data);
    final tooBig =
        oversizeFailure(declared, maxBytes: maxBytes ?? 1 << 62, method: method, url: url, statusCode: status) ??
        (bodyLength != null && maxBytes != null && bodyLength > maxBytes
            ? NetworkFailure(
                kind: NetworkFailureKind.responseTooLarge,
                method: method,
                url: url,
                statusCode: status,
                cause: 'body of $bodyLength bytes exceeds $maxBytes',
              )
            : null);
    if (tooBig != null) {
      return tooBig;
    }
    if (status >= 400) {
      return failureForStatus(status, method: method, url: url, headers: headers, actualUri: response.realUri);
    }
    if (error.type == DioExceptionType.badCertificate) {
      return NetworkFailure(
        kind: NetworkFailureKind.unreachable,
        method: method,
        url: url,
        statusCode: status,
        cause: error.message ?? 'the certificate was rejected',
        actualUri: response.realUri,
      );
    }
  }

  final kind = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => NetworkFailureKind.timeout,
    DioExceptionType.cancel => NetworkFailureKind.cancelled,
    DioExceptionType.badCertificate || DioExceptionType.connectionError => NetworkFailureKind.unreachable,
    DioExceptionType.unknown =>
      error.error is NetworkFailure ? (error.error as NetworkFailure).kind : NetworkFailureKind.unknown,
    _ => NetworkFailureKind.unknown,
  };
  final carried = error.error is NetworkFailure ? error.error as NetworkFailure : null;
  return NetworkFailure(
    kind: kind,
    method: method,
    url: url,
    statusCode: carried?.statusCode ?? response?.statusCode,
    cause: error.message ?? carried?.cause ?? error.error,
    retryable: carried?.retryable ?? _isRetryableKind(kind),
    retryAfter: carried?.retryAfter,
    actualUri: carried?.actualUri ?? response?.realUri,
  );
}

bool _isRetryableKind(NetworkFailureKind kind) => switch (kind) {
  NetworkFailureKind.timeout || NetworkFailureKind.unreachable || NetworkFailureKind.server => true,
  _ => false,
};

Map<String, String> _flatHeaders(Response<dynamic> response) {
  final out = <String, String>{};
  response.headers.forEach((name, values) {
    if (values.isNotEmpty) {
      out[name.toLowerCase()] = values.join(', ');
    }
  });
  return out;
}

int? _bodyLength(Object? data) {
  if (data is String) {
    return data.length;
  }
  if (data is List<int>) {
    return data.length;
  }
  return null;
}
