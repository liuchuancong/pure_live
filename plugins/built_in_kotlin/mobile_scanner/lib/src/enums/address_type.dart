/// Address type constants.
enum AddressType {
  /// Unknown address type.
  unknown(0),

  /// Work address.
  work(1),

  /// Home address.
  home(2);

  const AddressType(this.rawValue);

  factory AddressType.fromRawValue(int value) {
    switch (value) {
      case 0:
        return AddressType.unknown;
      case 1:
        return AddressType.work;
      case 2:
        return AddressType.home;
      default:
        return AddressType.unknown;
    }
  }

  /// The raw address type value.
  final int rawValue;
}
