/// The type of camera lens based on focal length.
enum CameraLensType {
  /// A normal/standard lens (typically around 26-35mm equivalent).
  ///
  /// This is the standard wide angle lens found on most smartphones.
  normal(0),

  /// An ultra-wide angle lens (typically around 13-16mm equivalent).
  ///
  /// This type of lens captures a wider field of view than the normal lens.
  wide(1),

  /// A telephoto/zoom lens (typically 50mm+ equivalent).
  ///
  /// This type of lens provides optical zoom capabilities.
  zoom(2),

  /// Any available lens type.
  ///
  /// When this is specified, the first available camera for the given
  /// facing direction will be used, regardless of lens type.
  any(-1);

  const CameraLensType(this.rawValue);

  factory CameraLensType.fromRawValue(int? value) {
    return switch (value) {
      0 => normal,
      1 => wide,
      2 => zoom,
      _ => any,
    };
  }

  /// The raw value for the camera lens type.
  final int rawValue;
}
