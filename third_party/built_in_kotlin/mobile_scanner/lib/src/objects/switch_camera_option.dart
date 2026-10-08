import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/enums/camera_lens_type.dart';

/// The options for a switch camera request.
///
/// See also:
/// - [ToggleDirection], which toggles between front and back cameras.
/// - [ToggleLensType], which cycles through available lens types.
/// - [SelectCamera], which selects a specific camera direction and/or lens type.
sealed class SwitchCameraOption {
  /// The default constructor for subclasses of [SwitchCameraOption].
  const SwitchCameraOption();
}

/// An implementation of [SwitchCameraOption] that toggles
/// between [CameraFacing.front] and [CameraFacing.back].
///
/// This option does nothing if the current [CameraFacing] direction
/// is either [CameraFacing.unknown] or [CameraFacing.external].
///
/// This is the default behavior when calling `switchCamera()`
/// without arguments.
final class ToggleDirection extends SwitchCameraOption {
  /// Creates a toggle camera direction request.
  const ToggleDirection();
}

/// An implementation of [SwitchCameraOption] that cycles through
/// available lens types on the current camera facing direction.
///
/// This option cycles through the available lens types in order:
/// normal -> wide -> zoom -> normal (wrapping around).
///
/// If a lens type is not available on the device, it will be skipped.
final class ToggleLensType extends SwitchCameraOption {
  /// Creates a toggle lens type request.
  const ToggleLensType();
}

/// An implementation of [SwitchCameraOption] that selects
/// a specific camera direction and/or lens type.
///
/// Use this option to switch to a specific camera configuration.
///
/// If [facingDirection] is `null`, the current facing direction is kept.
/// If [lensType] is [CameraLensType.any] (the default), the default lens
/// for the facing direction will be used.
final class SelectCamera extends SwitchCameraOption {
  /// Creates a select camera request.
  ///
  /// If [facingDirection] is `null`, the current facing direction is kept.
  ///
  /// The [lensType] defaults to [CameraLensType.any], which allows
  /// selecting any available lens for the given facing direction.
  const SelectCamera({
    this.facingDirection,
    this.lensType = CameraLensType.any,
  });

  /// The desired facing direction to switch to.
  ///
  /// If `null`, the current facing direction is kept.
  final CameraFacing? facingDirection;

  /// The preferred lens type to switch to.
  ///
  /// Defaults to [CameraLensType.any].
  final CameraLensType lensType;
}
