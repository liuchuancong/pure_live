import 'dart:io' show HandshakeException, SocketException;

import 'package:dio/dio.dart';

/// A site adapter failure that can say whether the platform answered at all.
///
/// Every adapter keeps its own failure enum, and they all settled on the same
/// name for the case that is not about the room: `transport` means the
/// connection died, timed out, or the reply was something the adapter could
/// not read as a status. That is a statement about reaching the platform, so it
/// must not be reported as "读取视频信息失败" — there was no information to read.
abstract interface class SiteTransportFailure {
  /// Whether the request failed before the platform gave a usable answer.
  bool get isSiteUnreachable;
}

/// Whether a failed site request never got anything to read.
///
/// Three shapes carry that: an adapter that declares it, a transport error that
/// dio classified (a TLS reset is not classified — dio maps only
/// [SocketException] onto a connection type, so a handshake broken on the wire
/// arrives as a [DioExceptionType.unknown] wrapping the [HandshakeException]),
/// and a caller that lets the raw dart:io error through unwrapped.
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
