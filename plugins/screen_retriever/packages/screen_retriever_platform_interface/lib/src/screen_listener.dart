/// Interface for listening to screen events.
abstract mixin class ScreenListener {
  /// Called when a screen event occurs.
  void onScreenEvent(String eventName) {}
}
