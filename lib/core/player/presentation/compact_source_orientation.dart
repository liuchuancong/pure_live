abstract final class CompactSourceOrientation {
  static bool Function()? read;

  static const double portraitAspectThreshold = 0.95;

  static bool isPortraitSize(double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) return false;
    return width / height < portraitAspectThreshold;
  }

  static bool get isPortrait => read?.call() ?? false;
}
