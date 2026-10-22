import 'package:flutter_svg/flutter_svg.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureIconSource, PureIconWidget;

/// The brand/product artwork seam.
///
/// Multi-colour logos draw as SVG and are never tinted: give them the
/// `preserve` role at the call site and register them with
/// [brandSvgSource]. The files live under `assets/icons/brand/` (declared
/// in the app's pubspec assets); a key whose svg is absent should stay
/// unregistered rather than point at a missing asset.
PureIconSource brandSvgSource(String assetName, {double? height}) => PureIconWidget(
  (context, renderContext) =>
      SvgPicture.asset('assets/icons/brand/$assetName.svg', height: height ?? renderContext.style.size),
);
