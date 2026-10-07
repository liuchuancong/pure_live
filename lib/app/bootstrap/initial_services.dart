import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/release/release_history_source.dart';
import 'package:pure_live/core/platform/multi_instance_settings_source.dart';
import 'package:pure_live/core/platform/desktop_exit_port.dart';
import 'package:pure_live/core/navigation/official_category_policy.dart';
import 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/shared/platforms/cc/cc_catalog.dart';
import 'package:pure_live/app/bootstrap/desktop_exit_flow.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';
import 'package:pure_live/core/config/cache_controller.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/exit_settings_controller.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/config/page_settings_controller.dart';
import 'package:pure_live/core/config/player_settings_controller.dart';
import 'package:pure_live/core/config/proxy_settings_controller.dart';
import 'package:pure_live/core/config/refresh_config_controller.dart';
import 'package:pure_live/core/config/room_card_settings_controller.dart';
import 'package:pure_live/core/config/startup_controller.dart';
import 'package:pure_live/core/config/theme_settings_controller.dart';
import 'package:pure_live/core/config/volume_settings_controller.dart';
import 'package:pure_live/core/config/window_size_controller.dart';
import 'package:pure_live/domains/iptv/data/local/db_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/account/data/bilibili_account_service.dart';
import 'package:pure_live/domains/account/presentation/auth/auth_controller.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart' show readNiconicoMaster;
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';
import 'package:pure_live/domains/live/data/history_controller.dart';
import 'package:pure_live/shared/platforms/huya/huya_site.dart';
import 'package:pure_live/domains/live/presentation/tags/tag_management_controller.dart';
import 'package:pure_live/domains/iptv/data/iptv_settings_controller.dart';
import 'package:pure_live/features/about/widgets/release_history_repository.dart';
import 'package:pure_live/features/backup/backup_controller.dart';
import 'package:pure_live/features/web_dav/web_dav_settings_controller.dart';
import 'package:pure_live/domains/recorder/data/services/cache_service.dart';
import 'package:pure_live/domains/recorder/data/consts/recorder_config.dart';
import 'package:pure_live/domains/recorder/data/consts/recorder_keys.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_controller.dart';
import 'package:pure_live/domains/iptv/presentation/channel_detail_controller.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';
import 'package:pure_live/domains/live/presentation/favorite/favorite_controller.dart';
import 'package:pure_live/domains/live/presentation/popular/popular_controller.dart';
import 'package:pure_live/domains/live/presentation/areas/areas_controller.dart';

class InitialServices {
  static void initGlobalServices() {
    Sites.niconicoMasterReader = readNiconicoMaster;
    Get.put(SettingsService(), permanent: true);
    _registerCoreSettings();
    _registerDomainSettings();
    // Register IPTV outside the settings registration above. Creating this
    // controller from inside another controller's onInit can re-enter the
    // dependency container during a cold Hive migration and stall the first
    // frame. A direct, post-registration owner also avoids the old
    // lazy-then-permanent collision in GetX.
    Get.put(IptvSettingsController(), permanent: true);
    final localInteraction = LocalInteractionController();
    Get.put(localInteraction, permanent: true);
    // The shared danmaku panel looks the composer up by its Core contract, not
    // by this concrete class: the panel must not know which domain registered it,
    // and a recording has nothing to register at all.
    Get.put<DanmakuLocalInteraction>(localInteraction, permanent: true);
    Get.put(RouteObserverController(), permanent: true);
  }

  static void _registerCoreSettings() {
    Get.lazyPut(() => StartupController(), fenix: true);
    Get.lazyPut(() => AppSettingsController(), fenix: true);
    Get.lazyPut(() => ThemeSettingsController(), fenix: true);
    Get.lazyPut(() => RoomCardSettingsController(), fenix: true);
    Get.lazyPut(() => WindowSizeController(), fenix: true);
    Get.lazyPut(() => ProxySettingsController(), fenix: true);
    Get.lazyPut(() => PlayerSettingsController(), fenix: true);
    Get.lazyPut(() => DanmakuSettingsController(), fenix: true);
    Get.lazyPut(() => VolumeSettingsController(), fenix: true);
    Get.lazyPut(() => RefreshConfigController(), fenix: true);
    Get.lazyPut(() => CacheController(), fenix: true);
    Get.lazyPut(() => PageSettingsController(), fenix: true);
    Get.lazyPut(() => FontSettingsController(), fenix: true);
    Get.lazyPut(() => LogController(), fenix: true);
    Get.lazyPut(() => CookieSettingsController(), fenix: true);
    Get.put(ExitSettingsController(), permanent: true);
  }

  static void _registerDomainSettings() {
    Get.lazyPut(() => HistoryController(), fenix: true);
    Get.lazyPut(() => FavoriteRoomController(), fenix: true);
    Get.lazyPut(() => WebDavController(), fenix: true);
    Get.lazyPut(() => BackupController(), fenix: true);
    Get.lazyPut(() => TagManagementController(), fenix: true);
    Get.lazyPut(() => BiliBiliAccountService(), fenix: true);
  }

  static void initLazyControllers() {
    // Permanent on purpose: entering a live room pushes a route and GetX's
    // smart management tears the controller down; with fenix it comes back
    // fresh and the follow list jumps from page 3 back to page 1 on return.
    // A permanent instance keeps the pagination state across that round trip.
    Get.put<FavoriteController>(FavoriteController(), permanent: true);
    Get.lazyPut(() => ChannelDetailController(), fenix: true);
    Get.lazyPut(() => PopularController(), fenix: true);
    Get.lazyPut(() => AreasController(), fenix: true);

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
    Get.lazyPut(() => BackgroundController(), fenix: true);
  }

  static Future<void> init() async {
    await initDb();
    initGlobalServices();
    _bindCorePorts();
    // Load and register the persisted custom font before MyApp builds its
    // first ThemeData. This makes the selection survive a full process restart.
    await SettingsService.to.font.ensureInitialized();
    // The panel's cutout is a physical fact that `MediaQuery.padding` stops
    // reporting once the status bar hides; the player chrome reads this to stay
    // out of the notch in immersive fullscreen.
    unawaited(DisplayCutout.refresh());
    await _migrateRoomScopedAudioOnly();
    initLazyControllers();
    _initHeavyServicesInBackground();
  }

  static void _bindCorePorts() {
    ReleaseHistorySource.provider = ({bool forceRefresh = false}) =>
        ReleaseHistoryRepository.instance.load(forceRefresh: forceRefresh);
    CookieSettingsController.onRestored = () {
      BiliBiliAccountService.instance.setCookie(CookieSettingsController.to.bilibiliCookie.v);
      BiliBiliAccountService.instance.loadUserInfo();
    };
    MultiInstanceSettingsSource.exporter = ({required bool includeSensitiveData}) =>
        BackupController.to.exportAllSettings(includeSensitiveData: includeSensitiveData);
    DesktopExitPort.exitApplication = DesktopExitFlow.exitDesktopApplication;
    DesktopExitPort.showExitDialog = DesktopExitFlow.showExitDialog;
    OfficialCategoryPolicy.isOfficialCategory = CCCatalog.isOfficialEntry;
    OfficialCategoryPolicy.officialCategoryUri = CCCatalog.officialEntryUri;
    CompactSourceOrientation.read = () {
      final player = GlobalPlayerService.instance.player;
      final size = player.handle?.combinedSnapshot.geometry.videoSize;
      if (size == null) return player.isVerticalVideo.value;
      return CompactSourceOrientation.isPortraitSize(size.width.toDouble(), size.height.toDouble());
    };
    unawaited(HuyaSite().getHuYaUA());
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
