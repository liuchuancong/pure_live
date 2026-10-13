import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('ChromePlan.select', () {
    test('Windows keeps the native caption in the first stage', () {
      final plan = ChromePlan.select(platform: PlatformKind.windows, stage: ChromeStage.nativeFirst);

      expect(plan.mode, ChromeMode.nativeCaption);
      expect(plan.drawsButtons, isFalse);
      expect(plan.ownsResize, isFalse, reason: 'WS_THICKFRAME still owns it');
      expect(plan.ownsSnap, isFalse);
      expect(plan.metrics.titleBarHeight, 32);
    });

    test('macOS insets the traffic lights and reserves their space', () {
      final plan = ChromePlan.select(platform: PlatformKind.macos, stage: ChromeStage.nativeFirst);

      expect(plan.mode, ChromeMode.insetSystemButtons);
      expect(plan.leftButtonLayout, isTrue);
      expect(plan.metrics.buttonInset, greaterThan(0), reason: 'nothing interactive may sit under the lights');
      expect(plan.needsDragHandling, isTrue);
      expect(plan.ownsResize, isFalse);
    });

    test('Linux self-draws in both stages, and owns what that costs', () {
      final plan = ChromePlan.select(platform: PlatformKind.linux, stage: ChromeStage.nativeFirst);

      expect(plan.mode, ChromeMode.selfDrawn);
      expect(plan.drawsButtons, isTrue);
      expect(plan.ownsResize, isTrue);
      expect(plan.workAreaClampNeeded, isTrue);
    });

    test('the second stage is the one that takes the window manager over', () {
      final plan = ChromePlan.select(platform: PlatformKind.windows, stage: ChromeStage.seamlessSelfDrawn);

      expect(plan.mode, ChromeMode.selfDrawn);
      expect(plan.ownsSnap, isTrue, reason: 'snap, resize and the shadow are now ours to reimplement');
    });
  });

  group('hitTestChrome', () {
    const metrics = ChromeMetrics.selfDrawn();
    const width = 1200.0;
    const height = 800.0;

    ChromeHit hit(double x, double y, {bool maximized = false}) =>
        hitTestChrome(x: x, y: y, metrics: metrics, width: width, height: height, maximized: maximized);

    test('the middle of the strip drags, and the content below is the app', () {
      expect(hit(600, metrics.titleBarHeight / 2), ChromeHit.drag);
      expect(hit(600, 400), ChromeHit.client);
    });

    test('the three buttons occupy the right edge, close outermost', () {
      expect(hit(width - 2, metrics.titleBarHeight / 2), ChromeHit.close);
      expect(hit(width - metrics.buttonWidth - 2, metrics.titleBarHeight / 2), ChromeHit.maximise);
      expect(hit(width - metrics.buttonWidth * 2 - 2, metrics.titleBarHeight / 2), ChromeHit.minimise);
    });

    test('the corner grabs resize, and they win over the strip', () {
      expect(hit(2, 2), ChromeHit.resizeTopLeft);
      expect(hit(width - 2, height - 2), ChromeHit.resizeBottomRight);
      expect(hit(2, height / 2), ChromeHit.resizeLeft);
      expect(hit(width / 2, height - 2), ChromeHit.resizeBottom);
    });

    test('a maximised window has no resize edge, so its corner drags', () {
      expect(hit(2, 2, maximized: true), ChromeHit.drag);
      expect(hit(2, metrics.titleBarHeight - 1, maximized: true), ChromeHit.drag);
    });

    test('the macOS side has no buttons to hit', () {
      expect(
        hitTestChrome(
          x: 600,
          y: 10,
          metrics: const ChromeMetrics.macos(),
          width: width,
          height: height,
          rightSideButtons: false,
        ),
        ChromeHit.drag,
      );
    });
  });
}
