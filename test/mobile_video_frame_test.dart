import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

void main() {
  test('application floating bounds follow a late portrait ratio', () {
    final landscape = resolveAppFloatingSize(aspectRatio: 16 / 9, maxSide: 220);
    final portrait = resolveAppFloatingSize(aspectRatio: 9 / 16, maxSide: 220);

    expect(landscape, const Size(220, 123.75));
    expect(portrait.width / portrait.height, closeTo(9 / 16, 0.001));
    expect(portrait.height, greaterThan(portrait.width));
  });

  test('PiP source hint encloses the same contained pixels as its portrait ratio', () {
    final rect = resolveContainedVideoRect(container: const Rect.fromLTWH(0, 0, 400, 300), contentAspectRatio: 9 / 16);

    expect(rect.height, 300);
    expect(rect.width / rect.height, closeTo(9 / 16, 0.001));
    expect(rect.center, const Offset(200, 150));
  });

  testWidgets('mobile video frame owns one trusted contain ratio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            fit: BoxFit.contain,
            nativeVideoBuilder: (fit) =>
                _FakeNativeVideo(fit: fit, aspectRatio: 9 / 16, textureKey: const ValueKey('video-texture')),
          ),
        ),
      ),
    );

    final texture = tester.getRect(find.byKey(const ValueKey('video-texture')));
    expect(texture.height, closeTo(400, 0.01));
    expect(texture.width, closeTo(225, 0.01));
    expect(texture.center, const Offset(200, 200));
    expect(tester.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.contain);
  });

  testWidgets('direct portrait texture ignores a stale landscape manager canvas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 16 / 9,
            fit: BoxFit.contain,
            nativeVideoBuilder: (fit) => _FakeNativeVideo(
              fit: fit,
              aspectRatio: 9 / 16,
              textureKey: const ValueKey('late-direct-portrait-texture'),
            ),
          ),
        ),
      ),
    );

    final texture = tester.getRect(find.byKey(const ValueKey('late-direct-portrait-texture')));
    expect(texture.height, closeTo(400, 0.1));
    expect(texture.width / texture.height, closeTo(9 / 16, 0.002));
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.contain);
  });

  testWidgets('mobile fill mode fills the target without a second aspect owner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            fit: BoxFit.fill,
            nativeVideoBuilder: (fit) =>
                _FakeNativeVideo(fit: fit, aspectRatio: 9 / 16, textureKey: const ValueKey('filled-video-texture')),
          ),
        ),
      ),
    );

    expect(tester.getRect(find.byKey(const ValueKey('filled-video-texture'))).size, const Size(400, 300));
  });

  testWidgets('active-content crop removes encoded pillar bars without stretching the programme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 16 / 9,
            contentInsets: const NormalizedVideoInsets(left: 0.3418, right: 0.3418),
            fit: BoxFit.contain,
            nativeVideoBuilder: (fit) => _FakeNativeVideo(
              fit: fit,
              aspectRatio: 16 / 9,
              textureKey: const ValueKey('embedded-portrait-texture'),
            ),
          ),
        ),
      ),
    );

    final viewport = tester.getRect(find.byKey(const ValueKey('active-video-content-viewport')));
    final texture = tester.getRect(find.byKey(const ValueKey('embedded-portrait-texture')));
    expect(viewport.height, closeTo(400, 0.1));
    expect(viewport.width / viewport.height, closeTo(9 / 16, 0.02));
    expect(texture.width / texture.height, closeTo(16 / 9, 0.02));
    expect(texture.width, greaterThan(viewport.width));
  });

  testWidgets('renderer drops a stale crop that disagrees with the trusted presentation ratio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 9 / 16,
            contentInsets: const NormalizedVideoInsets(left: 0.3418, right: 0.3418),
            fit: BoxFit.contain,
            nativeVideoBuilder: (fit) =>
                _FakeNativeVideo(fit: fit, aspectRatio: 9 / 16, textureKey: const ValueKey('direct-portrait-texture')),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('active-video-content-viewport')), findsNothing);
    final texture = tester.getRect(find.byKey(const ValueKey('direct-portrait-texture')));
    expect(texture.height, closeTo(400, 0.1));
    expect(texture.width / texture.height, closeTo(9 / 16, 0.002));
  });

  testWidgets('platform orientation hint never stretches an unmeasured landscape canvas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoPresentation(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 16 / 9,
            fit: BoxFit.contain,
            nativeVideoBuilder: (fit) => _FakeNativeVideo(
              fit: fit,
              aspectRatio: 16 / 9,
              textureKey: const ValueKey('unmeasured-landscape-texture'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('active-video-content-viewport')), findsNothing);
    final texture = tester.getRect(find.byKey(const ValueKey('unmeasured-landscape-texture')));
    expect(texture.width / texture.height, closeTo(16 / 9, 0.002));
    expect(texture.width, closeTo(400, 0.1));
    expect(texture.height, closeTo(225, 0.1));
  });
}

/// Faithfully models the sizing contract of media_kit's Video widget: the
/// native texture has an intrinsic decoder rect and the widget itself owns one
/// FittedBox. A plain ColoredBox hid the former double-fit regression.
class _FakeNativeVideo extends StatelessWidget {
  const _FakeNativeVideo({required this.fit, required this.aspectRatio, required this.textureKey});

  final BoxFit fit;
  final double aspectRatio;
  final Key textureKey;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: 1000 * aspectRatio,
          height: 1000,
          child: ColoredBox(key: textureKey, color: Colors.black),
        ),
      ),
    );
  }
}
