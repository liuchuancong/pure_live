import 'dart:io';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:android_intent_plus/android_intent.dart';
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

      if (await file.exists()) {
        await file.delete();
      }

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
            final double receivedMb = received / (1024 * 1024);
            final double totalMb = total / (1024 * 1024);

            setState(() {
              _progress = progress;
              _statusText = "${receivedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB";
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

      if (Platform.isAndroid) {
        Get.showSnackbar(
          GetSnackBar(
            message: i18n("install_tip"),
            snackPosition: SnackPosition.top,
            duration: const Duration(seconds: 2),
            backgroundColor: Get.theme.colorScheme.primary,
          ),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (Navigator.canPop(Get.context!)) {
          Navigator.pop(Get.context!, true);
        }
        openDownloadFolder(baseDir);
      } else if (PlatformUtils.isDesktop) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }

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

  void openDownloadFolder(Directory folder) async {
    if (!Platform.isAndroid) return;
    try {
      final result = await OpenFilex.open(folder.path);
      if (result.type != ResultType.done) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'content://com.android.externalstorage.documents/document/primary%3ADownload',
          type: 'vnd.android.document/directory',
          flags: [1, 268435456],
        );
        await intent.launch();
      }
    } catch (e) {
      Get.snackbar(i18n("install_failed"), e.toString());
    }
  }

  Future<Directory> _getSafeDownloadDir() async {
    Directory downloadDir;
    if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
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
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isDownloading
                          ? const AppStatusView(type: AppStatusType.loading, isMini: true)
                          : Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n("downloading_version", args: {"version": widget.version}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progress / 100,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$_progress%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isDownloading
                        ? () {
                            _cancelToken.cancel(i18n("cancel"));
                            if (Navigator.canPop(context)) Navigator.pop(context, false);
                          }
                        : null,
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
