import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/plugins/font_download_manager.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/medels/download_status.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class FontSettingsController extends GetxController {
  Future<void>? _initialization;
  Worker? _themeWorker;
  final RxDouble textScaleFactor = hiveDouble('textScaleFactor', 1.0);
  final RxDouble fontSizeBodySmall = hiveDouble('fontSizeBodySmall', 12.0);
  final RxDouble fontSizeBodyMedium = hiveDouble('fontSizeBodyMedium', 13.0);
  final RxDouble fontSizeBodyLarge = hiveDouble('fontSizeBodyLarge', 14.0);
  final RxDouble fontSizeTitleMedium = hiveDouble('fontSizeTitleMedium', 15.0);
  final RxDouble fontSizeTitleLarge = hiveDouble('fontSizeTitleLarge', 20.0);
  final RxString fontFamilyName = hiveString('fontFamilyName', 'Default');
  final RxString fontFamilyFileName = hiveString('fontFamilyFileName', '');
  final Rx<FontModel?> curFontModel = Rx<FontModel?>(null);
  final RxList<FontModel> fontList = <FontModel>[].obs;
  final Rx<DownloadState> fontState = DownloadState.notDownloaded.obs;
  final RxMap<String, String> fontFolderSizes = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
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
    final fileName = fontFamilyFileName.v;

    if (fontList.isEmpty) {
      return;
    }

    curFontModel.value = fontList.firstWhere((e) => e.id == id, orElse: () => fontList.first);

    if (id == 'Default') {
      fontState.value = DownloadState.notDownloaded;
      return;
    }

    final downloaded = await FontDownloadManager.instance.checkFontDownloaded(id);

    fontState.value = downloaded ? DownloadState.downloaded : DownloadState.notDownloaded;

    if (downloaded) {
      await FontDownloadManager.instance.loadFont(id, fileName: fileName);
    }
  }

  Future<void> activateFontFamily(FontModel fontModel, {String? targetFileName}) async {
    final fileName = targetFileName ?? '';

    await FontDownloadManager.instance.loadFont(fontModel.id, fileName: fileName);

    fontFamilyName.v = fontModel.id;
    fontFamilyFileName.v = fileName;

    await HivePrefUtil.setString('fontFamilyName', fontModel.id);
    await HivePrefUtil.setString('fontFamilyFileName', fileName);

    curFontModel.value = fontModel;
    fontState.value = DownloadState.downloaded;

    refreshSystemTheme();
    Get.updateLocale(Get.locale ?? const Locale('zh', 'CN'));

    if (targetFileName != null) {
      final subName = targetFileName.split('-').last;
      ToastUtil.show(i18n('font_toast_exclusive', args: {"name": fontModel.name, "subName": subName}));
    } else {
      ToastUtil.show(i18n('font_toast_global', args: {"name": fontModel.name}));
    }
  }

  Future<void> activateDanmakuFontFamily(FontModel font, {String? targetFileName}) async {
    final controller = Get.find<DanmakuSettingsController>();
    final fileName = targetFileName ?? '';

    controller.danmakuFontFamilyName.v = font.id;
    controller.danmakuFontFamilyFileName.v = fileName;

    await HivePrefUtil.setString('danmakuFontFamilyName', font.id);
    await HivePrefUtil.setString('danmakuFontFamilyFileName', fileName);
  }

  Future<void> refreshFontDiskSizes() async {
    final dir = await AppPathManager().getDir(AppPathManager.dirDownload);
    final fontDir = Directory('${dir.path}/fonts');
    if (!await fontDir.exists()) return;
    fontFolderSizes.clear();
    await for (final entity in fontDir.list()) {
      if (entity is! Directory) continue;
      final id = entity.path.split(Platform.pathSeparator).last;
      int bytes = 0;
      await for (final f in entity.list(recursive: true)) {
        if (f is File) bytes += await f.length();
      }
      fontFolderSizes[id] = '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
  }

  Future<void> uninstallFontFamily(FontModel font) async {
    await FontDownloadManager.instance.deleteFontFamily(font, (s) {});
    if (fontFamilyName.v == font.id) {
      fontFamilyName.v = 'Default';
      fontFamilyFileName.v = '';

      await HivePrefUtil.setString('fontFamilyName', 'Default');
      await HivePrefUtil.setString('fontFamilyFileName', '');

      refreshSystemTheme();
    }
    await refreshFontDiskSizes();
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
    };
  }

  void fromJson(Map<String, dynamic> json) {
    textScaleFactor.v = json['textScaleFactor'] ?? 1.0;
    fontSizeBodySmall.v = json['fontSizeBodySmall'] ?? 12.0;
    fontSizeBodyMedium.v = json['fontSizeBodyMedium'] ?? 13.0;
    fontSizeBodyLarge.v = json['fontSizeBodyLarge'] ?? 14.0;
    fontSizeTitleMedium.v = json['fontSizeTitleMedium'] ?? 15.0;
    fontSizeTitleLarge.v = json['fontSizeTitleLarge'] ?? 20.0;
    fontFamilyName.v = json['fontFamilyName'] ?? 'Default';
    fontFamilyFileName.v = json["fontFamilyFileName"] ?? '';
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final font = rootConfig?['font'] as Map<String, dynamic>? ?? {};
    return {
      'textScaleFactor': (font['textScaleFactor'] ?? 1.0).toDouble(),
      'fontSizeBodySmall': (font['fontSizeBodySmall'] ?? 12.0).toDouble(),
      'fontSizeBodyMedium': (font['fontSizeBodyMedium'] ?? 13.0).toDouble(),
      'fontSizeBodyLarge': (font['fontSizeBodyLarge'] ?? 14.0).toDouble(),
      'fontSizeTitleMedium': (font['fontSizeTitleMedium'] ?? 15.0).toDouble(),
      'fontSizeTitleLarge': (font['fontSizeTitleLarge'] ?? 20.0).toDouble(),
      'fontFamilyName': font['fontFamilyName'] ?? 'Default',
      'fontFamilyFileName': font['fontFamilyFileName'] ?? '',
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final font = Map<String, dynamic>.from(rootConfig['font'] ?? {});
    updateFields.forEach((k, v) => font[k] = v);
    rootConfig['font'] = font;
    return rootConfig;
  }
}
