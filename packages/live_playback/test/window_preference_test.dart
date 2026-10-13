import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:live_playback/live_playback.dart';
import 'package:live_storage/live_storage.dart';
import 'package:media_core/media_core.dart';

VideoGeometry geometryOf(int width, int height) {
  final size = VideoSize(width: width, height: height);
  return VideoGeometry.derived(
    videoSize: size,
    displaySize: DisplaySize(width: width.toDouble(), height: height.toDouble()),
    rotation: const VideoRotationInfo.none(),
    pixelRatio: const PixelRatioValue.one(),
  );
}

void main() {
  const sessionId = 'room-42';
  const area = Size(400, 800);

  group('EphemeralWindowPreferenceStore', () {
    test('remembers a rect per session and slot', () async {
      final store = EphemeralWindowPreferenceStore();

      await store.writeRect(sessionId: sessionId, slot: 'floating_portrait', rect: const Rect.fromLTWH(1, 2, 3, 4));
      await store.writeRect(sessionId: sessionId, slot: 'pip_landscape', rect: const Rect.fromLTWH(5, 6, 7, 8));

      expect(await store.readRect(sessionId: sessionId, slot: 'floating_portrait'), const Rect.fromLTWH(1, 2, 3, 4));
      expect(await store.readRect(sessionId: sessionId, slot: 'pip_landscape'), const Rect.fromLTWH(5, 6, 7, 8));
      expect(await store.readRect(sessionId: sessionId, slot: 'floating_landscape'), isNull);

      await store.clearSession(sessionId);
      expect(await store.readRect(sessionId: sessionId, slot: 'floating_portrait'), isNull);
    });
  });

  group('HiveWindowPreferenceStore', () {
    late Directory storageDir;

    setUp(() {
      storageDir = Directory.systemTemp.createTempSync('live_playback_window_geometry');
      Hive.init(storageDir.path);
    });

    tearDown(() async {
      await Hive.close();
      try {
        storageDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Transient lock on Windows; the temp directory goes with the process.
      }
    });

    test('round-trips a rect through the storage box', () async {
      final store = HiveWindowPreferenceStore();

      await store.writeRect(
        sessionId: sessionId,
        slot: 'floating_portrait',
        rect: const Rect.fromLTWH(10, 20, 120, 240),
      );

      expect(
        await store.readRect(sessionId: sessionId, slot: 'floating_portrait'),
        const Rect.fromLTWH(10, 20, 120, 240),
      );
    });

    test('keeps sessions apart', () async {
      final store = HiveWindowPreferenceStore();

      await store.writeRect(sessionId: 'room-1', slot: 'pip_landscape', rect: const Rect.fromLTWH(1, 2, 3, 4));
      await store.writeRect(sessionId: 'room-2', slot: 'pip_landscape', rect: const Rect.fromLTWH(5, 6, 7, 8));

      expect(await store.readRect(sessionId: 'room-1', slot: 'pip_landscape'), const Rect.fromLTWH(1, 2, 3, 4));
      expect(await store.readRect(sessionId: 'room-2', slot: 'pip_landscape'), const Rect.fromLTWH(5, 6, 7, 8));
    });

    test('a session whose id is a prefix of another keeps its own entry', () async {
      final store = HiveWindowPreferenceStore();

      await store.writeRect(sessionId: 'room', slot: 'floating_portrait', rect: const Rect.fromLTWH(1, 2, 3, 4));
      await store.writeRect(sessionId: 'room-2', slot: 'floating_portrait', rect: const Rect.fromLTWH(5, 6, 7, 8));

      await store.clearSession('room');

      expect(await store.readRect(sessionId: 'room', slot: 'floating_portrait'), isNull);
      expect(await store.readRect(sessionId: 'room-2', slot: 'floating_portrait'), const Rect.fromLTWH(5, 6, 7, 8));
    });

    test('a half-written entry degrades to "no preference"', () async {
      final boxes = StorageBoxManager();
      final box = await boxes.keyed<Map<String, List<double>>>(HiveWindowPreferenceStore.defaultBoxName);
      await box.put(sessionId, <String, List<double>>{
        'floating_portrait': <double>[10, 20],
      }).run();

      final store = HiveWindowPreferenceStore(boxes: boxes);

      expect(await store.readRect(sessionId: sessionId, slot: 'floating_portrait'), isNull);
    });

    test('clearAll forgets every session', () async {
      final store = HiveWindowPreferenceStore();

      await store.writeRect(sessionId: 'room-1', slot: 'pip_landscape', rect: const Rect.fromLTWH(1, 2, 3, 4));
      await store.writeRect(sessionId: 'room-2', slot: 'pip_landscape', rect: const Rect.fromLTWH(5, 6, 7, 8));

      await store.clearAll();

      expect(await store.readRect(sessionId: 'room-1', slot: 'pip_landscape'), isNull);
      expect(await store.readRect(sessionId: 'room-2', slot: 'pip_landscape'), isNull);
    });
  });

  group('WindowPreferenceManager', () {
    test('opens at the natural size when nothing is remembered', () async {
      final manager = WindowPreferenceManager(store: EphemeralWindowPreferenceStore());

      final rect = await manager.resolveRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.portrait,
        ),
        area: area,
        geometry: geometryOf(720, 1280),
      );

      expect(rect.height, greaterThan(rect.width));
      expect(rect.right, lessThanOrEqualTo(area.width));
      expect(rect.bottom, lessThanOrEqualTo(area.height));
    });

    test("restores a remembered rect, clamped into today's surface", () async {
      final store = EphemeralWindowPreferenceStore();
      final manager = WindowPreferenceManager(store: store);

      // Remembered on a much wider screen, then the app is resized.
      await manager.rememberRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.landscape,
        ),
        rect: const Rect.fromLTWH(900, 500, 320, 180),
      );

      final rect = await manager.resolveRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.landscape,
        ),
        area: area,
        geometry: geometryOf(1920, 1080),
      );

      expect(rect.right, lessThanOrEqualTo(area.width));
      expect(rect.bottom, lessThanOrEqualTo(area.height));
      expect(rect.width / rect.height, closeTo(16 / 9, 0.001));
    });

    test('portrait and landscape layouts do not overwrite each other', () async {
      final manager = WindowPreferenceManager(store: EphemeralWindowPreferenceStore());

      await manager.rememberRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.portrait,
        ),
        rect: const Rect.fromLTWH(10, 10, 120, 213),
      );

      final landscape = await manager.resolveRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.landscape,
        ),
        area: area,
        geometry: geometryOf(1920, 1080),
      );

      expect(landscape.width, isNot(closeTo(120, 0.001)));
      expect(landscape.width, greaterThan(landscape.height));
    });

    test('the surface is part of the key: PiP does not inherit the floating rect', () async {
      final manager = WindowPreferenceManager(store: EphemeralWindowPreferenceStore());

      await manager.rememberRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.floating,
          orientation: VideoOrientation.landscape,
        ),
        rect: const Rect.fromLTWH(10, 10, 120, 67.5),
      );

      final pip = await manager.resolveRect(
        key: const WindowGeometryKey(
          sessionId: sessionId,
          surface: WindowSurface.pip,
          orientation: VideoOrientation.landscape,
        ),
        area: area,
        geometry: geometryOf(1920, 1080),
      );

      expect(pip.width, isNot(closeTo(120, 0.001)));
    });
  });

  group('WindowGeometryKey', () {
    test('unknown orientation counts as landscape', () {
      const key = WindowGeometryKey(
        sessionId: sessionId,
        surface: WindowSurface.pip,
        orientation: VideoOrientation.unknown,
      );

      expect(key.slot, 'pip_landscape');
    });

    test('portrait gets its own slot', () {
      const key = WindowGeometryKey(
        sessionId: sessionId,
        surface: WindowSurface.floating,
        orientation: VideoOrientation.portrait,
      );

      expect(key.slot, 'floating_portrait');
    });
  });
}
