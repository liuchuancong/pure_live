import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_platform/live_platform.dart'
    show DesktopDistribution, FormFactor, PlatformCapabilities, PlatformEnvironment, PlatformKind, PlatformRuntimeInfo;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/features/room/local_message_bus.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomController, roomControllerProvider;
import 'package:pure_live/features/room/room_dialogs.dart';
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/mobile/features/room/room_phone_portrait_layout.dart' show portraitPanelRange;
import 'package:pure_uikit/pure_uikit.dart';

/// The room page's second-round features, tested without a live room: the
/// sheet's three-stop math, the local-message bus, the controller's sleep
/// timer and volume commit, and both dialogs' contract.

const RoomIdentity _identity = (siteId: 'nosite', roomId: '1');

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('portraitPanelRange', () {
    test('the reference stops for a tall body', () {
      final stops = portraitPanelRange(800);
      expect(stops.minimum, closeTo(216, 0.001)); // 0.27 * 800, inside 190..250
      expect(stops.middle, closeTo(352, 0.001)); // 0.44 * 800
      expect(stops.maximum, closeTo(544, 0.001)); // 0.68 * 800, under 800-120
      expect(stops.initial, stops.middle);
    });

    test('a transiently small body never inverts the range', () {
      final stops = portraitPanelRange(300);
      expect(stops.maximum, greaterThanOrEqualTo(stops.minimum));
      expect(stops.middle, greaterThanOrEqualTo(stops.minimum));
      expect(stops.middle, lessThanOrEqualTo(stops.maximum));
      expect(stops.initial, greaterThanOrEqualTo(stops.minimum));
    });

    test('the ceiling always leaves 120 of video', () {
      for (final height in [600.0, 900.0, 1280.0]) {
        expect(portraitPanelRange(height).maximum, lessThanOrEqualTo(height - 120 + 0.001));
      }
    });
  });

  group('RoomLocalMessageBus', () {
    test('composes a local chat line; blank text never reaches the stream', () async {
      final bus = RoomLocalMessageBus();
      final seen = <LiveMessage>[];
      final sub = bus.messages.listen(seen.add);
      bus
        ..sendChat(text: '  你好  ', userName: '我', colorArgb: 0xFF112233)
        ..sendChat(text: '   ', userName: '我', colorArgb: 0xFFFFFFFF);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));
      final message = seen.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '你好');
      expect(message.isLocal, isTrue);
      expect(message.effectiveSender.userName, '我');
      expect(message.effectiveColor.r, 0x11);
      expect(message.effectiveColor.g, 0x22);
      expect(message.effectiveColor.b, 0x33);
      await sub.cancel();
      await bus.dispose();
      // Late sends drop quietly — the composer callback must not throw while
      // the room is tearing down.
      bus.sendChat(text: 'after close', userName: '我', colorArgb: 0xFFFFFFFF);
    });
  });

  group('RoomController', () {
    test('the sleep timer commits as one transaction and cancels without pausing', () {
      final container = _container();
      final controller = container.read(roomControllerProvider(_identity).notifier);
      expect(controller.state.sleepTimerActive, isFalse);

      controller.applySleepTimer(enabled: true, minutes: 15);
      expect(controller.state.sleepTimerActive, isTrue);
      expect(controller.state.sleepMinutes, 15);

      // Re-arm with an out-of-range draft: clamped, still active.
      controller.applySleepTimer(enabled: true, minutes: 999999999);
      expect(controller.state.sleepMinutes, RoomController.maxSleepMinutes);

      controller.applySleepTimer(enabled: false, minutes: 999999999);
      expect(controller.state.sleepTimerActive, isFalse);
      expect(controller.state.sleepMinutes, RoomController.maxSleepMinutes);
      // re-arm then cancel, exercising the toggle both directions; the final
      // disabled call leaves no pending Timer for the binding to flag.
      controller
        ..applySleepTimer(enabled: true, minutes: 5)
        ..applySleepTimer(enabled: false, minutes: 5);
      expect(controller.state.sleepTimerActive, isFalse);
    });

    test('the volume commit refuses without a live adapter and persists nothing', () async {
      final store = AppPreferencesStore(repository: _MapRepository());
      final container = _container(store: store);
      final controller = container.read(roomControllerProvider(_identity).notifier);
      await expectLater(controller.commitRoomVolumeDefaults(muted: true, mobile: 0.3, desktop: 0.6), throwsStateError);
      expect(store.value.volumeMuted, isFalse);
      expect(store.value.defaultDesktopVolume, 1);
    });

    test('a room opens dressed by the per-device volume answers', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final store = AppPreferencesStore(repository: _MapRepository());
      unawaited(
        store.update((p) => p.copyWith(defaultMobileVolume: 0.4, defaultDesktopVolume: 0.8, volumeMuted: true)),
      );
      final container = _container(store: store);
      final state = container.read(roomControllerProvider(_identity));
      expect(state.volume, 0.8); // the desktop answer, not the mobile one
      expect(state.muted, isTrue);
    });

    test('the barrage toggle is the global setting, not a per-visit flag', () async {
      final store = AppPreferencesStore(repository: _MapRepository());
      final container = _container(store: store);
      container.read(roomControllerProvider(_identity).notifier).setBarrage(on: false);
      expect(container.read(roomControllerProvider(_identity)).barrageOn, isFalse);
      expect(store.value.danmakuVisible, isFalse); // applied in memory at once
    });
  });

  group('dialogs', () {
    testWidgets('the volume dialog keeps the draft and reports when the room refuses', (tester) async {
      final container = await _pumpHost(
        tester,
        label: '打开音量',
        open: (context) => showRoomVolumeDialog(context, _identity),
      );
      await tester.tap(find.text('打开音量'));
      await tester.pumpAndSettle();
      expect(find.text('房间音量'), findsOne);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      // The unopened room has no adapter — the reference's refusal path:
      // the dialog stays open, the draft editable, with the reason shown.
      expect(find.text('房间音量'), findsOne);
      expect(find.text('当前房间无法应用音量，请确认后重试'), findsOne);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('房间音量'), findsNothing);
      container.dispose();
    });

    testWidgets('the timer dialog commits the draft on confirm only', (tester) async {
      final container = await _pumpHost(
        tester,
        label: '打开定时',
        open: (context) => showRoomTimerDialog(context, _identity),
      );
      // The dialog reaches the controller through `read`, which does not keep
      // an autoDispose family entry alive between frames; the test's listener
      // is the app's `ref.watch` stand-in.
      final live = container.listen(roomControllerProvider(_identity), (_, _) {});
      addTearDown(live.close);
      await tester.tap(find.text('打开定时'));
      await tester.pumpAndSettle();
      expect(find.text('睡眠定时'), findsWidgets);

      // Turning it on and picking a preset edits the draft; the running
      // session is untouched until 确定.
      await tester.tap(find.byKey(const ValueKey('room-timer-enabled')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('room-timer-preset-15')));
      await tester.pump();
      expect(find.text('15 分钟'), findsWidgets);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      final state = live.read();
      expect(state.sleepTimerActive, isTrue);
      expect(state.sleepMinutes, 15);

      // Run the countdown out on the test clock: the timer's end pauses the
      // room, falls the flag, and ticks the announcement — leaving no pending
      // timer for the binding to flag.
      await tester.pump(const Duration(minutes: 15));
      final ended = live.read();
      expect(ended.sleepTimerActive, isFalse);
      expect(ended.sleepEndedTick, state.sleepEndedTick + 1);
      expect(ended.paused, isTrue);
      live.close();
      container.dispose();
    });
  });
}

/// A host with an unopened room: [open] is wired to a button, the provider
/// graph is the test one, and the locale lands on zh like the shipped default.
Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required String label,
  required Future<void> Function(BuildContext context) open,
}) async {
  final container = _container();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Center(
                  child: Builder(
                    builder: (inner) => TextButton(onPressed: () => open(inner), child: Text(label)),
                  ),
                ),
              ),
            ],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// The provider graph of an offline room: booted stores on memory documents,
/// a site registry with no sites (the detail load becomes an honest error,
/// the engine never opens), a desktop environment.
ProviderContainer _container({AppPreferencesStore? store, _Stores? stores}) {
  final resolved = stores ?? _Stores();
  final preferences = store ?? resolved.preferences;
  return ProviderContainer(
    overrides: [
      appPreferencesStoreProvider.overrideWithValue(preferences),
      appearanceStoreProvider.overrideWithValue(resolved.appearance),
      sitesProvider.overrideWithValue(
        AppSites(factory: DioFactory(), http: DioFactory().create(), registry: LiveSiteRegistry(const [])),
      ),
      environmentProvider.overrideWithValue(const _DesktopEnvironment()),
    ],
  );
}

final class _Stores {
  final AppPreferencesStore preferences = AppPreferencesStore(repository: _MapRepository());
  final AppearanceStore appearance = AppearanceStore(repository: _MapRepository());
}

final class _DesktopEnvironment implements PlatformEnvironment {
  const new();

  @override
  PlatformRuntimeInfo get runtime => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: DesktopDistribution.values.first,
    isPackaged: false,
    executableRoot: Directory.current,
  );

  @override
  PlatformCapabilities get capabilities => PlatformCapabilities.none;
}

final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> watch({String? key}) => _changes.stream;
  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];
  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };
  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);
  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);
  @override
  List<String> getAllKeys() => List.of(documents.keys);
  @override
  bool contains(String key) => documents.containsKey(key);
  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);
  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async {
    documents[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async {
    documents.addAll(values);
    _changes.add(null);
  }

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
      _changes.add(null);
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> delete(String key) async {
    documents.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(documents.remove);
    _changes.add(null);
  }

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    _changes.add(null);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async {
    documents.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}
}
