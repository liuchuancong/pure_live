/// The facing of a camera.
enum CameraFacing {
  /// The camera is a front facing camera.
  ///
  /// This type of camera always faces the user.
  front(0),

  /// The camera is a back facing camera.
  ///
  /// This type of camera always faces away from the user.
  back(1),

  /// The camera is an external camera.
  ///
  /// For example a USB-camera.
  external(2),

  /// The camera facing direction is unknown.
  unknown(-1);

  const CameraFacing(this.rawValue);

  factory CameraFacing.fromRawValue(int? value) {
    switch (value) {
      case 0:
        return front;
      case 1:
        return back;
      case 2:
        return external;
      default:
        return unknown;
    }
  }

  /// The raw value for the camera facing direction.
  final int rawValue;
}
