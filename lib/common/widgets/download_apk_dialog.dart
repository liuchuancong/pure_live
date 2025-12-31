import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pure_live/common/global/platform_utils.dart';

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
  String _statusText = '准备中...';

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
    final dir = await getApplicationDocumentsDirectory();
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
            final status = '正在下载 v${widget.version}... $progress%';
            setState(() {
              _progress = progress;
              _statusText = status;
            });
          } else if (mounted) {
            final mb = received ~/ (1024 * 1024);
            setState(() {
              _statusText = '已下载: $mb MB';
            });
          }
        },
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = '下载完成，正在安装...';
        });

        // 关闭当前对话框
        Navigator.of(Get.context!).pop(false);

        // 安装 APK
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
          Get.snackbar('安装失败', result.message);
        }
      }
    } catch (e) {
      log(e.toString(), name: 'DownloadApkDialog');
      if (mounted && !_cancelToken.isCancelled) {
        _showErrorAndClose('下载失败: $e');
      }
    }
  }

  void _showErrorAndClose(String message) {
    Navigator.of(Get.context!).pop(false);
    Get.snackbar('错误', message, snackPosition: SnackPosition.bottom);
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
            Text('正在下载 v${widget.version}...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_statusText),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDownloading)
                  TextButton(
                    onPressed: () {
                      _cancelToken.cancel('用户取消');
                      Navigator.of(Get.context!).pop(false);
                    },
                    child: const Text('取消'),
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
