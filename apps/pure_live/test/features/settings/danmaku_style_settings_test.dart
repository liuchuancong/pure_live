import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/device/display_refresh_rate_provider.dart' show RefreshRateMode;
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The flying danmaku's settings: the stored-value normalizers a slider and
/// its reader share (the weight's snap to the 100-step stops, the
/// same-screen cap's out-of-range default, the colours forced opaque, the
/// panel-rate policy), the style record's designed defaults and their writes
/// through the prefs, the frame rate's manual-and-follow pair, the rate the
/// renderer finally gets, and the two interaction switches.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the stored-value normalizers', () {
    test('a weight clamps into 100–900 and snaps to the 100-step stops', () {
      expect(normalizeDanmakuFontWeight(null), 500); // nothing stored: the medium default
      expect(normalizeDanmakuFontWeight(100), 100);
      expect(normalizeDanmakuFontWeight(500), 500);
      expect(normalizeDanmakuFontWeight(900), 900);
      expect(normalizeDanmakuFontWeight(849), 800); // the snap's own halves
      expect(normalizeDanmakuFontWeight(850), 900);
      expect(normalizeDanmakuFontWeight(47), 100); // clamped first, then snapped
      expect(normalizeDanmakuFontWeight(950), 900);
      expect(normalizeDanmakuFontWeight(0), 100);
    });

    test('the same-screen cap reads an out-of-range stored value as the default', () {
      expect(normalizeDanmakuMaxVisibleCount(null), 48);
      expect(normalizeDanmakuMaxVisibleCount(10), 10); // the range's own edges hold
      expect(normalizeDanmakuMaxVisibleCount(120), 120);
      expect(normalizeDanmakuMaxVisibleCount(55), 55);
      expect(normalizeDanmakuMaxVisibleCount(0), 48); // a TV backup's "by device"
      expect(normalizeDanmakuMaxVisibleCount(9), 48);
      expect(normalizeDanmakuMaxVisibleCount(121), 48);
    });

    test('a colour keeps its RGB and loses any alpha it carried', () {
      expect(normalizeDanmakuColor(null, 0xFF000000), 0xFF000000); // missing reads the fallback
      expect(normalizeDanmakuColor(0xFFFF4D4F, 0xFF000000), 0xFFFF4D4F); // opaque stays
      expect(normalizeDanmakuColor(0x80FF4D4F, 0xFF000000), 0xFFFF4D4F); // translucent forced opaque
      expect(normalizeDanmakuColor(0x00123456, 0xFFFFFFFF), 0xFF123456);
      expect(normalizeDanmakuColor(0x1FFFFFF, 0xFF000000), 0xFFFFFFFF); // bits above the RGB are masked
    });

    test('the palette and the weight stops are the tables their readers promise', () {
      expect(kDanmakuColorChoices, hasLength(10));
      expect(kDanmakuColorChoices.toSet(), hasLength(10)); // no repeats
      for (final colour in kDanmakuColorChoices) {
        expect(colour & 0xFF000000, 0xFF000000); // every one opaque
      }
      expect(kDanmakuColorChoices.first, 0xFFFFFFFF); // the engine's own default leads
      expect(kDanmakuFontWeights, [100, 200, 300, 400, 500, 600, 700, 800, 900]);
    });

    test('a palette colour names its word, and anything off the palette reads as pink', () {
      final t = Translations();
      expect(danmakuColorLabel(t, 0xFFFFFFFF), '白色');
      final named = [for (final colour in kDanmakuColorChoices) danmakuColorLabel(t, colour)];
      expect(named.toSet(), hasLength(named.length)); // ten distinct words
      expect(danmakuColorLabel(t, 0x00123456), danmakuColorLabel(t, 0xFFFF85C0)); // off-palette is pink
    });

    test('the weight words answer for any stored number through the snap', () {
      final t = Translations();
      final labels = [for (final stop in kDanmakuFontWeights) danmakuFontWeightLabel(t, stop)];
      expect(labels.toSet(), hasLength(9));
      expect(danmakuFontWeightLabel(t, 849), danmakuFontWeightLabel(t, 800)); // snapped first
      expect(danmakuFontWeightLabel(t, 0), danmakuFontWeightLabel(t, 100));
      expect(danmakuFontWeightLabel(t, 500), '稍粗');
    });

    test('the slider bounds keep their promises', () {
      expect(DanmakuStyleRange.fontSizeMin, lessThan(DanmakuStyleRange.fontSizeMax));
      expect(DanmakuStyleRange.maxVisibleDefault, 48);
      // The cap slider's 55 steps of two keep the 48 default on a stop.
      expect(
        (DanmakuStyleRange.maxVisibleMax - DanmakuStyleRange.maxVisibleMin) / 2,
        DanmakuStyleRange.maxVisibleDivisions,
      );
      expect((DanmakuStyleRange.maxVisibleDefault - DanmakuStyleRange.maxVisibleMin) % 2, 0);
      expect(DanmakuStyleRange.fpsDivisions, DanmakuStyleRange.fpsMax - DanmakuStyleRange.fpsMin); // one-frame steps
    });
  });

  group('the frame-rate resolver', () {
    test('a manual rate is the configured one, clamped', () {
      expect(normalizeDanmakuFps(null), 60);
      expect(normalizeDanmakuFps(90), 90);
      expect(normalizeDanmakuFps(29), 30);
      expect(normalizeDanmakuFps(241), 240);
      expect(resolveDanmakuFps(autoFps: false, configured: 500, mode: RefreshRateMode.performance), 240);
      expect(resolveDanmakuFps(autoFps: false, configured: 0, mode: RefreshRateMode.powerSaving), 30);
    });

    test('following the display takes the panel, capped by the mode', () {
      // The panel's own rate in performance.
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.performance, maxHz: 144), 144);
      // Power saving and balanced hold 60.
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.powerSaving, maxHz: 144), 60);
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.balanced, maxHz: 144), 60);
      // A 59 Hz panel stays itself even under the cap.
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.powerSaving, maxHz: 59), 59);
      // A sub-range panel clamps into the engine's floor.
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.performance, maxHz: 24), 30);
      // A fractional panel rate rounds.
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.performance, maxHz: 165.4), 165);
    });

    test("without a reading the display's rate falls back, ending at 60", () {
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.performance, currentHz: 90), 90);
      expect(resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.performance), 60);
      expect(
        resolveDanmakuFps(autoFps: true, configured: 90, mode: RefreshRateMode.powerSaving, maxHz: 0, currentHz: 0),
        60,
      );
    });
  });

  group('the style controller', () {
    test('a fresh device stands on the designed defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final style = container.read(danmakuStyleProvider);
      expect(style.fontSize, 18);
      expect(style.fontWeight, 500);
      expect(style.italic, isFalse);
      expect(style.letterSpacing, 0);
      expect(style.baseSpeed, 120);
      expect(style.area, 1);
      expect(style.topMargin, 0);
      expect(style.bottomMargin, 0.5); // the bottom half is the streamer's
      expect(style.opacity, 1);
      expect(style.showStroke, isTrue);
      expect(style.textColor, 0xFFFFFFFF);
      expect(style.strokeColor, 0xFF000000);
      expect(style.strokeWidth, 1.8);
      expect(style.showShadow, isTrue); // the shadow ships on: a stroke alone dies on a white scene
      expect(style.shadowColor, 0xFF000000);
      expect(style.shadowBlur, 2);
      expect(style.shadowOffsetX, 1);
      expect(style.shadowOffsetY, 1);
      expect(style.noEmoji, isFalse);
      expect(style.fontFamily, isNull);
      expect(style.maxVisibleCount, 48);
      expect(style.massMode, isFalse);
      expect(style.trackHeight, 36);
      expect(style.emojiSize, 24);
      expect(style.safeArea, isTrue);
      expect(style.overlapSafeGap, 40);
      expect(style.maxPendingCount, 120);
      expect(style.maxPendingAge, 5);
      expect(style.emitInterval, 0.1);
      expect(style.rasterize, isTrue);
      expect(style.barragePoolMaxSize, 150);
      expect(style.pictureCacheMaxSize, 200);
      expect(style.textCacheMaxSize, 1000);
      expect(style.rasterCacheMb, 24);
    });

    test('a stored style restores with its clamps and snaps applied', () async {
      await StoragePrefs.setPrefs({
        'danmaku.style.fontSize': 24.0,
        'danmaku.style.fontWeight': 849,
        'danmaku.style.maxVisibleCount': 55,
        'danmaku.style.textColor': 0x80FF4D4F,
        'danmaku.style.area': 2.0,
        'danmaku.style.opacity': -1.0,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final style = container.read(danmakuStyleProvider);
      expect(style.fontSize, 24);
      expect(style.fontWeight, 800); // snapped on the way in
      expect(style.maxVisibleCount, 55);
      expect(style.textColor, 0xFFFF4D4F); // translucent forced opaque
      expect(style.area, 1); // out of range clamped
      expect(style.opacity, 0);
    });

    test('an unreadable stored family falls back instead of naming a face the app cannot draw', () async {
      for (final entry in {
        'Default': null, // the reference's own sentinel
        '': null,
        'NotARealFace': null, // never a bundled or Google family
        'MiSans': 'MiSans',
        'SystemChinese': 'SystemChinese',
        'freefont:abc123': 'freefont:abc123',
      }.entries) {
        await StoragePrefs.setString('danmaku.style.fontFamily', entry.key);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(danmakuStyleProvider, (_, _) {});
        expect(container.read(danmakuStyleProvider).fontFamily, entry.value, reason: 'stored: ${entry.key}');
      }
    });

    test('the writes clamp, snap and persist, and the untouched fields carry', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final controller = container.read(danmakuStyleProvider.notifier);

      await controller.setFontSize(999);
      expect(container.read(danmakuStyleProvider).fontSize, 30);
      await pumpEventQueue();
      expect(StoragePrefs.getDouble('danmaku.style.fontSize'), 30);

      await controller.setMaxVisibleCount(5);
      expect(container.read(danmakuStyleProvider).maxVisibleCount, 10);

      await controller.setFontWeight(849);
      expect(container.read(danmakuStyleProvider).fontWeight, 800);
      await pumpEventQueue();
      expect(StoragePrefs.getInt('danmaku.style.fontWeight'), 800);

      await controller.setTextColor(0x00123456);
      expect(container.read(danmakuStyleProvider).textColor, 0xFF123456);

      // The slider's neighbours survive one knob's turn.
      await controller.setItalic(value: true);
      final after = container.read(danmakuStyleProvider);
      expect(after.italic, isTrue);
      expect(after.fontSize, 30);
      expect(after.maxVisibleCount, 10);
      expect(after.fontWeight, 800);
    });

    test('the typeface row clears through the sentinel a plain null cannot express', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final controller = container.read(danmakuStyleProvider.notifier);

      await controller.setFontFamily('MiSans');
      expect(container.read(danmakuStyleProvider).fontFamily, 'MiSans');
      await pumpEventQueue();
      expect(StoragePrefs.getString('danmaku.style.fontFamily'), 'MiSans');

      // Back to the platform's own face: the stored name leaves too.
      await controller.setFontFamily(null);
      expect(container.read(danmakuStyleProvider).fontFamily, isNull);
      await pumpEventQueue();
      expect(StoragePrefs.getString('danmaku.style.fontFamily'), isNull);

      // A face this build cannot draw clears the same way.
      await controller.setFontFamily('NotARealFace');
      expect(container.read(danmakuStyleProvider).fontFamily, isNull);
      await pumpEventQueue();
      expect(StoragePrefs.getString('danmaku.style.fontFamily'), isNull);
    });

    test('the mass mode flips and rides the same prefs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final controller = container.read(danmakuStyleProvider.notifier);
      expect(container.read(danmakuStyleProvider).massMode, isFalse);
      await controller.setMassMode(value: true);
      expect(container.read(danmakuStyleProvider).massMode, isTrue);
      await pumpEventQueue();
      expect(StoragePrefs.getBool('danmaku.style.massMode'), isTrue);
    });

    test('the reset restores every knob, the family included', () async {
      await StoragePrefs.setPrefs({'danmaku.style.fontSize': 30.0, 'danmaku.style.massMode': true});
      await StoragePrefs.setString('danmaku.style.fontFamily', 'MiSans');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuStyleProvider, (_, _) {});
      final controller = container.read(danmakuStyleProvider.notifier);
      expect(container.read(danmakuStyleProvider).fontSize, 30);

      await controller.reset();
      final style = container.read(danmakuStyleProvider);
      expect(style.fontSize, 18);
      expect(style.massMode, isFalse);
      expect(style.fontFamily, isNull);
      await pumpEventQueue();
      expect(StoragePrefs.getDouble('danmaku.style.fontSize'), 18);
      expect(StoragePrefs.getBool('danmaku.style.massMode'), isFalse);
      expect(StoragePrefs.getString('danmaku.style.fontFamily'), isNull);
    });
  });

  group('the frame-rate controller', () {
    test('a fresh device follows the display at 60, and a stored pair restores', () async {
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh.listen(danmakuFrameRateProvider, (_, _) {});
      expect(fresh.read(danmakuFrameRateProvider), (fps: 60, autoFps: true));

      await StoragePrefs.setPrefs({'danmaku.style.fps': 120, 'danmaku.style.autoFps': false});
      final stored = ProviderContainer();
      addTearDown(stored.dispose);
      stored.listen(danmakuFrameRateProvider, (_, _) {});
      expect(stored.read(danmakuFrameRateProvider), (fps: 120, autoFps: false));

      // A stored rate outside the range clamps.
      await StoragePrefs.setInt('danmaku.style.fps', 500);
      final clamped = ProviderContainer();
      addTearDown(clamped.dispose);
      clamped.listen(danmakuFrameRateProvider, (_, _) {});
      expect(clamped.read(danmakuFrameRateProvider).fps, 240);
    });

    test('the manual rate writes through, and turning the display back on keeps it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(danmakuFrameRateProvider, (_, _) {});
      final controller = container.read(danmakuFrameRateProvider.notifier);

      await controller.setFps(0);
      expect(container.read(danmakuFrameRateProvider).fps, 30);
      await pumpEventQueue();
      expect(StoragePrefs.getInt('danmaku.style.fps'), 30);

      await controller.setAutoFps(value: false);
      expect(container.read(danmakuFrameRateProvider), (fps: 30, autoFps: false));
      await controller.setAutoFps(value: true);
      expect(container.read(danmakuFrameRateProvider).fps, 30); // the manual rate waits

      await controller.reset();
      expect(container.read(danmakuFrameRateProvider), (fps: 60, autoFps: true));
    });
  });

  group('the rate the renderer is asked for', () {
    test('the effective rate rides the manual rate, and 60 answers before a snapshot', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
        ..listen(danmakuEffectiveFpsProvider, (_, _) {})
        ..listen(danmakuFrameRateProvider, (_, _) {});
      final rate = container.read(danmakuFrameRateProvider.notifier);

      // Following the display before its first read: the fallback 60.
      expect(container.read(danmakuEffectiveFpsProvider), 60);

      // The manual rate applies once following the display is off.
      await rate.setAutoFps(value: false);
      await rate.setFps(90);
      expect(container.read(danmakuEffectiveFpsProvider), 90);

      // A stored manual rate outside the range clamps on the way in.
      await rate.setFps(500);
      expect(container.read(danmakuEffectiveFpsProvider), 240);
    });
  });

  group('the tap interactions', () {
    test('both default on, write through, restore from the prefs and reset back on', () async {
      // A fresh device: both switches stand on.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh
        ..listen(danmakuTapInteractionProvider, (_, _) {})
        ..listen(danmakuLongPressInteractionProvider, (_, _) {});
      expect(fresh.read(danmakuTapInteractionProvider), isTrue);
      expect(fresh.read(danmakuLongPressInteractionProvider), isTrue);

      // A stored off restores off.
      await StoragePrefs.setBool('danmaku.interaction.tap', false);
      await StoragePrefs.setBool('danmaku.interaction.longPress', false);
      final stored = ProviderContainer();
      addTearDown(stored.dispose);
      stored
        ..listen(danmakuTapInteractionProvider, (_, _) {})
        ..listen(danmakuLongPressInteractionProvider, (_, _) {});
      expect(stored.read(danmakuTapInteractionProvider), isFalse);
      expect(stored.read(danmakuLongPressInteractionProvider), isFalse);

      // The reset brings both back, writing the keys too.
      final taps = stored.read(danmakuTapInteractionProvider.notifier);
      final holds = stored.read(danmakuLongPressInteractionProvider.notifier);
      await taps.reset();
      await holds.reset();
      expect(stored.read(danmakuTapInteractionProvider), isTrue);
      expect(stored.read(danmakuLongPressInteractionProvider), isTrue);
      await pumpEventQueue();
      expect(StoragePrefs.getBool('danmaku.interaction.tap'), isTrue);
      expect(StoragePrefs.getBool('danmaku.interaction.longPress'), isTrue);

      // And a plain set still writes its key.
      await taps.set(value: false);
      expect(stored.read(danmakuTapInteractionProvider), isFalse);
      await pumpEventQueue();
      expect(StoragePrefs.getBool('danmaku.interaction.tap'), isFalse);
    });
  });
}
