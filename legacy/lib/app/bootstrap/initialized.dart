import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'package:pure_live/core/platform/app_path_manager.dart';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/widgets/refresh_indicators.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pure_live/core/network/image_cache_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/network/proxy_routing.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/app/bootstrap/initial_services.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:pure_live/core/platform/mobile_manager.dart';
import 'package:pure_live/core/platform/desktop_manager.dart';
import 'package:pure_live/core/stream/upstream_proxy_routing.dart';
import 'package:pure_live/core/player/core/playback_proxy_policy.dart';
import 'package:pure_live/core/player/core/ingest_ffmpeg_registry.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_ingest_starter.dart';
import 'package:pure_live/domains/live/data/stream/ingest_source_interceptor.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/domain/live_input_playback_binder.dart';
import 'package:pure_live/domains/recorder/data/services/live_input_playback_binding.dart';
import 'package:pure_live/features/backup/backup_controller.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/core/platform/windows_multi_instance_launcher.dart';
import 'package:pure_live/core/platform/initial_room_handoff.dart';
import 'package:pure_live/core/config/migrations/settings_upgrade_migration.dart';

/// Keep decoded cover/avatar memory bounded independently from the encoded
/// HTTP/disk cache. A 960x540 RGBA cover is roughly 2 MiB after decoding, so
/// Flutter's default entry count can otherwise retain far more memory than a
/// live-room grid needs.
@visibleForTesting
void configureDecodedImageCache({required bool desktop}) {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = desktop ? 240 : 160;
  cache.maximumSizeBytes = (desktop ? 72 : 48) * 1024 * 1024;
}

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  bool _isInitialized = false;

  factory AppInitializer() => _instance;
  AppInitializer._internal();

  bool get isInitialized => _isInitialized;

  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;

    WidgetsFlutterBinding.ensureInitialized();
    configureDecodedImageCache(desktop: PlatformUtils.isDesktop);
    final String instanceId = WindowsMultiInstanceLauncher.instanceIdFromArgs(args);
    InitialRoomHandoff.offer(WindowsMultiInstanceLauncher.roomFromArgs(args));
    await _initWindowsSingleInstance(args, instanceId);

    await AppPathManager().initialize(instanceId: instanceId);
    await EasyLocalization.ensureInitialized();
    final Directory hiveDir = await AppPathManager().getDir(AppPathManager.dirHiveDB);

    await Hive.initFlutter(hiveDir.path);
    await HivePrefUtil.init();
    final migrationReport = await SettingsUpgradeMigration.migrate(
      target: Hive.box('app_settings'),
      legacyHiveFiles: AppPathManager().legacyHiveFiles,
      workingDirectory: await AppPathManager().migrationWorkingDir,
    );
    if (migrationReport.changed) {
      log(
        'Settings upgrade imported ${migrationReport.importedSources} source(s); '
        'favorites=${migrationReport.favoriteCount}, '
        'history=${migrationReport.historyCount}.',
      );
    }
    // Settings and controller registration is a hard startup dependency for
    // MyApp.build.  Leaving this future detached created a first-launch race:
    // a freshly upgraded install could build the widget tree before
    // SettingsService was registered, then work on a later launch only because
    // the database/cache files had already been created.
    await InitialServices.init();
    unawaited(PlayerKernelService.ensureInitialized());
    // A window opened by WindowsMultiInstanceLauncher starts from the opening
    // window's settings (proxy, cookies, follows) instead of an empty profile.
    final configFilePath = WindowsMultiInstanceLauncher.configFileFromArgs(args);
    if (configFilePath != null) {
      final restored = await Get.find<BackupController>().recoverAndDelete(File(configFilePath));
      log('Windows multi-instance settings ${restored ? 'restored' : 'restore failed'}: $configFilePath');
    }
    configureUpstreamProxyRouting((uri) {
      if (playsDirectBehindProxy(uri)) return 'DIRECT';
      final proxy = SettingsService.to.proxy;
      return buildProxyDirective(
        enabled: proxy.enableAppProxy.v,
        host: proxy.appProxyHost.v,
        port: proxy.appProxyPort.v,
      );
    });
    // The ingest pipelines remux a source FFmpeg understands better than the
    // player does; they run on the recorder's FFmpegKit build instead of linking
    // a second runtime.
    configureIngestFfmpegStarter(ffmpegKitIngestStarter);
    // The player hands its candidate sources to this interceptor before opening
    // them, so a line the engine cannot parse is remuxed over loopback instead of
    // failing. Registered here rather than in the domain: the domain only knows
    // the abstraction, and the FFmpeg runtime above is what makes it work.
    GlobalPlayerService.sourceInterceptorFactory = IngestSourceInterceptor.new;
    configureLiveInputPlaybackBinder(bindSiteInputForPlayback);
    configureWebSocketProxyRouting((_) {
      final proxy = SettingsService.to.proxy;
      return buildProxyDirective(
        enabled: proxy.enableAppProxy.v,
        host: proxy.appProxyHost.v,
        port: proxy.appProxyPort.v,
      );
    });
    await AppImageCacheManager.initialize(
      proxyDirectiveProvider: () {
        final proxy = SettingsService.to.proxy;
        return buildProxyDirective(
          enabled: proxy.enableAppProxy.v,
          host: proxy.appProxyHost.v,
          port: proxy.appProxyPort.v,
        );
      },
    );
    // Android FFmpegKit must begin native initialization during application
    // startup. Deferring it until after the first frame reintroduced the
    // upstream-recorded I/O failure on the first recording attempt. Keep this
    // non-blocking; FFmpegService awaits the same idempotent future at use.
    if (shouldStartRecorderPrewarmImmediately(mobile: PlatformUtils.isMobile)) _startFFmpegPrewarm();
    _initSmartDialog();
    initRefresh();

    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    if (PlatformUtils.isDesktopNotMac && instanceId.isEmpty) {
      _setupLaunchAtStartupSafe();
    }

    _isInitialized = true;
  }

  void _startFFmpegPrewarm() {
    unawaited(
      FFmpegManager.to.initialize().catchError((Object error, StackTrace stackTrace) {
        log('FFmpeg prewarm failed: $error', stackTrace: stackTrace);
      }),
    );
  }

  @visibleForTesting
  static bool shouldStartRecorderPrewarmImmediately({required bool mobile}) => mobile;

  Future<void> _initWindowsSingleInstance(List<String> args, String instanceId) async {
    if (!Platform.isWindows) return;
    try {
      final safeId = instanceId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      await WindowsSingleInstance.ensureSingleInstance(args, "PureLive_InstanceID_$safeId", bringWindowToFront: true);
    } catch (e) {
      log('WindowsSingleInstance initialization failed: $e');
    }
  }

  Future<void> _setupLaunchAtStartupSafe() async {
    try {
      await SettingsService.to.startup.setupLaunchAtStartup();
    } catch (e) {
      log('Setup launch at startup failed: $e');
    }
  }

  void _initSmartDialog() {
    SmartDialog.config.toast = SmartConfigToast(
      displayTime: const Duration(milliseconds: 3000),
      intervalTime: const Duration(milliseconds: 100),
    );
  }
}
