/// The state of the flashlight.
enum TorchState {
  /// The flashlight turns on automatically in low light conditions.
  ///
  /// This is currently only supported on iOS and MacOS.
  auto(2),

  /// The flashlight is off.
  off(0),

  /// The flashlight is on.
  on(1),

  /// The flashlight is unavailable.
  unavailable(-1);

  const TorchState(this.rawValue);

  factory TorchState.fromRawValue(int value) {
    switch (value) {
      case -1:
        return TorchState.unavailable;
      case 0:
        return TorchState.off;
      case 1:
        return TorchState.on;
      case 2:
        return TorchState.auto;
      default:
        throw ArgumentError.value(value, 'value', 'Invalid raw value.');
    }
  }

  /// The raw value for the torch state.
  final int rawValue;
}
