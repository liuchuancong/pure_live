import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

// download_apk_dialog.dart

class DownloadApkDialog extends StatefulWidget {
  final String apkUrl;
  final String version; // 可选：用于显示版本号

  const DownloadApkDialog({super.key, required this.apkUrl, this.version = ''});

  @override
  State<DownloadApkDialog> createState() => _DownloadApkDialogState();
}

class _DownloadApkDialogState extends State<DownloadApkDialog> {
  late Dio _dio;
  late CancelToken _cancelToken;
  int _progress = 0;
  bool _isDownloading = true;
  String _statusText = i18n("download_preparing");

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        responseType: ResponseType.stream,
      ),
    );
    _startDownload();
  }

  Future<void> _startDownload() async {
    final apkName = widget.apkUrl.split('/').last;
    Directory? dir = await _getSafeDownloadDir();
    final apkDir = Directory('${dir.path}${path.separator}pure_live');
    if (!apkDir.existsSync()) {
      apkDir.createSync(recursive: true);
    }
    final file = File('${apkDir.path}${path.separator}$apkName');

    try {
      await _dio.download(
        widget.apkUrl,
        file.path,
        options: Options(
          headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache', 'Expires': '0'},
          receiveTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            final progress = (received / total * 100).toInt();

            final status = i18n("downloading_progress", args: {"version": widget.version, "progress": "$progress"});

            setState(() {
              _progress = progress;
              _statusText = status;
            });
          } else if (mounted) {
            final mb = received ~/ (1024 * 1024);

            setState(() {
              _statusText = i18n("downloaded_mb", args: {"mb": "$mb"});
            });
          }
        },
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = i18n("download_complete_installing");
        });

        Navigator.of(Get.context!).pop(false);

        if (Platform.isAndroid) {
          final result = await OpenFilex.open(file.path, type: "application/vnd.android.package-archive");

          if (result.type != ResultType.done) {
           Get.snackbar(
  i18n("install_failed"),
  i18n("install_unknown_app_permission_tip", args: {
    "message": result.message,
  }),
);
          }
        } else if (PlatformUtils.isDesktop) {
          final result = await OpenFilex.open(file.path);

          if (PlatformUtils.isDesktopNotMac) {
            if (await windowManager.isPreventClose()) {
              await windowManager.setPreventClose(false);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              exit(0);
            });
          }

          if (result.type != ResultType.done) {
            Get.snackbar(i18n("install_failed"), result.message);
          }
        }
      }
    } catch (e) {
      log(e.toString(), name: 'DownloadApkDialog');

      if (mounted && !_cancelToken.isCancelled) {
        _showErrorAndClose(i18n("download_failed", args: {"error": "$e"}));
      }
    }
  }

  Future<Directory> _getSafeDownloadDir() async {
    Directory downloadDir;

    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      downloadDir = Directory(path.join(dir!.path, 'pure_live'));
    } else {
      downloadDir = await AppPathManager().getDir(AppPathManager.dirDownload);
    }

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    return downloadDir;
  }

  void _showErrorAndClose(String message) {
    Navigator.of(Get.context!).pop(false);
    Get.snackbar(i18n("error"), message, snackPosition: SnackPosition.bottom);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 185,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n("downloading_version", args: {"version": widget.version}),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_statusText),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDownloading)
                  TextButton(
                    onPressed: () {
                      _cancelToken.cancel(i18n("cancel"));
                      Navigator.of(Get.context!).pop(false);
                    },
                    child: Text(i18n("cancel")),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
