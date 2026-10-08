/// Phone number format type constants.
enum PhoneType {
  /// Unknown phone type.
  unknown(0),

  /// Work phone.
  work(1),

  /// Home phone.
  home(2),

  /// Fax machine.
  fax(3),

  /// Mobile phone.
  mobile(4);

  const PhoneType(this.rawValue);

  factory PhoneType.fromRawValue(int value) {
    switch (value) {
      case 0:
        return PhoneType.unknown;
      case 1:
        return PhoneType.work;
      case 2:
        return PhoneType.home;
      case 3:
        return PhoneType.fax;
      case 4:
        return PhoneType.mobile;
      default:
        return PhoneType.unknown;
    }
  }

  /// The raw phone type value.
  final int rawValue;
}
