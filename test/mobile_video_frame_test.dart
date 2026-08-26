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
          child: buildUnifiedMobileVideoFrame(
            aspectRatio: 9 / 16,
            fit: BoxFit.contain,
            child: const ColoredBox(key: ValueKey('video-texture'), color: Colors.black),
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

  testWidgets('mobile fill mode fills the target without a second aspect owner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: buildUnifiedMobileVideoFrame(
            aspectRatio: 9 / 16,
            fit: BoxFit.fill,
            child: const ColoredBox(key: ValueKey('filled-video-texture'), color: Colors.black),
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
          child: buildUnifiedMobileVideoFrame(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 16 / 9,
            contentInsets: const NormalizedVideoInsets(left: 0.3418, right: 0.3418),
            fit: BoxFit.contain,
            child: const ColoredBox(key: ValueKey('embedded-portrait-texture'), color: Colors.black),
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
          child: buildUnifiedMobileVideoFrame(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 9 / 16,
            contentInsets: const NormalizedVideoInsets(left: 0.3418, right: 0.3418),
            fit: BoxFit.contain,
            child: const ColoredBox(key: ValueKey('direct-portrait-texture'), color: Colors.black),
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
          child: buildUnifiedMobileVideoFrame(
            aspectRatio: 9 / 16,
            encodedAspectRatio: 16 / 9,
            fit: BoxFit.contain,
            child: const ColoredBox(key: ValueKey('unmeasured-landscape-texture'), color: Colors.black),
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
