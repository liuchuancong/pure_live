import 'dart:io';
import 'dart:convert';

import 'package:synchronized/synchronized.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/page_settings_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings/proxy_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';

enum BackupRestoreScope { all, favorites }

class BackupController extends GetxController {
  static BackupController get to => Get.find();

  static const int backupVersion = 3;
  static bool _restoreInProgress = false;
  final Lock _directoryMutationLock = Lock();

  final RxString backupDirectory = hiveString('backupDirectory', '');

  Future<void> setBackupDirectoryDurably(String directory) {
    return _directoryMutationLock.synchronized(() async {
      final normalized = directory.trim();
      final previous = backupDirectory.v;
      backupDirectory.v = normalized;
      try {
        await HivePrefUtil.setString('backupDirectory', normalized);
        await HivePrefUtil.flush();
      } catch (_) {
        backupDirectory.v = previous;
        await HivePrefUtil.setString('backupDirectory', previous);
        await HivePrefUtil.flush();
        rethrow;
      }
    });
  }

  Map<String, dynamic> exportAllSettings({bool includeSensitiveData = false}) {
    if (!Get.isRegistered<TagManagementController>()) {
      Get.put(TagManagementController());
    }

    final data = <String, dynamic>{
      'backupVersion': backupVersion,
      'sensitiveDataIncluded': includeSensitiveData,
      'app': Get.find<AppSettingsController>().toJson(),
      'theme': Get.find<ThemeSettingsController>().toJson(),
      'roomCard': Get.find<RoomCardSettingsController>().toJson(),
      'font': Get.find<FontSettingsController>().toJson(),
      'player': Get.find<PlayerSettingsController>().toJson(),
      'danmaku': Get.find<DanmakuSettingsController>().toJson(),
      'volume': Get.find<VolumeSettingsController>().toJson(),
      'favorite': Get.find<FavoriteRoomController>().toJson(),
      'history': Get.find<HistoryController>().toJson(),
      'iptv': Get.find<IptvSettingsController>().toJson(),
      'proxy': Get.find<ProxySettingsController>().toJson(),
      'windowSize': Get.find<WindowSizeController>().toJson(),
      'exit': Get.find<ExitSettingsController>().toJson(),
      'startup': Get.find<StartupController>().toJson(),
      'tags': Get.find<TagManagementController>().exportToJson(),
      'refresh': Get.find<RefreshConfigController>().toJson(),
      'page': Get.find<PageSettingsController>().toJson(),
    };

    if (includeSensitiveData) {
      data['webdav'] = Get.find<WebDavController>().toJson();
      data['cookie'] = Get.find<CookieSettingsController>().toJson();
    }
    return data;
  }

  /// Removes credentials and session cookies before a backup leaves the device.
  static Map<String, dynamic> redactSensitiveData(Map<String, dynamic> source) {
    final result = Map<String, dynamic>.from(source)
      ..remove('webdav')
      ..remove('cookie');
    result['sensitiveDataIncluded'] = false;
    return result;
  }

  // Derive recognized wire keys from the existing canonical configuration
  // extractors, rather than maintaining another list of hundreds of fields.
  static final Map<String, Set<String>> _sectionKeys = {
    'app': AppSettingsController.extractConfig(null).keys.toSet(),
    'theme': ThemeSettingsController.extractConfig(null).keys.toSet()..add('languageName'),
    'roomCard': RoomCardSettingsController.extractConfig(null).keys.toSet()
      ..addAll({
        'room_card_mobile_preset',
        'room_card_desktop_preset',
        'room_card_mobile_config',
        'room_card_desktop_config',
      }),
    'font': FontSettingsController.extractConfig(null).keys.toSet(),
    'player': PlayerSettingsController.extractConfig(null).keys.toSet(),
    'danmaku': DanmakuSettingsController.extractConfig(null).keys.toSet()..add('pipDanmaNoEmojiMode'),
    'volume': VolumeSettingsController.extractConfig(null).keys.toSet(),
    'favorite': FavoriteRoomController.extractConfig(null).keys.toSet(),
    'history': HistoryController.extractConfig(null).keys.toSet(),
    'webdav': WebDavController.extractConfig(null).keys.toSet(),
    'iptv': IptvSettingsController.extractConfig(null).keys.toSet(),
    'cookie': CookieSettingsController.extractConfig(null).keys.toSet(),
    'proxy': ProxySettingsController.extractConfig(null).keys.toSet(),
    'windowSize': WindowSizeController.extractConfig(null).keys.toSet(),
    'exit': ExitSettingsController.extractConfig(null).keys.toSet(),
    'startup': StartupController.extractConfig(null).keys.toSet(),
    'refresh': RefreshConfigController.extractConfig(null).keys.toSet(),
    'page': PageSettingsController.extractConfig(null).keys.toSet(),
    'tags': {'tags', 'roomTagsMap'},
  };

  static int countConfigSections(Map<String, dynamic> data) {
    return _sectionKeys.keys.where(data.containsKey).length;
  }

  static void validateBackupIdentity(Map<String, dynamic> data) {
    final version = data['backupVersion'];
    if (version != null && (version is! int || version < 1)) {
      throw const FormatException('Invalid backup version');
    }
    bool recognized = false;
    if (version == null) {
      final legacyTags = data['custom_tags_data'];
      recognized =
          (legacyTags is Map && legacyTags.keys.any(_sectionKeys['tags']!.contains)) ||
          data.containsKey('pipDanmaNoEmojiMode') ||
          _sectionKeys.entries
              .where((entry) => entry.key != 'tags')
              .any((entry) => data.keys.any(entry.value.contains));
    } else {
      validateSectionStructure(data);
      recognized = _sectionKeys.entries.any((entry) {
        final section = data[entry.key];
        return section is Map && section.keys.any(entry.value.contains);
      });
    }
    if (!recognized) throw const FormatException('No recognized backup settings');
  }

  void importAllSettings(Map<String, dynamic> data) {
    validateBackupIdentity(data);
    final version = data['backupVersion'];

    // Validate input before any controller notifies observers or persists it.
    // This does not make asynchronous storage failures transactional.
    if (version != null) validateSectionStructure(data);
    final parsers = <String, Map<String, dynamic> Function(Map<String, dynamic>)>{
      'app': AppSettingsController.parseConfig,
      'player': PlayerSettingsController.parseConfig,
      'danmaku': DanmakuSettingsController.parseConfig,
      'windowSize': WindowSizeController.parseConfig,
      'theme': ThemeSettingsController.parseConfig,
      'roomCard': RoomCardSettingsController.parseConfig,
      'font': FontSettingsController.parseConfig,
      'exit': ExitSettingsController.parseConfig,
      'iptv': IptvSettingsController.parseConfig,
      'startup': StartupController.parseConfig,
      'proxy': ProxySettingsController.parseConfig,
      'refresh': RefreshConfigController.parseConfig,
      'cookie': CookieSettingsController.parseConfig,
      'favorite': FavoriteRoomController.parseConfig,
      'history': HistoryController.parseConfig,
      'webdav': WebDavController.parseConfig,
      'page': PageSettingsController.parseConfig,
    };
    for (final entry in parsers.entries) {
      if (version == null) {
        entry.value(data);
      } else if (data.containsKey(entry.key)) {
        entry.value(Map<String, dynamic>.from(data[entry.key] ?? {}));
      }
    }
    final tags = version == null ? data['custom_tags_data'] : data['tags'];
    if (tags != null) {
      TagManagementController.parseConfig(Map<String, dynamic>.from(tags));
    }
    if (version == null) {
      VolumeSettingsController.parseConfig(data);
    } else {
      VolumeSettingsController.parseConfig(Map<String, dynamic>.from(data['volume'] ?? {}));
      // Validate the legacy player-owned flag after normalizing its ownership.
      WindowSizeController.parseConfig(WindowSizeController.extractConfig(data));
    }

    if (version == null) {
      _importLegacy(data);
      return;
    }

    switch (version) {
      case 2:
      case 3:
        _importV2(data);
        break;

      default:
        _importLatestCompatible(data);
        break;
    }
  }

  void _importLatestCompatible(Map<String, dynamic> data) {
    _importV2(data);
  }

  void _importV2(Map<String, dynamic> data) {
    validateSectionStructure(data);
    Get.find<AppSettingsController>().fromJson(Map<String, dynamic>.from(data['app'] ?? {}));

    Get.find<ThemeSettingsController>().fromJson(Map<String, dynamic>.from(data['theme'] ?? {}));

    Get.find<RoomCardSettingsController>().fromJson(Map<String, dynamic>.from(data['roomCard'] ?? {}));

    Get.find<FontSettingsController>().fromJson(Map<String, dynamic>.from(data['font'] ?? {}));

    Get.find<PlayerSettingsController>().fromJson(Map<String, dynamic>.from(data['player'] ?? {}));

    Get.find<DanmakuSettingsController>().fromJson(Map<String, dynamic>.from(data['danmaku'] ?? {}));

    Get.find<VolumeSettingsController>().fromJson(Map<String, dynamic>.from(data['volume'] ?? {}));

    Get.find<FavoriteRoomController>().fromJson(Map<String, dynamic>.from(data['favorite'] ?? {}));

    Get.find<HistoryController>().fromJson(Map<String, dynamic>.from(data['history'] ?? {}));

    if (data.containsKey('webdav')) {
      Get.find<WebDavController>().fromJson(Map<String, dynamic>.from(data['webdav'] ?? {}));
    }

    Get.find<IptvSettingsController>().fromJson(Map<String, dynamic>.from(data['iptv'] ?? {}));

    if (data.containsKey('cookie')) {
      Get.find<CookieSettingsController>().fromJson(Map<String, dynamic>.from(data['cookie'] ?? {}));
    }

    Get.find<ProxySettingsController>().fromJson(Map<String, dynamic>.from(data['proxy'] ?? {}));

    // Normalize both the old flat PiP rectangle and the former player-owned
    // rememberPipPosition flag before importing the current window settings.
    Get.find<WindowSizeController>().fromJson(WindowSizeController.extractConfig(data));

    Get.find<ExitSettingsController>().fromJson(Map<String, dynamic>.from(data['exit'] ?? {}));

    Get.find<StartupController>().fromJson(Map<String, dynamic>.from(data['startup'] ?? {}));

    Get.find<RefreshConfigController>().fromJson(Map<String, dynamic>.from(data['refresh'] ?? {}));

    Get.find<PageSettingsController>().fromJson(Map<String, dynamic>.from(data['page'] ?? {}));

    if (!Get.isRegistered<TagManagementController>()) {
      Get.put(TagManagementController());
    }

    final tagsData = data['tags'];
    if (tagsData is Map) {
      Get.find<TagManagementController>().importFromJson(Map<String, dynamic>.from(tagsData));
    }
  }

  /// Reject malformed sections before any controller persists an earlier one.
  /// Missing/null sections keep their historical default-import behavior.
  static void validateSectionStructure(Map<String, dynamic> data) {
    const sections = <String>[
      'app',
      'theme',
      'roomCard',
      'font',
      'player',
      'danmaku',
      'volume',
      'favorite',
      'history',
      'webdav',
      'iptv',
      'cookie',
      'proxy',
      'windowSize',
      'exit',
      'startup',
      'refresh',
      'page',
      'tags',
    ];
    for (final name in sections) {
      final section = data[name];
      if (section == null) continue;
      if (section is! Map || section.keys.any((key) => key is! String)) {
        throw FormatException('Invalid backup section: $name');
      }
    }
  }

  void _importLegacy(Map<String, dynamic> data) {
    Get.find<AppSettingsController>().fromJson(data);
    Get.find<ThemeSettingsController>().fromJson(data);
    Get.find<RoomCardSettingsController>().fromJson(data);
    Get.find<FontSettingsController>().fromJson(data);
    Get.find<PlayerSettingsController>().fromJson(data);
    Get.find<DanmakuSettingsController>().fromJson(data);
    Get.find<VolumeSettingsController>().fromJson(data);
    Get.find<FavoriteRoomController>().fromJson(data);
    Get.find<HistoryController>().fromJson(data);
    Get.find<WebDavController>().fromJson(data);
    Get.find<IptvSettingsController>().fromJson(data);
    Get.find<CookieSettingsController>().fromJson(data);
    Get.find<ProxySettingsController>().fromJson(data);
    Get.find<WindowSizeController>().fromJson(data);
    Get.find<ExitSettingsController>().fromJson(data);
    Get.find<StartupController>().fromJson(data);
    Get.find<RefreshConfigController>().fromJson(data);
    Get.find<PageSettingsController>().fromJson(data);
    if (!Get.isRegistered<TagManagementController>()) {
      Get.put(TagManagementController());
    }

    final legacyTags = data['custom_tags_data'];
    if (legacyTags is Map) {
      Get.find<TagManagementController>().importFromJson(Map<String, dynamic>.from(legacyTags));
    }
  }

  Future<bool> backup(File file) async {
    final staged = File('${file.path}.part');
    final previous = File('${file.path}.previous');
    try {
      final data = exportAllSettings();
      if (!await file.parent.exists()) await file.parent.create(recursive: true);

      // Recover an interrupted replacement before starting a new one.
      if (await previous.exists()) {
        if (await file.exists()) {
          await previous.delete();
        } else {
          await previous.rename(file.path);
        }
      }
      if (await staged.exists()) await staged.delete();
      await staged.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);

      final hadPrevious = await file.exists();
      if (hadPrevious) await file.rename(previous.path);
      try {
        await staged.rename(file.path);
      } catch (_) {
        if (hadPrevious && await previous.exists() && !await file.exists()) {
          await previous.rename(file.path);
        }
        rethrow;
      }
      if (await previous.exists()) {
        try {
          await previous.delete();
        } catch (_) {
          // The completed backup is authoritative; stale rollback cleanup is
          // retried by the next backup targeting the same path.
        }
      }
      return true;
    } catch (_) {
      try {
        if (await staged.exists()) await staged.delete();
      } catch (_) {}
      return false;
    }
  }

  Future<void> restoreAllSettings(Map<String, dynamic> data) async {
    await _persistRestore(() => importAllSettings(data));
  }

  Future<void> restoreFavoriteSettings(Map<String, dynamic> data) async {
    await _persistRestore(() {
      final version = data['backupVersion'];
      if (version != null && (version is! int || version < 1)) {
        throw const FormatException('Invalid backup version');
      }

      final Map<String, dynamic> favorite;
      if (version == null) {
        favorite = data;
      } else {
        final section = data['favorite'];
        if (section is! Map || section.keys.any((key) => key is! String)) {
          throw const FormatException('Invalid backup section: favorite');
        }
        favorite = Map<String, dynamic>.from(section);
      }
      Get.find<FavoriteRoomController>().restoreFavoriteLists(favorite);
    });
  }

  Future<void> _persistRestore(void Function() restore) async {
    if (_restoreInProgress) throw StateError('A settings restore is already running');
    final previous = exportAllSettings(includeSensitiveData: true);
    _restoreInProgress = true;
    try {
      await HivePrefUtil.persistBatch(restore);
    } catch (_) {
      try {
        // Restore the complete in-memory controller graph as well as storage.
        // This also covers failures thrown after an earlier controller already
        // notified its observers during an otherwise valid import.
        await HivePrefUtil.persistBatch(() => importAllSettings(previous));
      } catch (_) {
        // Preserve the original restore failure for the caller. A later app
        // startup still reads the last successfully committed Hive snapshot.
      }
      rethrow;
    } finally {
      _restoreInProgress = false;
    }
  }

  Future<bool> recover(File file) async {
    try {
      final json = await file.readAsString();
      final data = jsonDecode(json);

      if (data is! Map<String, dynamic>) {
        return false;
      }

      await restoreAllSettings(data);

      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> exportToTVSettings({bool includeSensitiveData = false}) {
    final danmaku = Get.find<DanmakuSettingsController>().toJson();
    final iptv = Get.find<IptvSettingsController>().toJson();
    final favorite = Get.find<FavoriteRoomController>().toJson();
    final history = Get.find<HistoryController>().toJson();

    final data = <String, dynamic>{
      ...danmaku,
      ...favorite,
      ...history,
      'customIptvUserAgent': iptv['customIptvUserAgent'],
    };
    if (includeSensitiveData) {
      data.addAll(Get.find<CookieSettingsController>().toJson());
    }
    return data;
  }
}
