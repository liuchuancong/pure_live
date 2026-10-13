/// Paints an `ImageBackground` from a caller-supplied description.
///
/// The view has **no policy of its own**: every "what to paint when..."
/// decision is read from [ImageBackground]. If a field is `null` the
/// corresponding layer is simply absent, and the underlying canvas
/// shows through.
///
/// Layer order (bottom → top):
/// 1. [ImageBackground.underlay] when non-null.
/// 2. A blurred, cover-fitted copy of the same image when
///    [ImageBackground.letterboxBlurSigma] is non-null.
/// 3. The primary image, wrapped in [blurBackground] when
///    [ImageBackground.blurSigma] is positive.
/// 4. On a decode error, [ImageBackground.fallback] if provided, or
///    `SizedBox.shrink()` otherwise; the package never injects a
///    default surface.
library;

import 'package:flutter/widgets.dart';
import 'package:live_uikit_background/src/models/background_config/background_config.dart';
import 'package:live_uikit_background/src/rendering/background_blur.dart';
import 'package:live_uikit_background/src/rendering/live_background.dart';

/// Renders the still-image described by [config].
class ImageBackgroundView extends StatelessWidget {
  /// Renders [config].
  const new({required this.config, super.key});

  /// The image description to paint.
  final ImageBackground config;

  @override
  Widget build(BuildContext context) {
    final provider = _providerFor(config.source);
    final layers = <Widget>[
      if (config.underlay case final under?) LiveBackground(config: under),
      if (config.letterboxBlurSigma case final sigma? when sigma > 0)
        blurBackground(
          sigma: sigma,
          child: Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      blurBackground(
        sigma: config.blurSigma,
        child: Image(
          image: provider,
          fit: config.fit,
          alignment: config.alignment,
          gaplessPlayback: true,
          frameBuilder: _frameBuilder,
          errorBuilder: _errorBuilder,
        ),
      ),
    ];
    return Stack(fit: StackFit.passthrough, children: layers);
  }

  ImageProvider _providerFor(ImageSource source) {
    return switch (source) {
      final NetworkImageSource network => NetworkImage(network.url),
      final AssetImageSource asset => AssetImage(asset.name, package: asset.package),
      final ProviderImageSource wrapped => wrapped.provider,
    };
  }

  Widget _frameBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded || frame != null) return child;
    final placeholder = config.placeholderColor;
    if (placeholder == null) return const SizedBox.shrink();
    return ColoredBox(color: placeholder);
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    final fallback = config.fallback;
    if (fallback == null) return const SizedBox.shrink();
    return LiveBackground(config: fallback);
  }
}
