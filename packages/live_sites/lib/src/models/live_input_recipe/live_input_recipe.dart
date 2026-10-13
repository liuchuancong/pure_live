/// Immutable public parameters sufficient to reacquire a media input that has
/// no plain URL (Bigo, FC2, niconico). Carries no route, credentials, active
/// session or local URI; playback and recording bind their own lifetime after
/// resolving it.
abstract interface class LiveInputRecipe {
  /// Stable identity of the input, for comparing selections.
  String get identity;
}
