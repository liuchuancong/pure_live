import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/plugins/font_download_manager.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/services/medels/download_status.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class FontSettingsController extends GetxController {
  static const defaultFontFamilyName = 'Default';
  static const defaultTextScaleFactor = 1.0;
  static const minTextScaleFactor = 0.5;
  static const maxTextScaleFactor = 2.0;
  static const defaultFontSizeBodySmall = 12.0;
  static const minFontSizeBodySmall = 9.0;
  static const maxFontSizeBodySmall = 15.0;
  static const defaultFontSizeBodyMedium = 13.0;
  static const minFontSizeBodyMedium = 11.0;
  static const maxFontSizeBodyMedium = 17.0;
  static const defaultFontSizeBodyLarge = 14.0;
  static const minFontSizeBodyLarge = 12.0;
  static const maxFontSizeBodyLarge = 18.0;
  static const defaultFontSizeTitleMedium = 15.0;
  static const minFontSizeTitleMedium = 13.0;
  static const maxFontSizeTitleMedium = 20.0;
  static const defaultFontSizeTitleLarge = 20.0;
  static const minFontSizeTitleLarge = 16.0;
  static const maxFontSizeTitleLarge = 26.0;

  Future<void>? _initialization;
  Future<void>? _fontDiskSizeRefresh;
  DateTime? _lastFontDiskSizeRefresh;
  Worker? _themeWorker;
  final RxDouble textScaleFactor = hiveDouble('textScaleFactor', defaultTextScaleFactor);
  final RxDouble fontSizeBodySmall = hiveDouble('fontSizeBodySmall', defaultFontSizeBodySmall);
  final RxDouble fontSizeBodyMedium = hiveDouble('fontSizeBodyMedium', defaultFontSizeBodyMedium);
  final RxDouble fontSizeBodyLarge = hiveDouble('fontSizeBodyLarge', defaultFontSizeBodyLarge);
  final RxDouble fontSizeTitleMedium = hiveDouble('fontSizeTitleMedium', defaultFontSizeTitleMedium);
  final RxDouble fontSizeTitleLarge = hiveDouble('fontSizeTitleLarge', defaultFontSizeTitleLarge);
  final RxString fontFamilyName = hiveString('fontFamilyName', 'Default');
  final RxString fontFamilyFileName = hiveString('fontFamilyFileName', '');
  final RxString danmakuFontFamilyFileName = hiveString('danmakuFontFamilyFileName', '');

  final Rx<FontModel?> curFontModel = Rx<FontModel?>(null);
  final RxList<FontModel> fontList = <FontModel>[].obs;
  final Rx<DownloadState> fontState = DownloadState.notDownloaded.obs;
  final RxMap<String, String> fontFolderSizes = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _normalizeStoredTypography();
    unawaited(ensureInitialized());

    _themeWorker = everAll([
      fontSizeBodySmall,
      fontSizeBodyMedium,
      fontSizeBodyLarge,
      fontSizeTitleMedium,
      fontSizeTitleLarge,
      fontFamilyName,
    ], (_) => refreshSystemTheme());
  }

  void _normalizeStoredTypography() {
    textScaleFactor.v = _normalizeStoredValue(
      textScaleFactor.v,
      fallback: defaultTextScaleFactor,
      min: minTextScaleFactor,
      max: maxTextScaleFactor,
    );
    fontSizeBodySmall.v = _normalizeStoredValue(
      fontSizeBodySmall.v,
      fallback: defaultFontSizeBodySmall,
      min: minFontSizeBodySmall,
      max: maxFontSizeBodySmall,
    );
    fontSizeBodyMedium.v = _normalizeStoredValue(
      fontSizeBodyMedium.v,
      fallback: defaultFontSizeBodyMedium,
      min: minFontSizeBodyMedium,
      max: maxFontSizeBodyMedium,
    );
    fontSizeBodyLarge.v = _normalizeStoredValue(
      fontSizeBodyLarge.v,
      fallback: defaultFontSizeBodyLarge,
      min: minFontSizeBodyLarge,
      max: maxFontSizeBodyLarge,
    );
    fontSizeTitleMedium.v = _normalizeStoredValue(
      fontSizeTitleMedium.v,
      fallback: defaultFontSizeTitleMedium,
      min: minFontSizeTitleMedium,
      max: maxFontSizeTitleMedium,
    );
    fontSizeTitleLarge.v = _normalizeStoredValue(
      fontSizeTitleLarge.v,
      fallback: defaultFontSizeTitleLarge,
      min: minFontSizeTitleLarge,
      max: maxFontSizeTitleLarge,
    );
  }

  static double _normalizeStoredValue(
    double value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    if (!value.isFinite) return fallback;
    return value.clamp(min, max).toDouble();
  }

  static double _parseBoundedValue(Object? raw, {required double fallback, required double min, required double max}) {
    final value = ((raw ?? fallback) as num).toDouble();
    if (!value.isFinite) {
      throw const FormatException('Typography values must be finite');
    }
    return value.clamp(min, max).toDouble();
  }

  void resetTypography() {
    fontSizeBodySmall.v = defaultFontSizeBodySmall;
    fontSizeBodyMedium.v = defaultFontSizeBodyMedium;
    fontSizeBodyLarge.v = defaultFontSizeBodyLarge;
    fontSizeTitleMedium.v = defaultFontSizeTitleMedium;
    fontSizeTitleLarge.v = defaultFontSizeTitleLarge;
  }

  @override
  void onClose() {
    _themeWorker?.dispose();
    super.onClose();
  }

  Future<void> ensureInitialized() => _initialization ??= _initializeFonts();

  Future<void> _initializeFonts() async {
    await _loadInitialFontManifest();
    await initUserFontLifecycle();
    // This also runs before runApp so the selected custom font is ready for
    // the first ThemeData. Accessing Get.context here asks GetX for its root
    // navigator before GetMaterialApp exists and leaves Android on the native
    // splash screen. MyApp reads the initialized settings on its first build;
    // interactive font changes still call refreshSystemTheme below.
  }

  Future<void> _loadInitialFontManifest() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/fonts/fonts-manifest.json');
      final list = jsonDecode(jsonStr) as List;
      fontList.assignAll(list.map((e) => FontModel.fromJson(e)).toList());
    } catch (_) {}
  }

  Future<void> initUserFontLifecycle() async {
    final id = fontFamilyName.v;
    if (fontList.isEmpty) {
      return;
    }
    if (id == 'Microsoft YaHei') {
      curFontModel.value = fontList.firstWhere((e) => e.id == 'Default', orElse: () => fontList.first);
      fontState.value = DownloadState.notDownloaded;
    } else {
      curFontModel.value = fontList.firstWhere((e) => e.id == id, orElse: () => fontList.first);

      if (id == 'Default') {
        fontState.value = DownloadState.notDownloaded;
      } else {
        final downloaded = await FontDownloadManager.instance.checkFontDownloaded(id);
        fontState.value = downloaded ? DownloadState.downloaded : DownloadState.notDownloaded;

        if (downloaded) {
          var loaded = await FontDownloadManager.instance.loadFont(id, fileName: fontFamilyFileName.v);
          if (!loaded && fontFamilyFileName.v.isNotEmpty) {
            loaded = await FontDownloadManager.instance.loadFont(id);
            if (loaded) {
              fontFamilyFileName.v = '';
              await HivePrefUtil.setString('fontFamilyFileName', '');
            }
          }
          if (!loaded) {
            fontState.value = DownloadState.notDownloaded;
            fontFamilyName.v = Platform.isWindows ? 'Microsoft YaHei' : 'Default';
            await HivePrefUtil.setString('fontFamilyName', fontFamilyName.v);
            fontFamilyFileName.v = '';
            await HivePrefUtil.setString('fontFamilyFileName', '');
            if (fontFamilyName.v == 'Microsoft YaHei') {
              curFontModel.value = fontList.firstWhere((e) => e.id == 'Default', orElse: () => fontList.first);
            } else {
              curFontModel.value = fontList.firstWhere((e) => e.id == fontFamilyName.v, orElse: () => fontList.first);
            }
          }
        } else {
          fontState.value = DownloadState.notDownloaded;
          fontFamilyName.v = Platform.isWindows ? 'Microsoft YaHei' : 'Default';
          await HivePrefUtil.setString('fontFamilyName', fontFamilyName.v);
          fontFamilyFileName.v = '';
          await HivePrefUtil.setString('fontFamilyFileName', '');
          if (fontFamilyName.v == 'Microsoft YaHei') {
            curFontModel.value = fontList.firstWhere((e) => e.id == 'Default', orElse: () => fontList.first);
          } else {
            curFontModel.value = fontList.firstWhere((e) => e.id == fontFamilyName.v, orElse: () => fontList.first);
          }
        }
      }
    }

    // 处理弹幕字体
    final danmakuController = Get.find<DanmakuSettingsController>();
    final danmakuId = danmakuController.danmakuFontFamilyName.v;

    if (danmakuId != 'Default' && danmakuId != id && danmakuId != 'Microsoft YaHei') {
      final danmakuDownloaded = await FontDownloadManager.instance.checkFontDownloaded(danmakuId);
      if (danmakuDownloaded) {
        var loaded = await FontDownloadManager.instance.loadFont(danmakuId, fileName: danmakuFontFamilyFileName.v);
        if (!loaded && danmakuFontFamilyFileName.v.isNotEmpty) {
          loaded = await FontDownloadManager.instance.loadFont(danmakuId);
          if (loaded) {
            danmakuFontFamilyFileName.v = '';
            await HivePrefUtil.setString('danmakuFontFamilyFileName', '');
          }
        }
        if (!loaded) {
          danmakuController.danmakuFontFamilyName.v = 'Default';
          await HivePrefUtil.setString('danmakuFontFamilyName', 'Default');
          danmakuFontFamilyFileName.v = '';
          await HivePrefUtil.setString('danmakuFontFamilyFileName', '');
        }
      } else {
        danmakuController.danmakuFontFamilyName.v = 'Default';
        await HivePrefUtil.setString('danmakuFontFamilyName', 'Default');
        danmakuFontFamilyFileName.v = '';
        await HivePrefUtil.setString('danmakuFontFamilyFileName', '');
      }
    }
  }

  Future<bool> activateFontFamily(FontModel fontModel, {String? targetFileName}) async {
    final loaded = await FontDownloadManager.instance.loadFont(fontModel.id, fileName: targetFileName ?? '');
    if (!loaded) {
      ToastUtil.show(i18n('font_not_downloaded_or_corrupted'));
      return false;
    }
    final selectedFileName = targetFileName ?? '';
    await HivePrefUtil.setPrefs({'fontFamilyName': fontModel.id, 'fontFamilyFileName': selectedFileName});
    await HivePrefUtil.flush();
    fontFamilyName.v = fontModel.id;
    fontFamilyFileName.v = selectedFileName;
    curFontModel.value = fontModel;
    refreshSystemTheme();
    Get.updateLocale(Get.locale ?? const Locale('zh', 'CN'));
    if (targetFileName != null) {
      final subName = targetFileName.split('-').last;
      ToastUtil.show(i18n('font_toast_exclusive', args: {"name": fontModel.name, "subName": subName}));
    } else {
      ToastUtil.show(i18n('font_toast_global', args: {"name": fontModel.name}));
    }
    return true;
  }

  Future<bool> activateDanmakuFontFamily(FontModel font, {String? targetFileName}) async {
    final loaded = await FontDownloadManager.instance.loadFont(font.id, fileName: targetFileName ?? '');
    if (!loaded) {
      ToastUtil.show(i18n('font_not_downloaded_or_corrupted'));
      return false;
    }
    final selectedFileName = targetFileName ?? '';
    await HivePrefUtil.setPrefs({'danmakuFontFamilyName': font.id, 'danmakuFontFamilyFileName': selectedFileName});
    await HivePrefUtil.flush();
    Get.find<DanmakuSettingsController>().danmakuFontFamilyName.v = font.id;
    danmakuFontFamilyFileName.v = selectedFileName;
    return true;
  }

  Future<void> resetAppFontFamily() async {
    await HivePrefUtil.setPrefs({'fontFamilyName': defaultFontFamilyName, 'fontFamilyFileName': ''});
    await HivePrefUtil.flush();
    fontFamilyName.v = defaultFontFamilyName;
    fontFamilyFileName.v = '';
    refreshSystemTheme();
  }

  Future<void> resetDanmakuFontFamily() async {
    await HivePrefUtil.setPrefs({'danmakuFontFamilyName': defaultFontFamilyName, 'danmakuFontFamilyFileName': ''});
    await HivePrefUtil.flush();
    Get.find<DanmakuSettingsController>().danmakuFontFamilyName.v = defaultFontFamilyName;
    danmakuFontFamilyFileName.v = '';
  }

  Future<void> refreshFontDiskSizes({bool force = false}) {
    final inFlight = _fontDiskSizeRefresh;
    if (inFlight != null) return inFlight;
    final lastRefresh = _lastFontDiskSizeRefresh;
    if (!force && lastRefresh != null && DateTime.now().difference(lastRefresh) < const Duration(seconds: 30)) {
      return Future.value();
    }
    final refresh = _refreshFontDiskSizes();
    _fontDiskSizeRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_fontDiskSizeRefresh, refresh)) _fontDiskSizeRefresh = null;
    });
  }

  Future<void> _refreshFontDiskSizes() async {
    final dir = await CacheController.resolveDownloadDirectory();
    final fontDir = Directory('${dir.path}${Platform.pathSeparator}${AppPathManager.fontDirectoryName}');
    if (!await fontDir.exists()) {
      fontFolderSizes.clear();
      _lastFontDiskSizeRefresh = DateTime.now();
      return;
    }
    final nextSizes = <String, String>{};
    await for (final entity in fontDir.list()) {
      if (entity is! Directory) continue;
      final id = entity.path.split(Platform.pathSeparator).last;
      if (id.startsWith('.')) continue;
      if (!await FontDownloadManager.instance.checkFontDownloaded(id)) continue;
      int bytes = 0;
      await for (final f in entity.list(recursive: true)) {
        if (f is File) bytes += await f.length();
      }
      nextSizes[id] = '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    fontFolderSizes.assignAll(nextSizes);
    _lastFontDiskSizeRefresh = DateTime.now();
  }

  Future<bool> uninstallFontFamily(FontModel font) async {
    final deleted = await FontDownloadManager.instance.deleteFontFamily(font, (s) {});
    if (!deleted) return false;
    if (fontFamilyName.v == font.id) {
      await resetAppFontFamily();
    }
    final danmaku = Get.find<DanmakuSettingsController>();
    if (danmaku.danmakuFontFamilyName.v == font.id) {
      await resetDanmakuFontFamily();
    }
    await refreshFontDiskSizes(force: true);
    return true;
  }

  void refreshSystemTheme() {
    final theme = MyTheme(primaryColor: Get.theme.primaryColor);
    Get.changeTheme(Get.isDarkMode ? theme.darkThemeData : theme.lightThemeData);
  }

  Map<String, dynamic> toJson() {
    return {
      'textScaleFactor': textScaleFactor.v,
      'fontSizeBodySmall': fontSizeBodySmall.v,
      'fontSizeBodyMedium': fontSizeBodyMedium.v,
      'fontSizeBodyLarge': fontSizeBodyLarge.v,
      'fontSizeTitleMedium': fontSizeTitleMedium.v,
      'fontSizeTitleLarge': fontSizeTitleLarge.v,
      'fontFamilyName': fontFamilyName.v,
      'fontFamilyFileName': fontFamilyFileName.v,
      'danmakuFontFamilyFileName': danmakuFontFamilyFileName.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'textScaleFactor': _parseBoundedValue(
        json['textScaleFactor'],
        fallback: defaultTextScaleFactor,
        min: minTextScaleFactor,
        max: maxTextScaleFactor,
      ),
      'fontSizeBodySmall': _parseBoundedValue(
        json['fontSizeBodySmall'],
        fallback: defaultFontSizeBodySmall,
        min: minFontSizeBodySmall,
        max: maxFontSizeBodySmall,
      ),
      'fontSizeBodyMedium': _parseBoundedValue(
        json['fontSizeBodyMedium'],
        fallback: defaultFontSizeBodyMedium,
        min: minFontSizeBodyMedium,
        max: maxFontSizeBodyMedium,
      ),
      'fontSizeBodyLarge': _parseBoundedValue(
        json['fontSizeBodyLarge'],
        fallback: defaultFontSizeBodyLarge,
        min: minFontSizeBodyLarge,
        max: maxFontSizeBodyLarge,
      ),
      'fontSizeTitleMedium': _parseBoundedValue(
        json['fontSizeTitleMedium'],
        fallback: defaultFontSizeTitleMedium,
        min: minFontSizeTitleMedium,
        max: maxFontSizeTitleMedium,
      ),
      'fontSizeTitleLarge': _parseBoundedValue(
        json['fontSizeTitleLarge'],
        fallback: defaultFontSizeTitleLarge,
        min: minFontSizeTitleLarge,
        max: maxFontSizeTitleLarge,
      ),
      'fontFamilyName': (json['fontFamilyName'] ?? 'Default') as String,
      'fontFamilyFileName': (json['fontFamilyFileName'] ?? '') as String,
      'danmakuFontFamilyFileName': (json['danmakuFontFamilyFileName'] ?? '') as String,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    textScaleFactor.v = parsed['textScaleFactor'];
    fontSizeBodySmall.v = parsed['fontSizeBodySmall'];
    fontSizeBodyMedium.v = parsed['fontSizeBodyMedium'];
    fontSizeBodyLarge.v = parsed['fontSizeBodyLarge'];
    fontSizeTitleMedium.v = parsed['fontSizeTitleMedium'];
    fontSizeTitleLarge.v = parsed['fontSizeTitleLarge'];
    fontFamilyName.v = parsed['fontFamilyName'];
    fontFamilyFileName.v = parsed['fontFamilyFileName'];
    danmakuFontFamilyFileName.v = parsed['danmakuFontFamilyFileName'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final font = rootConfig?['font'] as Map<String, dynamic>? ?? {};
    return parseConfig(font);
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final font = Map<String, dynamic>.from(rootConfig['font'] ?? {});
    updateFields.forEach((k, v) => font[k] = v);
    rootConfig['font'] = font;
    return rootConfig;
  }
}
