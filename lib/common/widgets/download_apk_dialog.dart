import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';

enum DownloadRuntimePlatform { android, desktop, other }

typedef DownloadProgressCallback = void Function(int received, int total);
typedef DownloadFileTransfer = Future<void> Function({
  required String url,
  required String destinationPath,
  required CancelToken cancelToken,
  required DownloadProgressCallback onProgress,
});
typedef DownloadDirectoryProvider = Future<Directory> Function();
typedef DownloadFileOpener = Future<DownloadedFileOpenResult> Function(String filePath);

const _maxDownloadBaseNameBytes = 240;
const _maxDownloadExtensionBytes = 32;

class DownloadedFileOpenResult {
  const DownloadedFileOpenResult.opened() : isOpened = true, message = '';
  const DownloadedFileOpenResult.failed([this.message = '']) : isOpened = false;

  final bool isOpened;
  final String message;
}

String safeDownloadFileName(String url, {String? suggestedName}) {
  var candidate = suggestedName?.trim() ?? '';
  if (candidate.isEmpty) {
    try {
      final uri = Uri.parse(url.trim());
      final segments = uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
      if (segments.isNotEmpty) candidate = segments.last;
    } catch (_) {}
  }

  try {
    candidate = Uri.decodeComponent(candidate);
  } catch (_) {}
  candidate = candidate.replaceAll('\\', '/').split('/').last.trim();
  candidate = candidate
      .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"/\\|?*\u202A-\u202E\u2066-\u2069]'), '_')
      .replaceFirst(RegExp(r'^[. ]+'), '')
      .replaceFirst(RegExp(r'[. ]+$'), '');
  candidate = String.fromCharCodes(candidate.runes);

  if (candidate.isEmpty || candidate == '.' || candidate == '..') candidate = 'PureLive-download';
  if (RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', caseSensitive: false).hasMatch(candidate)) {
    candidate = '_$candidate';
  }

  return _fitDownloadBaseName(candidate);
}

String _fitDownloadBaseName(String candidate) {
  if (utf8.encode(candidate).length <= _maxDownloadBaseNameBytes) return candidate;

  final rawExtension = path.extension(candidate);
  final extension = _truncateUtf8(rawExtension, _maxDownloadExtensionBytes);
  final stem = rawExtension.isEmpty ? candidate : candidate.substring(0, candidate.length - rawExtension.length);
  final digest = sha256.convert(utf8.encode(candidate)).toString().substring(0, 12);
  final suffix = '-$digest$extension';
  final stemBudget = _maxDownloadBaseNameBytes - utf8.encode(suffix).length;
  var fittedStem = _truncateUtf8(stem, stemBudget);
  if (fittedStem.isEmpty) fittedStem = _truncateUtf8('PureLive', stemBudget);
  return '$fittedStem$suffix';
}

String _truncateUtf8(String value, int maxBytes) {
  if (maxBytes <= 0 || value.isEmpty) return '';
  final buffer = StringBuffer();
  var usedBytes = 0;
  for (final rune in value.runes) {
    final scalar = String.fromCharCode(rune);
    final scalarBytes = utf8.encode(scalar).length;
    if (usedBytes + scalarBytes > maxBytes) break;
    buffer.write(scalar);
    usedBytes += scalarBytes;
  }
  return buffer.toString();
}

class DownloadApkDialog extends StatefulWidget {
  const DownloadApkDialog({
    super.key,
    required this.apkUrl,
    this.version = '',
    this.fileName,
    this.runtimePlatform,
    this.downloadDirectoryProvider,
    this.transfer,
    this.fileOpener,
    this.completionDelay = const Duration(seconds: 1),
    this.startAutomatically = true,
  });

  final String apkUrl;
  final String version;
  final String? fileName;
  final DownloadRuntimePlatform? runtimePlatform;
  final DownloadDirectoryProvider? downloadDirectoryProvider;
  final DownloadFileTransfer? transfer;
  final DownloadFileOpener? fileOpener;
  final Duration completionDelay;
  final bool startAutomatically;

  @override
  State<DownloadApkDialog> createState() => _DownloadApkDialogState();
}

class _DownloadApkDialogState extends State<DownloadApkDialog> {
  late final Dio _dio;
  late final CancelToken _cancelToken;
  late final String _resolvedFileName;

  int _progress = 0;
  bool _hasKnownTotal = false;
  bool _isDownloading = true;
  bool _isOpening = false;
  String _statusText = '';
  String? _openFailure;
  File? _partialFile;
  File? _completedFile;

  DownloadRuntimePlatform get _runtimePlatform {
    final override = widget.runtimePlatform;
    if (override != null) return override;
    if (Platform.isAndroid) return DownloadRuntimePlatform.android;
    if (PlatformUtils.isDesktop) return DownloadRuntimePlatform.desktop;
    return DownloadRuntimePlatform.other;
  }

  @override
  void initState() {
    super.initState();
    _resolvedFileName = safeDownloadFileName(widget.apkUrl, suggestedName: widget.fileName);
    _statusText = i18n('download_preparing');
    _cancelToken = CancelToken();
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 120)));
    if (widget.startAutomatically) {
      unawaited(Future<void>.microtask(_startDownload));
    }
  }

  Future<void> _startDownload() async {
    File? partialFile;
    try {
      final baseDir = await _getSafeDownloadDir();
      final completedFile = File(path.join(baseDir.path, _resolvedFileName));
      partialFile = File('${completedFile.path}.part');
      _partialFile = partialFile;
      await _recoverInterruptedCommit(completedFile);
      await _deleteIfPresent(partialFile);

      final transfer = widget.transfer ?? _defaultTransfer;
      await transfer(
        url: widget.apkUrl,
        destinationPath: partialFile.path,
        cancelToken: _cancelToken,
        onProgress: _updateProgress,
      );
      if (_cancelToken.isCancelled) {
        await _deleteIfPresent(partialFile);
        return;
      }

      if (!await partialFile.exists()) {
        throw const FileSystemException('Downloaded staging file is missing');
      }
      _completedFile = await _commitStagedFile(partialFile, completedFile);
      _partialFile = null;

      if (!mounted) return;
      setState(() {
        _progress = 100;
        _hasKnownTotal = true;
        _isDownloading = false;
        _isOpening = false;
        _statusText = i18n('download_complete_opening');
      });

      if (_runtimePlatform == DownloadRuntimePlatform.android && _resolvedFileName.toLowerCase().endsWith('.apk')) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(i18n('install_tip')), duration: const Duration(seconds: 2)));
      }

      if (widget.completionDelay > Duration.zero) {
        await Future<void>.delayed(widget.completionDelay);
      }
      if (mounted) await _openCompletedFile();
    } catch (error) {
      await _deleteIfPresent(partialFile);
      log(error.toString(), name: 'DownloadApkDialog');
      if (mounted && !_cancelToken.isCancelled) {
        _showErrorAndClose(i18n('download_failed'));
      }
    }
  }

  Future<void> _defaultTransfer({
    required String url,
    required String destinationPath,
    required CancelToken cancelToken,
    required DownloadProgressCallback onProgress,
  }) {
    return _dio.download(
      url,
      destinationPath,
      options: Options(
        headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache', 'Expires': '0'},
        receiveTimeout: const Duration(seconds: 30),
      ),
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  void _updateProgress(int received, int total) {
    if (!mounted) return;
    if (total > 0) {
      final progress = (received / total * 100).round().clamp(0, 100);
      final receivedMb = received / (1024 * 1024);
      final totalMb = total / (1024 * 1024);
      setState(() {
        _progress = progress;
        _hasKnownTotal = true;
        _statusText = '${receivedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';
      });
      return;
    }

    final mb = received ~/ (1024 * 1024);
    setState(() {
      _hasKnownTotal = false;
      _statusText = i18n('downloaded_mb', args: {'mb': '$mb'});
    });
  }

  Future<void> _openCompletedFile() async {
    final file = _completedFile;
    if (file == null || _isOpening) return;

    setState(() {
      _isOpening = true;
      _openFailure = null;
      _statusText = i18n('download_complete_opening');
    });
    final result = await _openDownloadedFile(file.path);
    if (!mounted) return;
    if (result.isOpened) {
      if (Navigator.canPop(context)) Navigator.pop(context, true);
      return;
    }

    final detail = result.message.trim();
    setState(() {
      _isOpening = false;
      _openFailure = detail;
      _statusText = detail.isEmpty
          ? i18n('download_open_failed')
          : i18n('download_open_failed_detail', args: {'message': detail});
    });
  }

  Future<DownloadedFileOpenResult> _openDownloadedFile(String filePath) async {
    final opener = widget.fileOpener;
    if (opener != null) return opener(filePath);
    try {
      if (_runtimePlatform == DownloadRuntimePlatform.android) {
        final opened = await FileUtils.openFileOrUrl(filePath);
        return opened ? const DownloadedFileOpenResult.opened() : const DownloadedFileOpenResult.failed();
      }
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done
          ? const DownloadedFileOpenResult.opened()
          : DownloadedFileOpenResult.failed(result.message);
    } catch (error) {
      return DownloadedFileOpenResult.failed(error.toString());
    }
  }

  Future<Directory> _getSafeDownloadDir() async {
    final provider = widget.downloadDirectoryProvider;
    if (provider != null) {
      final directory = await provider();
      if (!await directory.exists()) await directory.create(recursive: true);
      return directory;
    }

    final Directory downloadDir;
    if (_runtimePlatform == DownloadRuntimePlatform.android) {
      final directory = await getDownloadsDirectory();
      if (directory == null) throw const FileSystemException('Downloads directory is missing');
      downloadDir = Directory(path.join(directory.path, 'pure_live'));
    } else {
      downloadDir = await AppPathManager().getDir(AppPathManager.dirDownload);
    }
    if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
    return downloadDir;
  }

  Future<void> _deleteIfPresent(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  Future<void> _recoverInterruptedCommit(File completedFile) async {
    final backupFile = File('${completedFile.path}.previous');
    if (!await backupFile.exists()) return;
    if (await completedFile.exists()) {
      await backupFile.delete();
    } else {
      await backupFile.rename(completedFile.path);
    }
  }

  Future<File> _commitStagedFile(File partialFile, File completedFile) async {
    final backupFile = File('${completedFile.path}.previous');
    await _deleteIfPresent(backupFile);
    final hadPreviousFile = await completedFile.exists();
    if (hadPreviousFile) await completedFile.rename(backupFile.path);
    try {
      final committedFile = await partialFile.rename(completedFile.path);
      await _deleteIfPresent(backupFile);
      return committedFile;
    } catch (_) {
      if (hadPreviousFile && await backupFile.exists() && !await completedFile.exists()) {
        await backupFile.rename(completedFile.path);
      }
      rethrow;
    }
  }

  void _cancelDownload() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel(i18n('cancel'));
    if (Navigator.canPop(context)) Navigator.pop(context, false);
  }

  void _showErrorAndClose(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (Navigator.canPop(context)) Navigator.pop(context, false);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 420 || media.textScaler.scale(1) > 1.5;

    final statusContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.fileName != null
              ? i18n('downloading_app', args: {'app': _resolvedFileName})
              : i18n('downloading_version', args: {'version': widget.version}),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _statusText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _openFailure == null ? theme.colorScheme.primary : theme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    final statusIcon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Center(
        child: _isDownloading || _isOpening
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary),
              )
            : Icon(
                _openFailure == null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: _openFailure == null ? theme.colorScheme.primary : theme.colorScheme.error,
                size: 24,
              ),
      ),
    );

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          key: const ValueKey('download-dialog-scroll'),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [statusIcon, const SizedBox(height: 12), statusContent],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statusIcon,
                    const SizedBox(width: 16),
                    Expanded(child: statusContent),
                  ],
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProgressIndicator(theme),
                          const SizedBox(height: 8),
                          Text(
                            _hasKnownTotal ? '$_progress%' : '…',
                            textAlign: TextAlign.end,
                            style: _progressStyle(theme),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildProgressIndicator(theme)),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 48,
                            child: Text(
                              _hasKnownTotal ? '$_progress%' : '…',
                              textAlign: TextAlign.end,
                              style: _progressStyle(theme),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _buildActions(compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return LinearProgressIndicator(
      value: _hasKnownTotal ? _progress / 100 : null,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
      borderRadius: BorderRadius.circular(8),
      minHeight: 8,
    );
  }

  TextStyle? _progressStyle(ThemeData theme) {
    return theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold);
  }

  Widget _buildActions(bool compact) {
    if (_isDownloading) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: const ValueKey('download-cancel'),
          onPressed: _cancelDownload,
          child: Text(i18n('cancel')),
        ),
      );
    }
    if (_isOpening) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        label: Text(i18n('download_complete_opening'), textAlign: TextAlign.center),
      );
    }
    if (_openFailure != null) {
      final close = OutlinedButton(
        key: const ValueKey('download-close'),
        onPressed: () {
          if (Navigator.canPop(context)) Navigator.pop(context, false);
        },
        child: Text(i18n('close')),
      );
      final openAgain = FilledButton.icon(
        key: const ValueKey('download-open-again'),
        onPressed: _openCompletedFile,
        icon: const Icon(Icons.open_in_new_rounded),
        label: Text(i18n('download_open_again'), textAlign: TextAlign.center),
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [openAgain, const SizedBox(height: 8), close],
        );
      }
      return Row(mainAxisAlignment: MainAxisAlignment.end, children: [close, const SizedBox(width: 8), openAgain]);
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('dialog disposed');
    _dio.close(force: true);
    final partialFile = _partialFile;
    if (partialFile != null) partialFile.delete().ignore();
    super.dispose();
  }
}
