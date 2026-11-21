import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/settings/playback/pip_danmaku_scale_provider.dart';

/// The compact window's danmaku factor: the auto shrink toward a narrower
/// window (never above the main look, never under its floor), the pinned
/// factor that replaces it, both kept in range by any input — a width or a
/// pin that is not a number included — and the two choices' store.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the auto factor', () {
    test('shrinks with the window, never above the main look, never under its floor', () {
      expect(resolvePipDanmakuScale(width: 350, auto: true, pinned: 0.4), 1.0); // the reference width
      expect(resolvePipDanmakuScale(width: 700, auto: true, pinned: 0.4), 1.0); // wider never grows
      expect(resolvePipDanmakuScale(width: 280, auto: true, pinned: 0.4), closeTo(0.8, 1e-9));
      expect(resolvePipDanmakuScale(width: 175, auto: true, pinned: 0.4), 0.65); // the floor keeps it legible
      expect(resolvePipDanmakuScale(width: 0.1, auto: true, pinned: 0.4), 0.65);
    });
  });

  group('the pinned factor', () {
    test('replaces the width and keeps its own floor and ceiling', () {
      expect(resolvePipDanmakuScale(width: 100, auto: false, pinned: 1), 1.0); // the width is not consulted
      expect(resolvePipDanmakuScale(width: 100, auto: false, pinned: 0.5), 0.5);
      expect(resolvePipDanmakuScale(width: 100, auto: false, pinned: 9), 1.0); // the ceiling
      expect(resolvePipDanmakuScale(width: 100, auto: false, pinned: -1), 0.4); // the floor
    });

    test('a pin that is not a number falls to the floor, and auto never consults it', () {
      expect(resolvePipDanmakuScale(width: 100, auto: false, pinned: double.nan), 0.4); // clamp passes NaN through
      expect(resolvePipDanmakuScale(width: 350, auto: true, pinned: double.nan), 1.0);
    });
  });

  group('the width', () {
    test('a width that cannot be measured reads as the reference width', () {
      expect(resolvePipDanmakuScale(width: 0, auto: true, pinned: 0.4), 1.0);
      expect(resolvePipDanmakuScale(width: -3, auto: true, pinned: 0.4), 1.0);
      expect(resolvePipDanmakuScale(width: double.nan, auto: true, pinned: 0.4), 1.0);
      expect(resolvePipDanmakuScale(width: double.infinity, auto: true, pinned: 0.4), 1.0);
    });
  });

  group('the store', () {
    test('a fresh start reads auto on and the floor', () {
      final scale = ProviderContainer().read(pipDanmakuScaleProvider);
      expect(scale.auto, isTrue);
      expect(scale.scale, 0.4);
    });

    test('the stored choices read, with the pin kept to its range', () async {
      await StoragePrefs.setBool('danmaku.pip.autoScale', false);
      expect(ProviderContainer().read(pipDanmakuScaleProvider).auto, isFalse);

      await StoragePrefs.setDouble('danmaku.pip.scale', 0.9);
      expect(ProviderContainer().read(pipDanmakuScaleProvider).scale, 0.9);

      await StoragePrefs.setDouble('danmaku.pip.scale', 7);
      expect(ProviderContainer().read(pipDanmakuScaleProvider).scale, 1.0); // the ceiling at read
    });

    test('a pinned factor keeps to its range and survives the store', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(pipDanmakuScaleProvider.notifier);

      await controller.setScale(2.5);
      expect(container.read(pipDanmakuScaleProvider).scale, 1.0); // the ceiling
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ProviderContainer().read(pipDanmakuScaleProvider).scale, 1.0); // the write went through
    });

    test('a pin that is not a number lands on the floor, not in the store', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(pipDanmakuScaleProvider.notifier);

      await controller.setScale(double.nan);
      expect(container.read(pipDanmakuScaleProvider).scale, 0.4);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ProviderContainer().read(pipDanmakuScaleProvider).scale, 0.4);
    });

    test('the auto flip and the reset persist', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(pipDanmakuScaleProvider.notifier);

      await controller.setAuto(value: false);
      await controller.setScale(0.7);
      expect(container.read(pipDanmakuScaleProvider).auto, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ProviderContainer().read(pipDanmakuScaleProvider).auto, isFalse); // the flip survived

      await controller.reset();
      expect(container.read(pipDanmakuScaleProvider), (auto: true, scale: 0.4));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final restored = ProviderContainer().read(pipDanmakuScaleProvider);
      expect(restored.auto, isTrue);
      expect(restored.scale, 0.4); // the reference's own answer
    });
  });
}
