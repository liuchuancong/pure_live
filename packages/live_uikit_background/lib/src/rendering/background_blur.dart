/// Gaussian blur helper shared by the media-backed background views.
///
/// Solid and gradient backgrounds never route through this helper: blurring
/// a flat surface changes no pixel and still costs an offscreen pass. A
/// `sigma` of `0` returns the child unchanged, which also avoids an
/// unnecessary `saveLayer`. `TileMode.decal` is used so the blurred edge
/// does not stretch the picture's border pixels into the letterbox bars.
///
/// Callers pick the sigma themselves; the package does not ship a "good
/// enough" default.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Wraps [child] in an `ImageFiltered` Gaussian blur of the given
/// [sigma]; returns [child] unchanged when [sigma] is not positive.
Widget blurBackground({required Widget child, required double sigma}) {
  if (sigma <= 0) return child;
  return ImageFiltered(
    imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: ui.TileMode.decal),
    child: child,
  );
}
