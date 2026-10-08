/// The authorization state of the scanner.
enum MobileScannerAuthorizationState {
  /// The scanner has not yet requested the required permissions.
  undetermined(0),

  /// The scanner has the required permissions.
  authorized(1),

  /// The user denied the required permissions.
  denied(2);

  const MobileScannerAuthorizationState(this.rawValue);

  factory MobileScannerAuthorizationState.fromRawValue(int value) {
    switch (value) {
      case 0:
        return MobileScannerAuthorizationState.undetermined;
      case 1:
        return MobileScannerAuthorizationState.authorized;
      case 2:
        return MobileScannerAuthorizationState.denied;
      default:
        throw ArgumentError.value(value, 'value', 'Invalid raw value.');
    }
  }

  /// The raw value for the state.
  final int rawValue;
}
