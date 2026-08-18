/// The detection speed of the scanner.
enum DetectionSpeed {
  /// The scanner will only scan a barcode once, and never again until another
  /// barcode has been scanned.
  ///
  /// Bear in mind that this mode analyzes every frame,
  /// in order to check if the value has changed.
  noDuplicates(0),

  /// The barcode scanner will scan barcodes,
  /// while respecting the configured scan timeout between individual scans.
  normal(1),

  /// The barcode scanner will scan barcodes, without any restrictions.
  ///
  /// Bear in mind that this mode can cause memory issues on older devices.
  unrestricted(2);

  const DetectionSpeed(this.rawValue);

  factory DetectionSpeed.fromRawValue(int value) {
    switch (value) {
      case 0:
        return DetectionSpeed.noDuplicates;
      case 1:
        return DetectionSpeed.normal;
      case 2:
        return DetectionSpeed.unrestricted;
      default:
        throw ArgumentError.value(value, 'value', 'Invalid raw value.');
    }
  }

  /// The raw value for the detection speed.
  final int rawValue;
}
