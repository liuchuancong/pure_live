import 'dart:io';
import 'dart:convert';

import 'package:pure_live/get/get.dart';
import 'package:synchronized/synchronized.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/storage/hive_rx.dart';
import 'package:pure_live/domains/live/presentation/tags/tag_management_controller.dart';
import 'package:pure_live/features/web_dav/web_dav_settings_controller.dart';
import 'package:pure_live/domains/live/data/history_controller.dart';
import 'package:pure_live/core/config/startup_controller.dart';
import 'package:pure_live/core/config/window_size_controller.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';
import 'package:pure_live/domains/iptv/data/iptv_settings_controller.dart';
import 'package:pure_live/core/config/exit_settings_controller.dart';
import 'package:pure_live/core/config/page_settings_controller.dart';
import 'package:pure_live/core/config/refresh_config_controller.dart';
import 'package:pure_live/core/config/theme_settings_controller.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';
import 'package:pure_live/core/config/proxy_settings_controller.dart';
import 'package:pure_live/core/config/player_settings_controller.dart';
import 'package:pure_live/core/config/volume_settings_controller.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/room_card_settings_controller.dart';

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

  Map<String, dynamic> exportAllSettings({bool includeSensitiveData = true, Iterable<String>? sections}) {
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
      'background': Get.find<BackgroundController>().toJson(),
    };

    if (includeSensitiveData) {
      data['webdav'] = Get.find<WebDavController>().toJson();
      data['cookie'] = Get.find<CookieSettingsController>().toJson();
    }

    final filtered = filterBackupSections(data, sections);
    if (!identical(filtered, data)) {
      // 勾选结果决定这份备份到底有没有带凭据，标记必须跟着走。
      filtered['sensitiveDataIncluded'] =
          includeSensitiveData && (filtered.containsKey('webdav') || filtered.containsKey('cookie'));
    }
    return filtered;
  }

  /// Removes credentials and session cookies before a backup leaves the device.
  static Map<String, dynamic> redactSensitiveData(Map<String, dynamic> source) {
    final result = Map<String, dynamic>.from(source)
      ..remove('webdav')
      ..remove('cookie');
    result['sensitiveDataIncluded'] = false;
    return result;
  }

  /// 备份里可单独勾选的顶层模块，顺序即选择页的显示顺序。
  ///
  /// 与 [_sectionKeys] 同一个来源：新增一个 section，选择页与导入校验会一起看到它。
  static List<String> get sectionNames => List<String>.unmodifiable(_sectionKeys.keys);

  /// 电视端推送支持的模块：`/api/setSettings` 是扁平负载，只认这几段。
  static const List<String> tvSectionNames = <String>['danmaku', 'favorite', 'history', 'iptv', 'cookie'];

  /// [data] 里实际带了的模块，顺序同 [sectionNames]。
  static List<String> presentSections(Map<String, dynamic> data) {
    return [
      for (final name in _sectionKeys.keys)
        if (data.containsKey(name)) name,
    ];
  }

  /// 读取备份文件里实际带了的模块；解析不出本程序的备份返回 null。
  ///
  /// 返回空列表表示这是一份旧版扁平备份（没有模块划分），调用方只能整份恢复。
  static Future<List<String>?> readBackupSections(File file) async {
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      return presentSections(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// 只保留勾选的模块。`sections` 为 null 表示不过滤（整份使用）。
  ///
  /// 版本这类元字段永远保留，否则过滤后的备份自己就读不出来了。
  static Map<String, dynamic> filterBackupSections(Map<String, dynamic> data, Iterable<String>? sections) {
    if (sections == null) return data;
    final selected = sections.toSet();
    return <String, dynamic>{
      for (final entry in data.entries)
        if (_metaKeys.contains(entry.key) || selected.contains(entry.key)) entry.key: entry.value,
    };
  }

  static const Set<String> _metaKeys = <String>{'backupVersion', 'backupScope', 'sensitiveDataIncluded'};

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
    'background': BackgroundController.extractConfig(null).keys.toSet(),
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

  void importAllSettings(Map<String, dynamic> data, {Iterable<String>? sections}) {
    _importSettings(filterBackupSections(data, sections));
  }

  void _importSettings(Map<String, dynamic> data) {
    if (data['backupScope'] == 'favorites') {
      throw const FormatException('Favorites-only backup requires favorites restore');
    }
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
      'background': BackgroundController.parseConfig,
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

    // Only when present: a backup taken before the background feature existed
    // must not wipe the wallpaper the device is using.
    if (data.containsKey('background')) {
      Get.find<BackgroundController>().fromJson(Map<String, dynamic>.from(data['background'] ?? {}));
    }

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
      'background',
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

  Future<bool> backup(File file, {Iterable<String>? sections}) async {
    return _writeBackup(file, exportAllSettings(sections: sections));
  }

  Future<bool> _writeBackup(File file, Map<String, dynamic> data) async {
    final staged = File('${file.path}.part');
    final previous = File('${file.path}.previous');
    try {
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

  Future<void> restoreAllSettings(Map<String, dynamic> data, {Iterable<String>? sections}) async {
    if (data['backupScope'] == 'favorites') {
      throw const FormatException('Favorites-only backup requires favorites restore');
    }
    await _persistRestore(() => importAllSettings(data, sections: sections));
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

  Future<bool> recover(File file, {Iterable<String>? sections}) async {
    try {
      final json = await file.readAsString();
      final data = jsonDecode(json);

      if (data is! Map<String, dynamic>) {
        return false;
      }

      await restoreAllSettings(data, sections: sections);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Imports the settings a new Windows window received from its launcher,
  /// then removes the temporary file and its folder.
  Future<bool> recoverAndDelete(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      final json = await file.readAsString();
      final data = jsonDecode(json);
      if (data is! Map<String, dynamic>) {
        return false;
      }
      importAllSettings(data);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        final parent = file.parent;
        if (await parent.exists()) {
          try {
            await parent.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic> exportToTVSettings({bool includeSensitiveData = true, Iterable<String>? sections}) {
    final selected = sections?.toSet();
    bool wanted(String name) => selected == null || selected.contains(name);

    final data = <String, dynamic>{};
    if (wanted('danmaku')) data.addAll(Get.find<DanmakuSettingsController>().toJson());
    if (wanted('favorite')) data.addAll(Get.find<FavoriteRoomController>().toJson());
    if (wanted('history')) data.addAll(Get.find<HistoryController>().toJson());
    if (wanted('iptv')) {
      data['customIptvUserAgent'] = Get.find<IptvSettingsController>().toJson()['customIptvUserAgent'];
    }
    if (includeSensitiveData && wanted('cookie')) {
      data.addAll(Get.find<CookieSettingsController>().toJson());
    }
    return data;
  }
}
