part of '../floating.dart';

/// Base configuration data class for PiP mode launch details.
sealed class EnableArguments {
  /// Provide [aspectRatio] to override default 16/9 aspect ratio.
  /// [aspectRatio] must fit into Android-supported values:
  /// min: 1/2.39, max: 2.39/1, otherwise [RationalNotMatchingAndroidRequirementsException]
  /// will be thrown.
  final Rational aspectRatio;

  /// Provide [sourceRectHint] to specify where the portion of the UI you'll
  /// keep after entering the PiP mode is located.
  ///
  /// It makes the OS able to animate the PiP mode entrance with
  /// a nicer animation.
  final Rectangle<int>? sourceRectHint;

  const EnableArguments({
    this.aspectRatio = const Rational.landscape(),
    this.sourceRectHint,
  });
}

/// Configuration data for manual PiP mode launch.
///
/// To be used when the app shall shrink on a direct user action in
/// the app's UI.
///
/// See [OnLeavePiP], shall the app should enter the PiP mode automatically
/// upon system-side action, e.g. on Home navigation gesture.
class ImmediatePiP extends EnableArguments {
  const ImmediatePiP({
    super.aspectRatio = const Rational.landscape(),
    super.sourceRectHint,
  });
}

/// Configuration data for automatic PiP mode launch
///
/// To be used when the app shall shrink on an indirect user action,
/// e.g. on Home navigation gesture.
///
/// See [ImmediatePiP] if the app should enter PiP immediately.
///
///
class OnLeavePiP extends EnableArguments {
  const OnLeavePiP({
    super.aspectRatio = const Rational.landscape(),
    super.sourceRectHint,
  });
}
