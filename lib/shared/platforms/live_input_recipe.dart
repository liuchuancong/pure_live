/// Immutable public parameters sufficient to reacquire a media input.
/// Implementations contain no route, credentials, active session or local URI.
/// Consumers bind their own playback/recording lifetime after resolution.
abstract interface class LiveInputRecipe {
  String get identity;
}
