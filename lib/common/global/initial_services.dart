import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/core/iptv/services/channel_detail_controller.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

class InitialServices {
  static void initGlobalServices() {
    Get.put(SettingsService(), permanent: true);
    Get.put(LocalInteractionController(), permanent: true);
    Get.put(RouteObserverController(), permanent: true);
  }

  static void initLazyControllers() {
    Get.lazyPut(() => FavoriteController(), fenix: true);
    Get.lazyPut(() => ChannelDetailController(), fenix: true);
    Get.lazyPut(() => PopularController(), fenix: true);
    Get.lazyPut(() => AreasController(), fenix: true);
    Get.lazyPut(() => GlobalPlayerState(), fenix: true);

    // LivePlayController exposes recording actions in the room app bar.  It
    // can therefore be opened before the delayed heavy-service warm-up runs
    // (notably from a fast search result tap).  Register the dependency chain
    // lazily now so Get.find never races the three-second warm-up.
    Get.lazyPut(() => CacheService(), fenix: true);
    Get.lazyPut(() => RecordSettingsController(), fenix: true);
    Get.lazyPut(() => RecorderController(), fenix: true);
  }

  static Future<void> initDb() async {
    final db = DbService();
    await db.init();
    Get.put<DbService>(db, permanent: true);
  }

  static Future<void> init() async {
    await initDb();
    initGlobalServices();
    // Load and register the persisted custom font before MyApp builds its
    // first ThemeData. This makes the selection survive a full process restart.
    await SettingsService.to.font.ensureInitialized();
    await _migrateRoomScopedAudioOnly();
    initLazyControllers();
    _initHeavyServicesInBackground();
  }

  /// Retire the legacy global default so an old backup or persisted value can
  /// no longer make new rooms audio-only after ASMR has been disabled.
  static Future<void> _migrateRoomScopedAudioOnly() async {
    const migrationKey = 'migration.room_scoped_audio_only.v231';
    if (HivePrefUtil.getBool(migrationKey) == true) return;
    await HivePrefUtil.remove('audioOnly');
    SettingsService.to.player.audioOnly.v = false;
    await HivePrefUtil.setBool(migrationKey, true);
  }

  static void _initHeavyServicesInBackground() {
    Future<void>(() async {
      try {
        await FFmpegKitExtended.initialize();
        developer.log('FFmpegKitExtended initialized', name: 'InitialServices');
      } catch (error, stackTrace) {
        developer.log(
          'FFmpegKitExtended initialization failed: $error',
          name: 'InitialServices',
          error: error,
          stackTrace: stackTrace,
        );
      }

      await Future.delayed(const Duration(seconds: 3));

      _initializeSafely('CacheService', () {
        Get.find<CacheService>();
      });

      _initializeSafely('RecordSettingsController', () {
        Get.find<RecordSettingsController>();
      });

      _initializeSafely('RecorderController', () {
        Get.find<RecorderController>();
      });

      _initializeSafely('StreamResolverService', () {
        if (!Get.isRegistered<StreamResolverService>()) {
          Get.lazyPut(() => StreamResolverService(), fenix: true);
        }

        Get.find<StreamResolverService>();
      });

      _initializeSafely('AuthController', () {
        if (!Get.isRegistered<AuthController>()) {
          Get.put(AuthController(), permanent: true);
        }
      });

      developer.log('All heavy services initialized', name: 'InitialServices');
    });
  }

  static void _initializeSafely(String name, void Function() initialize) {
    try {
      initialize();
    } catch (error, stackTrace) {
      developer.log(
        '$name initialization failed (${error.runtimeType})',
        name: 'InitialServices',
        stackTrace: stackTrace,
      );
    }
  }
}
