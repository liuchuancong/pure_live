import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:pure_live/player/core/live_audio_handler.dart';
import 'package:pure_live/player/core/background_playback_policy.dart';
import 'package:pure_live/player/core/background_playback_service.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';


class LiveAudioService {
  LiveAudioService._();

  static LiveAudioHandler? _handler;

  static UnifiedPlayer? _boundPlayer;

  static Future<LiveAudioHandler?>? _initializationFuture;

  static bool _mprisInitialized = false;

  static int _sleepMinutes = 60;

  static bool get isSupportedPlatform {
    return PlatformUtils.isMobile || PlatformUtils.isMacOS || PlatformUtils.isWindows || PlatformUtils.isLinux;
  }

  static bool get isSystemMediaControlSupported {
    return PlatformUtils.isMobile || PlatformUtils.isMacOS || PlatformUtils.isWindows || PlatformUtils.isLinux;
  }

  static bool get isSleepSessionActive {
    return BackgroundPlaybackService.sleepSessionActive;
  }

  static bool get shouldContinueInBackground {
    return BackgroundPlaybackPolicy.shouldContinue(
      backgroundPlaybackEnabled: SettingsService.to.app.enableBackgroundPlay.v,
      sleepSessionActive: BackgroundPlaybackService.sleepSessionActive,
      audioOnlySessionActive: BackgroundPlaybackService.audioOnlySessionActive,
    );
  }

  static bool get isInitialized => _handler != null;

  static Future<LiveAudioHandler?> _ensureInitialized() {
    if (_handler != null) {
      return Future.value(_handler);
    }

    return _initializationFuture ??= _initialize();
  }

  static Future<LiveAudioHandler?> _initialize() async {
    try {
      if (!isSupportedPlatform) {
        return null;
      }

      if (PlatformUtils.isLinux && !_mprisInitialized) {
        AudioServiceMpris.init(
          dBusName: 'io.github.liuchuancong.purelive.channel.audio',
          identity: 'PureLive Playback',
          canControl: true,
          canPlay: true,
          canPause: true,
          canGoNext: true,
          canGoPrevious: true,
        );

        _mprisInitialized = true;
      }

      final handler = await AudioService.init(
        builder: () => LiveAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.mystyle.purelive.audio',
          androidNotificationChannelName: i18n('audio_channel_name'),
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          notificationColor: Colors.blue,
        ),
      );

      _handler = handler;

      return handler;
    } catch (error, stackTrace) {
      debugPrint('LiveAudioService initialization failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      _initializationFuture = null;

      return null;
    }
  }

  static Future<void> setPlayer(UnifiedPlayer player, {required bool audioOnly}) async {
    BackgroundPlaybackService.audioOnlySessionActive = audioOnly;

    if (!isSupportedPlatform) {
      await syncKeepAlive();
      return;
    }

    final handler = await _ensureInitialized();

    if (handler != null && !identical(_boundPlayer, player)) {
      await handler.setPlayer(player);

      _boundPlayer = player;
    }

    await syncKeepAlive();
  }

  static Future<void> start(String roomId, String title, String author, String? cover) async {
    if (!isSupportedPlatform) {
      return;
    }

    final handler = await _ensureInitialized();

    if (handler == null) {
      return;
    }

    final item = buildMediaItem(roomId: roomId, title: title, author: author, cover: cover);

    try {
      await handler.activateSession();
    } catch (error, stackTrace) {
      debugPrint('Audio session activation failed: $error');

      debugPrintStack(stackTrace: stackTrace);
    }

    await handler.playMediaItem(item);

    handler.configureSleepTimer(BackgroundPlaybackService.sleepSessionActive ? Duration(minutes: _sleepMinutes) : null);

    await syncKeepAlive();
  }

  static MediaItem buildMediaItem({
    required String roomId,
    required String title,
    required String author,
    String? cover,
  }) {
    Uri? artUri;

    if (cover != null && cover.trim().isNotEmpty) {
      artUri = Uri.tryParse(cover.trim());

      if (artUri != null && artUri.scheme != 'http' && artUri.scheme != 'https') {
        artUri = null;
      }
    }

    return MediaItem(id: roomId, album: i18nOr('app_name', 'PureLive'), title: title, artist: author, artUri: artUri);
  }

  static Future<void> stop() async {
    BackgroundPlaybackService.sleepSessionActive = false;
    BackgroundPlaybackService.audioOnlySessionActive = false;

    _handler?.configureSleepTimer(null);

    _sleepMinutes = 60;

    await BackgroundPlaybackService.setKeepAlive(false);

    final handler = _handler;

    if (handler == null) {
      _boundPlayer = null;
      return;
    }

    if (!isSupportedPlatform) {
      _boundPlayer = null;
      return;
    }

    try {
      await handler.stop();
    } catch (error, stackTrace) {
      debugPrint('LiveAudioService stop failed: $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _boundPlayer = null;
    }
  }

  static Future<void> configureSleepTimer({required bool enabled, required int minutes}) async {
    _sleepMinutes = minutes.clamp(1, AppSettingsController.maxSleepMinutes).toInt();

    BackgroundPlaybackService.sleepSessionActive = enabled;

    final handler = _handler;

    handler?.configureSleepTimer(enabled ? Duration(minutes: _sleepMinutes) : null);

    await syncKeepAlive();
  }

  static Future<void> releaseKeepAlive() {
    return BackgroundPlaybackService.setKeepAlive(false);
  }

  static Future<void> syncKeepAlive() {
    final handler = _handler;

    final playing = handler?.playbackState.value.playing ?? false;

    final shouldKeepAlive = playing && shouldContinueInBackground;

    return BackgroundPlaybackService.setKeepAlive(shouldKeepAlive);
  }

  static Future<bool> requestPlatformPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    if (await Permission.notification.status != PermissionStatus.granted) {
      final confirm = await _showExplainDialog(
        title: i18n('permission_notification_title'),
        content: i18n('permission_notification_content'),
      );

      if (confirm) {
        await Permission.notification.request();
      }

      if (await Permission.notification.status != PermissionStatus.granted) {
        return false;
      }
    }

    if (await Permission.ignoreBatteryOptimizations.status != PermissionStatus.granted) {
      final confirm = await _showExplainDialog(
        title: i18n('permission_battery_title'),
        content: i18n('permission_battery_content'),
      );

      if (confirm) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    return true;
  }

  static Future<bool> _showExplainDialog({required String title, required String content}) async {
    bool isConfirm = false;

    await SmartDialog.show(
      builder: (context) {
        return Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(content, textAlign: TextAlign.center, style: AppTextStyles.t14),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      SmartDialog.dismiss();
                    },
                    child: Text(i18n('permission_cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      isConfirm = true;
                      SmartDialog.dismiss();
                    },
                    child: Text(i18n('permission_go_enable')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return isConfirm;
  }
}
