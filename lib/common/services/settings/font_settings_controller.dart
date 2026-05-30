import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/plugins/font_download_manager.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/medels/download_status.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class FontSettingsController extends GetxController {
  final RxDouble textScaleFactor = hiveDouble('textScaleFactor', 1.0);
  final RxDouble fontSizeBodySmall = hiveDouble('fontSizeBodySmall', 12.0);
  final RxDouble fontSizeBodyMedium = hiveDouble('fontSizeBodyMedium', 13.0);
  final RxDouble fontSizeBodyLarge = hiveDouble('fontSizeBodyLarge', 14.0);
  final RxDouble fontSizeTitleMedium = hiveDouble('fontSizeTitleMedium', 15.0);
  final RxDouble fontSizeTitleLarge = hiveDouble('fontSizeTitleLarge', 20.0);
  final RxString fontFamilyName = hiveString('fontFamilyName', 'Default');

  final Rx<FontModel?> curFontModel = Rx<FontModel?>(null);
  final RxList<FontModel> fontList = <FontModel>[].obs;
  final Rx<DownloadState> fontState = DownloadState.notDownloaded.obs;
  final RxMap<String, String> fontFolderSizes = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialFontManifest();
    initUserFontLifecycle();

    everAll([
      fontSizeBodySmall,
      fontSizeBodyMedium,
      fontSizeBodyLarge,
      fontSizeTitleMedium,
      fontSizeTitleLarge,
      fontFamilyName,
    ], (_) => refreshSystemTheme());
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
    if (id != 'Default') {
      if (await FontDownloadManager.instance.checkFontDownloaded(id)) {
        await FontDownloadManager.instance.loadFont(id);
      }
    }
    curFontModel.value = fontList.firstWhere((e) => e.id == id, orElse: () => fontList.first);
    fontState.value = await FontDownloadManager.instance.checkFontDownloaded(curFontModel.value!.id)
        ? DownloadState.downloaded
        : DownloadState.notDownloaded;
  }

  Future<void> activateFontFamily(FontModel fontModel, {String? targetFileName}) async {
    fontFamilyName.v = fontModel.id;
    curFontModel.value = fontModel;
    fontState.value = DownloadState.downloaded;

    await FontDownloadManager.instance.loadFont(fontModel.id, fileName: targetFileName ?? '');
    Get.updateLocale(Get.locale ?? const Locale('zh', 'CN'));
    if (targetFileName != null) {
      final subName = targetFileName.split('-').last;
      ToastUtil.show(i18n('font_toast_exclusive', args: {"name": fontModel.name, "subName": subName}));
    } else {
      ToastUtil.show(i18n('font_toast_global', args: {"name": fontModel.name}));
    }
  }

  Future<void> activateDanmakuFontFamily(FontModel font) async {
    Get.find<DanmakuSettingsController>().danmakuFontFamilyName.v = font.id;
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
      fontFamilyName.v = Platform.isWindows ? "Microsoft YaHei" : 'Default';
    }
    refreshFontDiskSizes();
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
  }
}
