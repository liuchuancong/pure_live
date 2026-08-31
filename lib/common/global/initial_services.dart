import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/core/iptv/services/channel_detail_controller.dart';
import 'package:pure_live/common/services/settings/metered_network_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

class InitialServices {
  static void initGlobalServices() {
    Get.put(SettingsService(), permanent: true);
    Get.put(BackupController(), permanent: true);
    Get.put(LocalInteractionController(), permanent: true);
    Get.put(RouteObserverController(), permanent: true);
    Get.put<MeteredNetworkService>(MeteredNetworkService(), permanent: true);
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
    Get.lazyPut(() => StreamResolverService(), fenix: true);
    Get.lazyPut(() => AuthController(), fenix: true);
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
      await Future.delayed(const Duration(seconds: 3));

      // Keep heavyweight native/network services cold during ordinary browsing.
      // A recorder explicitly configured to resume persisted tasks remains the
      // only startup exception; FFmpeg itself is initialized when a task starts.
      final serializedTasks = HivePrefUtil.getString(RecorderKeys.recorderTasks);
      if (shouldWarmRecorderOnStartup(
        autoStartOnBoot: RecorderConfig.autoStartOnBoot,
        serializedTasks: serializedTasks,
      )) {
        _initializeSafely('RecorderController', () => Get.find<RecorderController>());
      }
    });
  }

  @visibleForTesting
  static bool shouldWarmRecorderOnStartup({required bool autoStartOnBoot, required String? serializedTasks}) {
    if (!autoStartOnBoot) return false;
    final value = serializedTasks?.trim();
    return value != null && value.isNotEmpty && value != '[]';
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
