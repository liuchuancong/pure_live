/// Defines the window operations required by a desktop title bar.
///
/// The application Shell implements this interface using the selected
/// platform window plugin and injects the implementation into `PureTitleBar`.
abstract interface class WindowChromeActions {
  /// Minimizes the current window.
  Future<void> minimize();

  /// Toggles between maximized and restored window states.
  Future<void> toggleMaximize();

  /// Returns whether the current window is maximized.
  Future<bool> isMaximized();

  /// Closes the current window.
  Future<void> close();

  /// Starts dragging the current window.
  Future<void> startDragging();
}
