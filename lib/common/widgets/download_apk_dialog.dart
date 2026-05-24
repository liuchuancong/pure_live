import 'dart:io';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class DownloadApkDialog extends StatefulWidget {
  final String apkUrl;
  final String version;

  const DownloadApkDialog({super.key, required this.apkUrl, this.version = ''});

  @override
  State<DownloadApkDialog> createState() => _DownloadApkDialogState();
}

class _DownloadApkDialogState extends State<DownloadApkDialog> {
  late final Dio _dio;
  late final CancelToken _cancelToken;

  int _progress = 0;
  bool _isDownloading = true;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _statusText = i18n("download_preparing");
    _cancelToken = CancelToken();
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 120)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDownload());
  }

  Future<void> _startDownload() async {
    try {
      final apkName = widget.apkUrl.split('/').last;
      final baseDir = await _getSafeDownloadDir();
      final file = File(path.join(baseDir.path, apkName));

      await _dio.download(
        widget.apkUrl,
        file.path,
        options: Options(
          headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache', 'Expires': '0'},
          receiveTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (!mounted) return;

          if (total > 0) {
            final progress = (received / total * 100).toInt();
            setState(() {
              _progress = progress;
              _statusText = i18n("downloading_progress", args: {"version": widget.version, "progress": "$progress"});
            });
          } else {
            final mb = received ~/ (1024 * 1024);
            setState(() {
              _statusText = i18n("downloaded_mb", args: {"mb": "$mb"});
            });
          }
        },
        cancelToken: _cancelToken,
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _statusText = i18n("download_complete_installing");
      });

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }

      if (Platform.isAndroid) {
        ToastUtil.show(i18n("install_tip"));
        final result = await OpenFilex.open(file.path, type: "application/vnd.android.package-archive");
        if (result.type != ResultType.done) {
          Get.snackbar(
            i18n("install_failed"),
            i18n("install_unknown_app_permission_tip", args: {"message": result.message}),
          );
        }
      } else if (PlatformUtils.isDesktop) {
        final result = await OpenFilex.open(file.path);

        if (PlatformUtils.isDesktopNotMac) {
          if (await windowManager.isPreventClose()) {
            await windowManager.setPreventClose(false);
          }
          exit(0);
        }

        if (result.type != ResultType.done) {
          Get.snackbar(
            i18n('install_failed'),
            i18n('check_unknown_sources_permission', args: {'msg': result.message}),
            snackPosition: SnackPosition.bottom,
          );
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
      // 使用 path.join 替代字符串拼接，自动处理跨平台斜杠
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
    if (Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
    Get.snackbar(
      i18n("error"),
      message,
      snackPosition: SnackPosition.bottom,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        // 使用约束代替固定高度，避免因字体放大导致 UI 溢出 (Overflow)
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n("downloading_version", args: {"version": widget.version}),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(_statusText, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isDownloading
                        ? () {
                            _cancelToken.cancel(i18n("cancel"));
                            if (Navigator.canPop(context)) Navigator.pop(context, false);
                          }
                        : null, // 下载完成后禁用取消按钮
                    child: Text(i18n("cancel")),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }
}
