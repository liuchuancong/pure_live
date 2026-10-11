/// The transport itself failed — DNS, TLS, timeout, cancellation or protocol.
///
/// These are failures below HTTP: a 4xx/5xx answer is a normal `LiveResponse`,
/// not a failure. Site-specific errors live in the site layer, not here.
sealed class TransportFailure implements Exception {
  /// A failure described by [description], carrying the underlying [cause]
  /// when the transport surfaced one.
  const new(this.description, {this.cause});

  /// Human-readable description of what failed, safe to show or log.
  final String description;

  /// The underlying error, if the transport surfaced one.
  final Object? cause;

  /// Short machine-friendly label of the failure kind, e.g. `connect`.
  String get label;

  @override
  String toString() => '$label: $description';
}

/// The connection could not be established (DNS, refused, unreachable).
final class ConnectFailure extends TransportFailure {
  /// A connect-phase failure.
  const new(super.description, {super.cause});

  @override
  String get label => 'connect';
}

/// The TLS handshake failed or the certificate was rejected.
final class TlsFailure extends TransportFailure {
  /// A TLS-phase failure.
  const new(super.description, {super.cause});

  @override
  String get label => 'tls';
}

/// A phase of the request exceeded its timeout.
final class TimeoutFailure extends TransportFailure {
  /// A timeout failure, whichever phase it occurred in.
  const new(super.description, {super.cause});

  @override
  String get label => 'timeout';
}

/// The caller cancelled the request through its cancel token.
final class CancelledFailure extends TransportFailure {
  /// A cancellation, carrying the underlying [cause] when the transport
  /// surfaced one.
  const new({super.cause}) : super('request cancelled by the caller');

  @override
  String get label => 'cancelled';
}

/// The transport broke down mid-flight in a way that is none of the above.
final class ProtocolFailure extends TransportFailure {
  /// An unexpected transport-level failure.
  const new(super.description, {super.cause});

  @override
  String get label => 'protocol';
}
