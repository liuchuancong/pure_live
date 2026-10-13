/// Where a LiveStreamFormat value on a play line came from.
enum LivePlayFormatSource {
  /// The platform's response said so (trusted).
  declared,

  /// `inferStreamFormat(url)` guessed it from the suffix/scheme; a wrong
  /// guess must stay overridable by first-byte probing.
  inferred,
}
