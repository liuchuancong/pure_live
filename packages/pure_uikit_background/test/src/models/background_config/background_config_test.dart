import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart' show AlignmentGeometry;
import 'package:flutter/widgets.dart' show Alignment, BoxFit, MemoryImage, SizedBox, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart';

void main() {
  group('BackgroundConfig invariants', () {
    test('SolidBackground carries the color and optional overlay', () {
      const config = SolidBackground(color: Colors.black);
      expect(config.color, Colors.black);
      expect(config.overlay, isNull);

      const withOverlay = SolidBackground(
        color: Colors.white,
        overlay: BackgroundOverlay(color: Colors.black, opacity: 0.25),
      );
      expect(withOverlay.overlay?.opacity, 0.25);
    });

    test('ImageBackground rejects a video fallback', () {
      const video = VideoBackground(source: _NoopVideoSource());
      expect(
        () => ImageBackground(source: const NetworkImageSource('https://example.com/x.jpg'), fallback: video),
        throwsA(isA<AssertionError>()),
      );
    });

    test('VideoBackground rejects another video as fallback', () {
      const video = VideoBackground(source: _NoopVideoSource());
      expect(() => VideoBackground(source: const _NoopVideoSource(), fallback: video), throwsA(isA<AssertionError>()));
    });

    test('ImageSource variants expose their location', () {
      expect(const NetworkImageSource('https://a').url, 'https://a');
      expect(const AssetImageSource('icons/logo.png').name, 'icons/logo.png');
      const packaged = AssetImageSource('icons/logo.png', package: 'acme');
      expect(packaged.package, 'acme');
      final provider = MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));
      expect(ProviderImageSource(provider).provider, same(provider));
    });

    test('ImageBackground rejects a video underlay', () {
      const video = VideoBackground(source: _NoopVideoSource());
      expect(
        () => ImageBackground(source: const NetworkImageSource('https://example.com/x.jpg'), underlay: video),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Media backgrounds reject a negative blurSigma', () {
      expect(
        () => ImageBackground(source: const NetworkImageSource('https://example.com/x.jpg'), blurSigma: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(() => VideoBackground(source: const _NoopVideoSource(), blurSigma: -0.5), throwsA(isA<AssertionError>()));
    });

    test('ImageBackground rejects a negative letterboxBlurSigma', () {
      expect(
        () => ImageBackground(source: const NetworkImageSource('https://example.com/x.jpg'), letterboxBlurSigma: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Media backgrounds have no fallback color by default', () {
      const image = ImageBackground(source: NetworkImageSource('https://example.com/x.jpg'));
      const video = VideoBackground(source: _NoopVideoSource());
      // The package does not invent defaults; callers who want a
      // bottom surface set `underlay` or `fallback` themselves.
      expect(image.fallback, isNull);
      expect(image.underlay, isNull);
      expect(image.letterboxBlurSigma, isNull);
      expect(video.fallback, isNull);
      expect(video.underlay, isNull);
    });
  });
}

class _NoopVideoSource implements BackgroundVideoSource {
  const new();

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    return const SizedBox.shrink();
  }
}
