/// Isolates asynchronous native events between retained-player source loads.
///
/// A native player is intentionally reused for fast quality, line and room
/// switches. Its callbacks, however, are not tagged with the Dart request that
/// produced them. Events are therefore fenced while a replacement open is in
/// progress and accepted again only after that open completes.
///
/// Native `path` remains useful diagnostic evidence, but it is deliberately not
/// a playback gate. libmpv may expose a redirected, protocol-rewritten or
/// normalized URL (and some Android builds expose no path at all). Requiring an
/// exact string match made a healthy stream look permanently unopened, which in
/// turn suppressed playing and geometry events and triggered false recovery.
class SourceEventFence {
  int _generation = 0;
  bool _opening = false;
  bool _nativeSourceConfirmed = false;
  String? _requestedUrl;

  int get generation => _generation;
  bool get isOpening => _opening;
  bool get isNativeSourceConfirmed => _nativeSourceConfirmed;

  /// Whether asynchronous work still belongs to the currently opened source
  /// generation. Unlike [accepts], this deliberately does not require a
  /// path callback: some native open failures happen before mpv publishes its
  /// first path event, but a generation-scoped readiness deadline must
  /// still be able to terminate that attempt.
  bool isCurrentGeneration(int eventGeneration) {
    return eventGeneration == _generation && !_opening;
  }

  int begin(String? requestedUrl) {
    _generation++;
    _opening = true;
    _nativeSourceConfirmed = false;
    _requestedUrl = requestedUrl?.trim();
    return _generation;
  }

  void observeNativeSources(Iterable<String> urls) {
    final requested = _requestedUrl;
    if (requested == null || requested.isEmpty) return;
    // Once the native path has matched in this generation, later empty
    // property notifications from mpv teardown must not revoke it. [begin]
    // resets confirmation before every replacement source.
    if (urls.any((url) => url == requested)) _nativeSourceConfirmed = true;
  }

  void finishOpen(Iterable<String> urls) {
    observeNativeSources(urls);
    _opening = false;
  }

  bool accepts(int eventGeneration) {
    return isCurrentGeneration(eventGeneration);
  }

  void clear() {
    _generation++;
    _opening = false;
    _nativeSourceConfirmed = false;
    _requestedUrl = null;
  }
}
