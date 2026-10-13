/// Stable site-layer errors, one class per business meaning.
///
/// Adapters throw these instead of raw platform exceptions; UI and
/// playback pattern-match on the type. The [SiteError.label] values are
/// machine-stable.
sealed class SiteError implements Exception {
  /// An error with a human-readable [message].
  const new(this.message);

  /// What went wrong, safe to show or log.
  final String message;

  /// Short machine-friendly category label.
  String get label;

  @override
  String toString() => '$label: $message';

  /// The passed room belongs to another site.
  static SiteError platformMismatch({required String expected, required String actual}) =>
      SitePlatformMismatchError(expected: expected, actual: actual);

  /// The room id is empty or malformed for the site.
  static SiteError invalidRoomId(String roomId) => SiteInvalidRoomIdError(roomId);
}

/// The room passed to this site belongs to a different site.
final class SitePlatformMismatchError extends SiteError {
  /// A mismatch between the [expected] site id and the [actual] one.
  const new({required this.expected, required this.actual}) : super('room belongs to $actual, this site is $expected');

  /// The site id the room carries.
  final String actual;

  /// The site id this site expects.
  final String expected;

  @override
  String get label => 'platformMismatch';
}

/// The room id is empty or malformed.
final class SiteInvalidRoomIdError extends SiteError {
  /// The offending room id.
  const new(String roomId) : super('invalid room id: "$roomId"');

  @override
  String get label => 'invalidRoomId';
}

/// The requested room does not exist or is gone.
final class SiteNotFoundError extends SiteError {
  /// Nothing exists under the requested identity.
  const new(super.message);

  @override
  String get label => 'notFound';
}

/// The platform demands a login this session cannot provide.
final class SiteNeedsLoginError extends SiteError {
  /// The operation requires credentials.
  const new(super.message);

  @override
  String get label => 'needsLogin';
}

/// The platform rate-limited or temporarily refused the request.
final class SiteRateLimitedError extends SiteError {
  /// The platform pushed back.
  const new(super.message);

  @override
  String get label => 'rateLimited';
}

/// The platform's risk control intercepted the request.
final class SiteRiskControlError extends SiteError {
  /// Risk control refused the operation.
  const new(super.message);

  @override
  String get label => 'riskControl';
}

/// The stream or room is blocked in this region.
final class SiteRegionBlockedError extends SiteError {
  /// Region restriction applies.
  const new(super.message);

  @override
  String get label => 'regionBlocked';
}

/// The site's web API changed and the adapter can no longer parse it.
final class SiteApiChangedError extends SiteError {
  /// The adapter needs an update.
  const new(super.message);

  @override
  String get label => 'apiChanged';
}

/// The room is known but has nothing to play right now (offline, ended
/// without a recording, or a stream whose seat moved away). Distinct from
/// [SiteNotFoundError]: the room exists, it just is not playable.
final class SiteStreamUnavailableError extends SiteError {
  /// Nothing is currently playable for this room.
  const new(super.message);

  @override
  String get label => 'streamUnavailable';
}
