import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart'
    show
        Alignment,
        Builder,
        ColoredBox,
        Colors,
        Image,
        MaterialApp,
        MemoryImage,
        Scaffold,
        SizedBox,
        Stack,
        Text,
        TextDirection,
        Widget;
import 'package:flutter/painting.dart' show AlignmentGeometry;
import 'package:flutter/widgets.dart' show BoxFit, ImageFiltered;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit_background/live_uikit_background.dart';
import 'package:live_uikit_background/src/rendering/background_blur.dart';
import 'package:live_uikit_background/src/rendering/background_layer_stack_view.dart';
import 'package:live_uikit_background/src/rendering/gradient_background_view.dart';
import 'package:live_uikit_background/src/rendering/image_background_view.dart';
import 'package:live_uikit_background/src/rendering/solid_background_view.dart';
import 'package:live_uikit_background/src/rendering/video_background_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('LiveBackground dispatch', () {
    testWidgets('renders SolidBackground through SolidBackgroundView', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: SolidBackground(color: Colors.blue),
          child: SizedBox(height: 40),
        ),
      );
      expect(find.byType(SolidBackgroundView), findsOneWidget);
    });

    testWidgets('renders GradientBackground through GradientBackgroundView', (tester) async {
      await _pump(tester, const LiveBackground(config: GradientBackground(colors: [Colors.black, Colors.white])));
      expect(find.byType(GradientBackgroundView), findsOneWidget);
    });

    testWidgets('renders VideoBackground through VideoBackgroundView', (tester) async {
      await _pump(tester, const LiveBackground(config: VideoBackground(source: _FakeVideoSource())));
      expect(find.byType(VideoBackgroundView), findsOneWidget);
    });

    testWidgets('renders BackgroundLayerStack through BackgroundLayerStackView', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: BackgroundLayerStack(
            layers: [BackgroundLayer(config: SolidBackground(color: Colors.black))],
          ),
        ),
      );
      expect(find.byType(BackgroundLayerStackView), findsOneWidget);
      expect(find.byType(SolidBackgroundView), findsOneWidget);
    });

    testWidgets('shows the caller child on top of the base', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: SolidBackground(color: Colors.blue),
          child: Text('foreground', textDirection: TextDirection.ltr),
        ),
      );
      expect(find.text('foreground'), findsOneWidget);
    });

    testWidgets('renders config fallback when the video source throws', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: VideoBackground(
            source: _ThrowingVideoSource(),
            fallback: SolidBackground(color: Colors.green),
          ),
        ),
      );
      expect(find.byType(SolidBackgroundView), findsOneWidget);
    });

    testWidgets('renders nothing when the video throws and the caller gave no fallback', (tester) async {
      await _pump(tester, const LiveBackground(config: VideoBackground(source: _ThrowingVideoSource())));
      // The package does not invent a surface; when the caller did
      // not set a fallback the layer collapses to SizedBox.shrink().
      expect(find.byType(SolidBackgroundView), findsNothing);
      expect(find.byType(GradientBackgroundView), findsNothing);
    });

    testWidgets('publishes the overlay scrim above the base when opacity > 0', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: SolidBackground(
            color: Colors.blue,
            overlay: BackgroundOverlay(color: Colors.black, opacity: 0.5),
          ),
          child: Text('fg', textDirection: TextDirection.ltr),
        ),
      );
      expect(find.byType(SolidBackgroundView), findsOneWidget);
      expect(find.text('fg'), findsOneWidget);
    });

    testWidgets('keeps the tree shape when config toggles to null', (tester) async {
      const solid = LiveBackground(config: SolidBackground(color: Colors.red));
      const empty = LiveBackground(config: null);
      await _pump(tester, solid);
      expect(find.byType(Stack), findsWidgets);
      await _pump(tester, empty);
      expect(find.byType(LiveBackground), findsOneWidget);
      expect(find.byType(SolidBackgroundView), findsNothing);
    });

    testWidgets('forwards `paused` to the video source (caller-owned signal)', (tester) async {
      final source = _RecordingVideoSource();
      await _pump(tester, LiveBackground(config: VideoBackground(source: source), paused: true));
      expect(source.lastPaused, isTrue);
      await _pump(tester, LiveBackground(config: VideoBackground(source: source)));
      expect(source.lastPaused, isFalse);
    });
  });

  group('LiveBackground builder type check', () {
    testWidgets('accepts a Builder as the child so descendants see the scope', (tester) async {
      var sawScope = false;
      await _pump(
        tester,
        LiveBackground(
          config: const SolidBackground(color: Colors.blue),
          child: Builder(
            builder: (context) {
              sawScope = true;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(sawScope, isTrue);
    });
  });

  group('Background blur helper', () {
    test('blurBackground returns the child untouched when sigma is not positive', () {
      const child = SizedBox.shrink();
      expect(blurBackground(child: child, sigma: 0), same(child));
      expect(blurBackground(child: child, sigma: -1), same(child));
    });

    testWidgets('blurBackground wraps the child in ImageFiltered for positive sigma', (tester) async {
      await _pump(tester, blurBackground(child: const ColoredBox(color: Colors.red), sigma: 8));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });

  group('Underlay and letterbox integration (explicit sigma)', () {
    testWidgets('ImageBackground paints the underlay beneath the media', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: ImageBackground(
            source: NetworkImageSource('https://example.invalid/x.jpg'),
            underlay: SolidBackground(color: Colors.orange),
          ),
        ),
      );
      expect(find.byType(SolidBackgroundView), findsOneWidget);
      expect(find.byType(ImageBackgroundView), findsOneWidget);
    });

    testWidgets('ImageBackground paints a blurred cover copy only when sigma is set', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: ImageBackground(
            source: NetworkImageSource('https://example.invalid/x.jpg'),
            fit: BoxFit.contain,
            letterboxBlurSigma: 20,
          ),
        ),
      );
      // Two Image widgets: the cover-fill layer and the primary image.
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byType(ImageFiltered), findsWidgets);
    });

    testWidgets('ImageBackground skips the letterbox fill when sigma is null', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: ImageBackground(source: NetworkImageSource('https://example.invalid/x.jpg'), fit: BoxFit.contain),
        ),
      );
      // No automatic detection: the package paints exactly one Image
      // because the caller did not opt into a letterbox fill.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ProviderImageSource hands the caller-supplied provider through', (tester) async {
      final provider = MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));
      await _pump(tester, LiveBackground(config: ImageBackground(source: ProviderImageSource(provider))));
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.image, same(provider));
    });

    testWidgets('VideoBackground paints underlay beneath the source', (tester) async {
      await _pump(
        tester,
        const LiveBackground(
          config: VideoBackground(
            source: _FakeVideoSource(),
            underlay: SolidBackground(color: Colors.orange),
          ),
        ),
      );
      expect(find.byType(SolidBackgroundView), findsOneWidget);
      expect(find.byType(VideoBackgroundView), findsOneWidget);
    });

    testWidgets('VideoBackground wraps source with ImageFiltered when blurSigma > 0', (tester) async {
      await _pump(tester, const LiveBackground(config: VideoBackground(source: _FakeVideoSource(), blurSigma: 12)));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}

class _FakeVideoSource implements BackgroundVideoSource {
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

class _ThrowingVideoSource implements BackgroundVideoSource {
  const new();

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    throw StateError('no decoder available');
  }
}

class _RecordingVideoSource implements BackgroundVideoSource {
  bool? lastPaused;

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    lastPaused = paused;
    return const SizedBox.shrink();
  }
}
