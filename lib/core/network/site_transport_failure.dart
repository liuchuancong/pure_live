import 'dart:io' show HandshakeException, SocketException;

import 'package:dio/dio.dart';

/// A site failure that can say whether the platform answered at all.
///
/// `transport` in an adapter's own taxonomy means the connection died, timed
/// out, or the reply was unreadable - which is not a statement about the room.
abstract interface class SiteTransportFailure {
  /// Whether the request failed before the platform gave a usable answer.
  bool get isSiteUnreachable;
}

/// Whether a failed site request never got anything to read.
///
/// dio classifies [SocketException] as a connection error but not a TLS reset,
/// which arrives as [DioExceptionType.unknown] wrapping the exception.
bool isUnreachableSiteFailure(Object error) => switch (error) {
  final SiteTransportFailure failure => failure.isSiteUnreachable,
  DioException(:final type, :final error) =>
    const {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        }.contains(type) ||
        error is HandshakeException ||
        error is SocketException,
  HandshakeException() || SocketException() => true,
  _ => false,
};
